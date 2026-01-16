-- ============================================================================
-- LEADERBOARD ENHANCEMENTS
-- Adds time-filtered leaderboards for Users, Organizations, and Vessels
-- ============================================================================

-- ============================================================================
-- PART 1: PERFORMANCE INDEXES
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_reports_org_reported ON reports(org_id, reported_at);
CREATE INDEX IF NOT EXISTS idx_reports_vessel_reported ON reports(vessel_id, reported_at);
CREATE INDEX IF NOT EXISTS idx_reports_user_reported ON reports(user_id, reported_at);

-- ============================================================================
-- PART 2: TIME-FILTERED USER LEADERBOARD
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_user_leaderboard(
  p_days int DEFAULT 30,
  p_limit int DEFAULT 50
)
RETURNS TABLE (
  rank bigint,
  user_id uuid,
  display_name text,
  avatar_url text,
  reports_count bigint,
  total_xp bigint
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  WITH user_stats AS (
    SELECT
      p.id,
      p.display_name,
      p.avatar_url,
      COUNT(r.id)::bigint as reports_count,
      COALESCE(SUM(r.xp_earned), 0)::bigint as total_xp
    FROM profiles p
    LEFT JOIN reports r ON r.user_id = p.id
      AND r.reported_at >= (now() - (p_days || ' days')::interval)
    GROUP BY p.id, p.display_name, p.avatar_url
  )
  SELECT
    RANK() OVER (ORDER BY reports_count DESC, total_xp DESC) as rank,
    id as user_id,
    display_name,
    avatar_url,
    reports_count,
    total_xp
  FROM user_stats
  ORDER BY reports_count DESC, total_xp DESC
  LIMIT p_limit;
$$;

-- ============================================================================
-- PART 3: ORGANIZATION LEADERBOARD
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_organization_leaderboard(
  p_days int DEFAULT 30,
  p_limit int DEFAULT 50
)
RETURNS TABLE (
  rank bigint,
  org_id uuid,
  org_name text,
  logo_url text,
  country text,
  member_count bigint,
  reports_count bigint,
  total_xp bigint
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  WITH org_stats AS (
    SELECT
      o.id,
      o.name,
      o.logo_url,
      o.country,
      (SELECT COUNT(*) FROM organization_members om WHERE om.org_id = o.id)::bigint as member_count,
      COUNT(r.id)::bigint as reports_count,
      COALESCE(SUM(r.xp_earned), 0)::bigint as total_xp
    FROM organizations o
    LEFT JOIN reports r ON r.org_id = o.id
      AND r.reported_at >= (now() - (p_days || ' days')::interval)
    WHERE o.verified = true
    GROUP BY o.id, o.name, o.logo_url, o.country
    HAVING COUNT(r.id) > 0
  )
  SELECT
    RANK() OVER (ORDER BY reports_count DESC, total_xp DESC) as rank,
    id as org_id,
    name as org_name,
    logo_url,
    country,
    member_count,
    reports_count,
    total_xp
  FROM org_stats
  ORDER BY reports_count DESC, total_xp DESC
  LIMIT p_limit;
$$;

-- ============================================================================
-- PART 4: VESSEL LEADERBOARD
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_vessel_leaderboard(
  p_days int DEFAULT 30,
  p_limit int DEFAULT 50
)
RETURNS TABLE (
  rank bigint,
  vessel_id uuid,
  vessel_name text,
  flag_state text,
  imo_number text,
  org_name text,
  reports_count bigint,
  total_xp bigint
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  WITH vessel_stats AS (
    SELECT
      v.id,
      v.name,
      v.flag_state,
      v.imo_number,
      o.name as org_name,
      COUNT(r.id)::bigint as reports_count,
      COALESCE(SUM(r.xp_earned), 0)::bigint as total_xp
    FROM vessels v
    LEFT JOIN organizations o ON o.id = v.org_id
    LEFT JOIN reports r ON r.vessel_id = v.id
      AND r.reported_at >= (now() - (p_days || ' days')::interval)
    GROUP BY v.id, v.name, v.flag_state, v.imo_number, o.name
    HAVING COUNT(r.id) > 0
  )
  SELECT
    RANK() OVER (ORDER BY reports_count DESC, total_xp DESC) as rank,
    id as vessel_id,
    name as vessel_name,
    flag_state,
    imo_number,
    org_name,
    reports_count,
    total_xp
  FROM vessel_stats
  ORDER BY reports_count DESC, total_xp DESC
  LIMIT p_limit;
$$;

-- ============================================================================
-- PART 5: USER CATEGORY RANK
-- Get current user's rank in their organization or vessel
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_user_category_rank(
  p_user_id uuid,
  p_category text,  -- 'user', 'organization', 'vessel'
  p_days int DEFAULT 30
)
RETURNS TABLE (
  rank bigint,
  entity_id uuid,
  entity_name text,
  reports_count bigint,
  total_xp bigint,
  is_member boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF p_category = 'organization' THEN
    RETURN QUERY
    WITH user_org AS (
      SELECT om.org_id
      FROM organization_members om
      WHERE om.user_id = p_user_id
      LIMIT 1
    ),
    org_stats AS (
      SELECT
        o.id,
        o.name,
        COUNT(r.id)::bigint as rpts_count,
        COALESCE(SUM(r.xp_earned), 0)::bigint as ttl_xp,
        RANK() OVER (ORDER BY COUNT(r.id) DESC, COALESCE(SUM(r.xp_earned), 0) DESC) as rnk
      FROM organizations o
      LEFT JOIN reports r ON r.org_id = o.id
        AND r.reported_at >= (now() - (p_days || ' days')::interval)
      WHERE o.verified = true
      GROUP BY o.id, o.name
    )
    SELECT
      os.rnk as rank,
      os.id as entity_id,
      os.name as entity_name,
      os.rpts_count as reports_count,
      os.ttl_xp as total_xp,
      (os.id = (SELECT org_id FROM user_org)) as is_member
    FROM org_stats os
    WHERE os.id = (SELECT org_id FROM user_org);

  ELSIF p_category = 'vessel' THEN
    RETURN QUERY
    WITH user_vessel AS (
      SELECT current_vessel_id FROM profiles WHERE id = p_user_id
    ),
    vessel_stats AS (
      SELECT
        v.id,
        v.name,
        COUNT(r.id)::bigint as rpts_count,
        COALESCE(SUM(r.xp_earned), 0)::bigint as ttl_xp,
        RANK() OVER (ORDER BY COUNT(r.id) DESC, COALESCE(SUM(r.xp_earned), 0) DESC) as rnk
      FROM vessels v
      LEFT JOIN reports r ON r.vessel_id = v.id
        AND r.reported_at >= (now() - (p_days || ' days')::interval)
      GROUP BY v.id, v.name
    )
    SELECT
      vs.rnk as rank,
      vs.id as entity_id,
      vs.name as entity_name,
      vs.rpts_count as reports_count,
      vs.ttl_xp as total_xp,
      (vs.id = (SELECT current_vessel_id FROM user_vessel)) as is_member
    FROM vessel_stats vs
    WHERE vs.id = (SELECT current_vessel_id FROM user_vessel);

  ELSE  -- 'user' category
    RETURN QUERY
    WITH user_stats AS (
      SELECT
        p.id,
        p.display_name,
        COUNT(r.id)::bigint as rpts_count,
        COALESCE(SUM(r.xp_earned), 0)::bigint as ttl_xp,
        RANK() OVER (ORDER BY COUNT(r.id) DESC, COALESCE(SUM(r.xp_earned), 0) DESC) as rnk
      FROM profiles p
      LEFT JOIN reports r ON r.user_id = p.id
        AND r.reported_at >= (now() - (p_days || ' days')::interval)
      GROUP BY p.id, p.display_name
    )
    SELECT
      us.rnk as rank,
      us.id as entity_id,
      us.display_name as entity_name,
      us.rpts_count as reports_count,
      us.ttl_xp as total_xp,
      true as is_member
    FROM user_stats us
    WHERE us.id = p_user_id;
  END IF;
END;
$$;

-- ============================================================================
-- PART 6: GRANT PERMISSIONS
-- ============================================================================

GRANT EXECUTE ON FUNCTION public.get_user_leaderboard(int, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_user_leaderboard(int, int) TO anon;
GRANT EXECUTE ON FUNCTION public.get_organization_leaderboard(int, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_organization_leaderboard(int, int) TO anon;
GRANT EXECUTE ON FUNCTION public.get_vessel_leaderboard(int, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_vessel_leaderboard(int, int) TO anon;
GRANT EXECUTE ON FUNCTION public.get_user_category_rank(uuid, text, int) TO authenticated;
