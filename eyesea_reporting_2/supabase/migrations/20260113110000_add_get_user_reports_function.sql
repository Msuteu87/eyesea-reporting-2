-- Create a function to fetch reports for a specific user with optional status filtering
-- Returns reports with location as text and includes image URLs

CREATE OR REPLACE FUNCTION public.get_user_reports(
  p_user_id uuid,
  p_status text DEFAULT NULL,
  p_limit int DEFAULT 20,
  p_offset int DEFAULT 0
)
RETURNS TABLE (
  id uuid,
  user_id uuid,
  org_id uuid,
  location text,
  address text,
  pollution_type pollution_type,
  severity int,
  status report_status,
  notes text,
  is_anonymous boolean,
  reported_at timestamptz,
  city text,
  country text,
  pollution_counts jsonb,
  total_weight_kg decimal,
  xp_earned int,
  is_flagged boolean,
  fraud_score decimal,
  fraud_warnings text[],
  image_urls text[]
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    r.id,
    r.user_id,
    r.org_id,
    ST_AsText(r.location) as location,
    r.address,
    r.pollution_type,
    r.severity,
    r.status,
    r.notes,
    r.is_anonymous,
    r.reported_at,
    r.city,
    r.country,
    r.pollution_counts,
    r.total_weight_kg,
    r.xp_earned,
    r.is_flagged,
    r.fraud_score,
    r.fraud_warnings,
    COALESCE(
      (SELECT array_agg(ri.storage_path ORDER BY ri.is_primary DESC)
       FROM report_images ri
       WHERE ri.report_id = r.id),
      ARRAY[]::text[]
    ) as image_urls
  FROM reports r
  WHERE r.user_id = p_user_id
    AND (p_status IS NULL OR r.status::text = p_status)
  ORDER BY r.reported_at DESC
  LIMIT p_limit
  OFFSET p_offset;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.get_user_reports(uuid, text, int, int) TO authenticated;
