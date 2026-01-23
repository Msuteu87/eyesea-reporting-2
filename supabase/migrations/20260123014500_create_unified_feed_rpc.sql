-- Create RPC for unified social feed that includes both reports and events
-- Returns items ordered by creation date, with proximity filtering support

CREATE OR REPLACE FUNCTION get_unified_feed(
  p_user_id UUID DEFAULT NULL,
  p_country TEXT DEFAULT NULL,
  p_city TEXT DEFAULT NULL,
  p_latitude DOUBLE PRECISION DEFAULT NULL,
  p_longitude DOUBLE PRECISION DEFAULT NULL,
  p_radius_km INTEGER DEFAULT NULL,
  p_limit INTEGER DEFAULT 20,
  p_offset INTEGER DEFAULT 0
)
RETURNS TABLE (
  id UUID,
  item_type TEXT,
  user_id UUID,
  display_name TEXT,
  avatar_url TEXT,
  location TEXT,
  city TEXT,
  country TEXT,
  created_at TIMESTAMPTZ,
  -- Report-specific fields (NULL for events)
  pollution_type pollution_type,
  severity INTEGER,
  status report_status,
  notes TEXT,
  total_weight_kg NUMERIC,
  pollution_counts JSONB,
  image_url TEXT,
  scene_labels TEXT[],
  thanks_count BIGINT,
  user_has_thanked BOOLEAN,
  -- Event-specific fields (NULL for reports)
  event_title TEXT,
  event_description TEXT,
  event_address TEXT,
  event_start_time TIMESTAMPTZ,
  event_end_time TIMESTAMPTZ,
  event_status TEXT,
  event_max_attendees INTEGER,
  event_attendee_count BIGINT,
  user_has_joined BOOLEAN
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = 'public'
AS $$
  WITH user_point AS (
    SELECT 
      CASE 
        WHEN p_latitude IS NOT NULL AND p_longitude IS NOT NULL 
        THEN ST_SetSRID(ST_MakePoint(p_longitude, p_latitude), 4326)::geography
        ELSE NULL
      END AS point
  )
  -- Reports
  SELECT
    r.id,
    'report'::TEXT as item_type,
    r.user_id,
    p.display_name,
    p.avatar_url,
    ST_AsText(r.location) as location,
    r.city,
    r.country,
    r.reported_at as created_at,
    -- Report fields
    r.pollution_type,
    r.severity,
    r.status,
    r.notes,
    r.total_weight_kg,
    r.pollution_counts,
    (
      SELECT ri.storage_path
      FROM report_images ri
      WHERE ri.report_id = r.id AND ri.is_primary = true
      LIMIT 1
    ) as image_url,
    (
      SELECT ai.scene_labels
      FROM ai_analysis ai
      WHERE ai.report_id = r.id
      LIMIT 1
    ) as scene_labels,
    (
      SELECT COUNT(*)
      FROM report_thanks rt
      WHERE rt.report_id = r.id
    ) as thanks_count,
    (
      p_user_id IS NOT NULL
      AND EXISTS(
        SELECT 1
        FROM report_thanks rt
        WHERE rt.report_id = r.id AND rt.user_id = p_user_id
      )
    ) as user_has_thanked,
    -- Event fields (NULL for reports)
    NULL::TEXT as event_title,
    NULL::TEXT as event_description,
    NULL::TEXT as event_address,
    NULL::TIMESTAMPTZ as event_start_time,
    NULL::TIMESTAMPTZ as event_end_time,
    NULL::TEXT as event_status,
    NULL::INTEGER as event_max_attendees,
    NULL::BIGINT as event_attendee_count,
    NULL::BOOLEAN as user_has_joined
  FROM reports r
  LEFT JOIN profiles p ON r.user_id = p.id
  CROSS JOIN user_point up
  WHERE
    -- Location filtering
    (
      p_radius_km IS NULL 
      OR up.point IS NULL 
      OR ST_DWithin(r.location::geography, up.point, p_radius_km * 1000)
    )
    AND (p_country IS NULL OR r.country = p_country)
    AND (p_city IS NULL OR r.city = p_city)

  UNION ALL

  -- Events (only upcoming/active events, not cancelled)
  SELECT
    e.id,
    'event'::TEXT as item_type,
    e.organizer_id as user_id,
    p.display_name,
    p.avatar_url,
    ST_AsText(e.location) as location,
    NULL::TEXT as city,
    NULL::TEXT as country,
    e.created_at,
    -- Report fields (NULL for events)
    NULL::pollution_type as pollution_type,
    NULL::INTEGER as severity,
    NULL::report_status as status,
    NULL::TEXT as notes,
    NULL::NUMERIC as total_weight_kg,
    NULL::JSONB as pollution_counts,
    NULL::TEXT as image_url,
    NULL::TEXT[] as scene_labels,
    NULL::BIGINT as thanks_count,
    NULL::BOOLEAN as user_has_thanked,
    -- Event fields
    e.title as event_title,
    e.description as event_description,
    e.address as event_address,
    e.start_time as event_start_time,
    e.end_time as event_end_time,
    e.status as event_status,
    e.max_attendees as event_max_attendees,
    (
      SELECT COUNT(*)
      FROM event_participants ep
      WHERE ep.event_id = e.id AND ep.status IN ('joined', 'checked_in')
    ) as event_attendee_count,
    (
      p_user_id IS NOT NULL
      AND EXISTS(
        SELECT 1
        FROM event_participants ep
        WHERE ep.event_id = e.id AND ep.user_id = p_user_id AND ep.status IN ('joined', 'checked_in')
      )
    ) as user_has_joined
  FROM events e
  LEFT JOIN profiles p ON e.organizer_id = p.id
  CROSS JOIN user_point up
  WHERE
    -- Only show upcoming or active events (not completed/cancelled)
    e.status IN ('planned', 'active')
    AND e.start_time > NOW() - INTERVAL '1 day'  -- Include events from last 24h
    -- Location filtering
    AND (
      p_radius_km IS NULL 
      OR up.point IS NULL 
      OR ST_DWithin(e.location::geography, up.point, p_radius_km * 1000)
    )

  ORDER BY created_at DESC
  LIMIT p_limit
  OFFSET p_offset;
$$;

-- Add helpful comment
COMMENT ON FUNCTION get_unified_feed IS 
  'Returns a unified feed combining pollution reports and cleanup events, ordered by creation date. Supports proximity filtering with latitude/longitude/radius parameters.';
