-- Scalability Improvements Migration
-- 1. Add updated_at column for delta sync
-- 2. Create get_reports_in_bounds_with_images to fix N+1 query problem
-- 3. Create get_clustered_reports for server-side clustering

-- ============================================================================
-- 1. ADD UPDATED_AT COLUMN FOR DELTA SYNC
-- ============================================================================

-- Add updated_at column if not exists
ALTER TABLE reports ADD COLUMN IF NOT EXISTS updated_at timestamptz;

-- Backfill existing rows with reported_at as initial updated_at
UPDATE reports SET updated_at = reported_at WHERE updated_at IS NULL;

-- Create trigger function to auto-update updated_at on row changes
CREATE OR REPLACE FUNCTION update_reports_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop trigger if exists and recreate
DROP TRIGGER IF EXISTS reports_updated_at_trigger ON reports;
CREATE TRIGGER reports_updated_at_trigger
  BEFORE UPDATE ON reports
  FOR EACH ROW
  EXECUTE FUNCTION update_reports_updated_at();

-- Index for efficient delta sync queries
CREATE INDEX IF NOT EXISTS reports_updated_at_idx ON reports(updated_at);

-- ============================================================================
-- 2. FIX N+1 QUERY: GET REPORTS IN BOUNDS WITH IMAGES
-- ============================================================================

-- This function includes image URLs in the same query using a correlated subquery
-- eliminating the N+1 problem where images were fetched separately per report

CREATE OR REPLACE FUNCTION public.get_reports_in_bounds_with_images(
  min_lng double precision,
  min_lat double precision,
  max_lng double precision,
  max_lat double precision,
  max_results int DEFAULT 500,
  p_updated_since timestamptz DEFAULT NULL
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
  image_urls text[],
  updated_at timestamptz
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
    -- Include images in same query (fixes N+1)
    COALESCE(
      (SELECT array_agg(ri.storage_path ORDER BY ri.is_primary DESC)
       FROM report_images ri
       WHERE ri.report_id = r.id),
      ARRAY[]::text[]
    ) as image_urls,
    COALESCE(r.updated_at, r.reported_at) as updated_at
  FROM reports r
  WHERE r.location IS NOT NULL
    AND ST_Intersects(
      r.location,
      ST_MakeEnvelope(min_lng, min_lat, max_lng, max_lat, 4326)::geography
    )
    -- Delta sync: only return reports updated since given timestamp
    AND (p_updated_since IS NULL OR COALESCE(r.updated_at, r.reported_at) > p_updated_since)
  ORDER BY r.reported_at DESC
  LIMIT max_results;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION public.get_reports_in_bounds_with_images(
  double precision, double precision, double precision, double precision, int, timestamptz
) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_reports_in_bounds_with_images(
  double precision, double precision, double precision, double precision, int, timestamptz
) TO anon;

-- ============================================================================
-- 3. SERVER-SIDE CLUSTERING FUNCTION
-- ============================================================================

-- Returns pre-clustered data at low zoom levels to reduce client-side processing
-- At zoom >= 14, returns individual points with full details
-- At zoom < 14, returns cluster centroids with point counts

CREATE OR REPLACE FUNCTION public.get_clustered_reports(
  min_lng double precision,
  min_lat double precision,
  max_lng double precision,
  max_lat double precision,
  zoom_level int,
  max_results int DEFAULT 500
)
RETURNS TABLE (
  cluster_id int,
  is_cluster boolean,
  point_count int,
  centroid_lng double precision,
  centroid_lat double precision,
  -- Individual report fields (null for actual clusters)
  report_id uuid,
  report_user_id uuid,
  pollution_type pollution_type,
  severity int,
  status report_status,
  reported_at timestamptz,
  city text,
  country text,
  pollution_counts jsonb,
  total_weight_kg decimal,
  image_url text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  cluster_distance double precision;
BEGIN
  -- Calculate cluster distance based on zoom level (in meters)
  -- Higher zoom = smaller clusters = more detail
  cluster_distance :=
    CASE
      WHEN zoom_level <= 5 THEN 100000   -- 100km at world view
      WHEN zoom_level <= 8 THEN 50000    -- 50km at country view
      WHEN zoom_level <= 10 THEN 10000   -- 10km at region view
      WHEN zoom_level <= 12 THEN 2000    -- 2km at city view
      WHEN zoom_level <= 13 THEN 500     -- 500m at neighborhood view
      ELSE 0  -- No clustering at zoom >= 14
    END;

  IF zoom_level >= 14 THEN
    -- Return individual points at high zoom (no clustering)
    RETURN QUERY
    SELECT
      0 as cluster_id,
      false as is_cluster,
      1 as point_count,
      ST_X(r.location::geometry) as centroid_lng,
      ST_Y(r.location::geometry) as centroid_lat,
      r.id as report_id,
      r.user_id as report_user_id,
      r.pollution_type,
      r.severity,
      r.status,
      r.reported_at,
      r.city,
      r.country,
      r.pollution_counts,
      r.total_weight_kg,
      (SELECT ri.storage_path FROM report_images ri
       WHERE ri.report_id = r.id ORDER BY ri.is_primary DESC LIMIT 1) as image_url
    FROM reports r
    WHERE r.location IS NOT NULL
      AND ST_Intersects(
        r.location,
        ST_MakeEnvelope(min_lng, min_lat, max_lng, max_lat, 4326)::geography
      )
    ORDER BY r.reported_at DESC
    LIMIT max_results;
  ELSE
    -- Return clusters at low zoom using ST_ClusterDBSCAN
    RETURN QUERY
    WITH bounded_reports AS (
      SELECT r.*
      FROM reports r
      WHERE r.location IS NOT NULL
        AND ST_Intersects(
          r.location,
          ST_MakeEnvelope(min_lng, min_lat, max_lng, max_lat, 4326)::geography
        )
    ),
    clustered AS (
      SELECT
        br.*,
        ST_ClusterDBSCAN(br.location::geometry, eps := cluster_distance, minpoints := 1)
          OVER () as cid
      FROM bounded_reports br
    )
    SELECT
      COALESCE(c.cid, 0)::int as cluster_id,
      COUNT(*) > 1 as is_cluster,
      COUNT(*)::int as point_count,
      AVG(ST_X(c.location::geometry))::double precision as centroid_lng,
      AVG(ST_Y(c.location::geometry))::double precision as centroid_lat,
      -- For single-point "clusters", return the report details
      CASE WHEN COUNT(*) = 1 THEN MIN(c.id) ELSE NULL END as report_id,
      CASE WHEN COUNT(*) = 1 THEN MIN(c.user_id) ELSE NULL END as report_user_id,
      CASE WHEN COUNT(*) = 1 THEN MIN(c.pollution_type) ELSE NULL END as pollution_type,
      CASE WHEN COUNT(*) = 1 THEN MIN(c.severity) ELSE NULL END as severity,
      CASE WHEN COUNT(*) = 1 THEN MIN(c.status) ELSE NULL END as status,
      CASE WHEN COUNT(*) = 1 THEN MIN(c.reported_at) ELSE NULL END as reported_at,
      CASE WHEN COUNT(*) = 1 THEN MIN(c.city) ELSE NULL END as city,
      CASE WHEN COUNT(*) = 1 THEN MIN(c.country) ELSE NULL END as country,
      CASE WHEN COUNT(*) = 1 THEN MIN(c.pollution_counts) ELSE NULL END as pollution_counts,
      CASE WHEN COUNT(*) = 1 THEN MIN(c.total_weight_kg) ELSE NULL END as total_weight_kg,
      NULL::text as image_url
    FROM clustered c
    GROUP BY c.cid
    ORDER BY point_count DESC
    LIMIT max_results;
  END IF;
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION public.get_clustered_reports(
  double precision, double precision, double precision, double precision, int, int
) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_clustered_reports(
  double precision, double precision, double precision, double precision, int, int
) TO anon;

-- ============================================================================
-- 4. COMPOSITE INDEX FOR BOUNDS + STATUS QUERIES
-- ============================================================================

-- This helps when filtering by both location and status
CREATE INDEX IF NOT EXISTS reports_status_idx ON reports(status);
