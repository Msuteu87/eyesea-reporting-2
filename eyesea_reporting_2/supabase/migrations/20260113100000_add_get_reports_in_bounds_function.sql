-- Create a function to fetch reports within a bounding box using PostGIS
-- This uses ST_MakeEnvelope to create a bounding box and ST_Intersects for spatial filtering
-- Much more efficient than fetching all reports and filtering client-side

CREATE OR REPLACE FUNCTION public.get_reports_in_bounds(
  min_lng double precision,
  min_lat double precision,
  max_lng double precision,
  max_lat double precision,
  max_results int DEFAULT 500
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
  WHERE r.location IS NOT NULL
    AND ST_Intersects(
      r.location,
      ST_MakeEnvelope(min_lng, min_lat, max_lng, max_lat, 4326)::geography
    )
  ORDER BY r.reported_at DESC
  LIMIT max_results;
$$;

-- Grant execute permission to authenticated and anonymous users
GRANT EXECUTE ON FUNCTION public.get_reports_in_bounds(double precision, double precision, double precision, double precision, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_reports_in_bounds(double precision, double precision, double precision, double precision, int) TO anon;

-- Create a spatial index on the location column for better performance (if not exists)
CREATE INDEX IF NOT EXISTS reports_location_gist_idx ON reports USING GIST (location);
