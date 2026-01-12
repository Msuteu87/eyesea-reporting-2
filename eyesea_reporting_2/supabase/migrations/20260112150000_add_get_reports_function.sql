-- Create a function to fetch reports with location as readable text
-- This converts the geography WKB format to POINT(lng lat) text format

CREATE OR REPLACE FUNCTION public.get_reports_with_location()
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
  fraud_warnings text[]
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
    r.fraud_warnings
  FROM reports r
  ORDER BY r.reported_at DESC;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION public.get_reports_with_location() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_reports_with_location() TO anon;
