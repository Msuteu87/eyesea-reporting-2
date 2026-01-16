-- Migration: Add proximity-based filtering to social feed
-- Handles 30k+ reports by showing nearby content first

-- ============================================
-- 1. Add geospatial index for fast proximity queries
-- ============================================

-- Index on geography for ST_DWithin queries (uses meters, accurate for global distances)
CREATE INDEX IF NOT EXISTS idx_reports_location_geography
ON public.reports
USING GIST ((location::geography));

-- ============================================
-- 2. Update get_social_feed to support proximity filtering
-- ============================================

CREATE OR REPLACE FUNCTION public.get_social_feed(
  p_user_id uuid DEFAULT NULL,
  p_country text DEFAULT NULL,
  p_city text DEFAULT NULL,
  p_latitude double precision DEFAULT NULL,
  p_longitude double precision DEFAULT NULL,
  p_radius_km int DEFAULT NULL,
  p_limit int DEFAULT 20,
  p_offset int DEFAULT 0
)
RETURNS TABLE (
  id uuid,
  user_id uuid,
  display_name text,
  avatar_url text,
  location text,
  city text,
  country text,
  pollution_type pollution_type,
  severity int,
  status report_status,
  notes text,
  reported_at timestamptz,
  total_weight_kg decimal,
  pollution_counts jsonb,
  image_url text,
  scene_labels text[],
  thanks_count bigint,
  user_has_thanked boolean,
  distance_km double precision
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    r.id,
    r.user_id,
    p.display_name,
    p.avatar_url,
    ST_AsText(r.location) as location,
    r.city,
    r.country,
    r.pollution_type,
    r.severity,
    r.status,
    r.notes,
    r.reported_at,
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
    -- Calculate distance in km if coordinates provided
    CASE
      WHEN p_latitude IS NOT NULL AND p_longitude IS NOT NULL THEN
        ST_Distance(
          r.location::geography,
          ST_SetSRID(ST_MakePoint(p_longitude, p_latitude), 4326)::geography
        ) / 1000.0
      ELSE NULL
    END as distance_km
  FROM reports r
  LEFT JOIN profiles p ON r.user_id = p.id
  WHERE
    -- Country/City filters (exact match, used as fallback)
    (p_country IS NULL OR r.country = p_country)
    AND (p_city IS NULL OR r.city = p_city)
    -- Proximity filter (if coordinates and radius provided)
    AND (
      p_latitude IS NULL
      OR p_longitude IS NULL
      OR p_radius_km IS NULL
      OR ST_DWithin(
        r.location::geography,
        ST_SetSRID(ST_MakePoint(p_longitude, p_latitude), 4326)::geography,
        p_radius_km * 1000  -- Convert km to meters
      )
    )
  ORDER BY
    -- If proximity search, order by distance first, then recency
    CASE
      WHEN p_latitude IS NOT NULL AND p_longitude IS NOT NULL THEN
        ST_Distance(
          r.location::geography,
          ST_SetSRID(ST_MakePoint(p_longitude, p_latitude), 4326)::geography
        )
      ELSE 0
    END ASC,
    r.reported_at DESC
  LIMIT p_limit
  OFFSET p_offset;
$$;

-- Grant execute permissions (update signature with new params)
GRANT EXECUTE ON FUNCTION public.get_social_feed(uuid, text, text, double precision, double precision, int, int, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_social_feed(uuid, text, text, double precision, double precision, int, int, int) TO anon;

-- ============================================
-- 3. Helper function to count reports in radius (for auto-expand logic)
-- ============================================

CREATE OR REPLACE FUNCTION public.count_reports_in_radius(
  p_latitude double precision,
  p_longitude double precision,
  p_radius_km int
)
RETURNS int
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COUNT(*)::int
  FROM reports r
  WHERE ST_DWithin(
    r.location::geography,
    ST_SetSRID(ST_MakePoint(p_longitude, p_latitude), 4326)::geography,
    p_radius_km * 1000
  );
$$;

GRANT EXECUTE ON FUNCTION public.count_reports_in_radius(double precision, double precision, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.count_reports_in_radius(double precision, double precision, int) TO anon;
