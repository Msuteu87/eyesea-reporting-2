-- Migration: Fix SECURITY DEFINER functions with auth.uid() validation
-- These functions previously allowed any authenticated user to access any other user's data

-- ============================================
-- 1. FIX get_user_reports - Only allow fetching own reports
-- ============================================

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
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- SECURITY: Validate that caller can only access their own reports
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  IF auth.uid() != p_user_id THEN
    RAISE EXCEPTION 'Access denied: Cannot access other users reports';
  END IF;

  RETURN QUERY
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
END;
$$;

-- ============================================
-- 2. FIX get_user_rank - Only allow fetching own rank
-- ============================================

CREATE OR REPLACE FUNCTION public.get_user_rank(p_user_id uuid)
RETURNS TABLE (
  rank bigint,
  total_users bigint,
  reports_count int,
  total_xp bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- SECURITY: Validate caller can only access their own rank
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  IF auth.uid() != p_user_id THEN
    RAISE EXCEPTION 'Access denied: Cannot access other users rank';
  END IF;

  RETURN QUERY
  WITH user_stats AS (
    SELECT
      p.id,
      p.reports_count,
      COALESCE(SUM(r.xp_earned), 0)::bigint as total_xp
    FROM profiles p
    LEFT JOIN reports r ON r.user_id = p.id
    GROUP BY p.id, p.reports_count
  ),
  ranked AS (
    SELECT
      us.id,
      us.reports_count,
      us.total_xp,
      RANK() OVER (ORDER BY us.reports_count DESC, us.total_xp DESC) as rk
    FROM user_stats us
  )
  SELECT
    rk.rk as rank,
    (SELECT COUNT(*) FROM profiles)::bigint as total_users,
    rk.reports_count,
    rk.total_xp
  FROM ranked rk
  WHERE rk.id = p_user_id;
END;
$$;

-- ============================================
-- 3. FIX get_user_total_xp - Only allow fetching own XP
-- ============================================

CREATE OR REPLACE FUNCTION public.get_user_total_xp(p_user_id uuid)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  result bigint;
BEGIN
  -- SECURITY: Validate caller can only access their own XP
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Authentication required';
  END IF;

  IF auth.uid() != p_user_id THEN
    RAISE EXCEPTION 'Access denied: Cannot access other users XP';
  END IF;

  SELECT COALESCE(SUM(xp_earned), 0)::bigint INTO result
  FROM reports
  WHERE user_id = p_user_id;

  RETURN result;
END;
$$;
