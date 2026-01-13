-- Function to get user's leaderboard rank and stats
CREATE OR REPLACE FUNCTION public.get_user_rank(p_user_id uuid)
RETURNS TABLE (
  rank bigint,
  total_users bigint,
  reports_count int,
  total_xp bigint
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
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
      id,
      reports_count,
      total_xp,
      RANK() OVER (ORDER BY reports_count DESC, total_xp DESC) as rank
    FROM user_stats
  )
  SELECT
    r.rank,
    (SELECT COUNT(*) FROM profiles)::bigint as total_users,
    r.reports_count,
    r.total_xp
  FROM ranked r
  WHERE r.id = p_user_id;
$$;

-- Function to get user's total XP from all reports
CREATE OR REPLACE FUNCTION public.get_user_total_xp(p_user_id uuid)
RETURNS bigint
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(SUM(xp_earned), 0)::bigint
  FROM reports
  WHERE user_id = p_user_id;
$$;

-- Function to get top users for leaderboard
CREATE OR REPLACE FUNCTION public.get_leaderboard(p_limit int DEFAULT 10)
RETURNS TABLE (
  rank bigint,
  user_id uuid,
  display_name text,
  avatar_url text,
  reports_count int,
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
      p.reports_count,
      COALESCE(SUM(r.xp_earned), 0)::bigint as total_xp
    FROM profiles p
    LEFT JOIN reports r ON r.user_id = p.id
    GROUP BY p.id, p.display_name, p.avatar_url, p.reports_count
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

-- Grant permissions
GRANT EXECUTE ON FUNCTION public.get_user_rank(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_user_total_xp(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_leaderboard(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_leaderboard(int) TO anon;
