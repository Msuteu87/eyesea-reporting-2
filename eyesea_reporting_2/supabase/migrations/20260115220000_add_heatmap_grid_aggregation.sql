-- Grid-based heatmap aggregation for global visualization
-- Ensures all regions are represented regardless of report density
-- Prevents limit-based exclusion of certain areas

-- Drop existing function if it exists
DROP FUNCTION IF EXISTS get_heatmap_grid(double precision, double precision, double precision, double precision, double precision);

CREATE OR REPLACE FUNCTION get_heatmap_grid(
  min_lng double precision DEFAULT -180,
  min_lat double precision DEFAULT -85,
  max_lng double precision DEFAULT 180,
  max_lat double precision DEFAULT 85,
  cell_size double precision DEFAULT 2.0  -- Grid cell size in degrees (2° for global, 0.5° for regional)
)
RETURNS TABLE (
  cell_lat double precision,
  cell_lng double precision,
  report_count bigint,
  avg_severity double precision,
  weight double precision
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  WITH grid_cells AS (
    SELECT
      -- Snap coordinates to grid cell center
      (FLOOR(ST_Y(r.location::geometry) / cell_size) * cell_size + cell_size / 2) AS grid_lat,
      (FLOOR(ST_X(r.location::geometry) / cell_size) * cell_size + cell_size / 2) AS grid_lng,
      r.severity
    FROM reports r
    WHERE
      r.status IN ('pending', 'verified', 'resolved')
      AND ST_X(r.location::geometry) BETWEEN min_lng AND max_lng
      AND ST_Y(r.location::geometry) BETWEEN min_lat AND max_lat
  )
  SELECT
    gc.grid_lat AS cell_lat,
    gc.grid_lng AS cell_lng,
    COUNT(*)::bigint AS report_count,
    AVG(gc.severity)::double precision AS avg_severity,
    -- Weight calculation: log scale to handle varying densities
    -- 1 report = 0.2, 10 reports = 0.5, 50+ reports = 1.0
    LEAST(1.0, 0.2 + (LN(COUNT(*) + 1) / LN(50)))::double precision AS weight
  FROM grid_cells gc
  GROUP BY gc.grid_lat, gc.grid_lng
  ORDER BY report_count DESC;
END;
$$;

-- Grant execute permission to authenticated and anon users
GRANT EXECUTE ON FUNCTION get_heatmap_grid(double precision, double precision, double precision, double precision, double precision) TO authenticated;
GRANT EXECUTE ON FUNCTION get_heatmap_grid(double precision, double precision, double precision, double precision, double precision) TO anon;

COMMENT ON FUNCTION get_heatmap_grid IS 'Returns aggregated heatmap data in grid cells. Cell size can be adjusted based on zoom level (2° for global, 0.5° for regional views).';
