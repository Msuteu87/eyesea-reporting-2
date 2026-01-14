-- Migration: Security Hardening
-- Revokes overly permissive grants from earlier migrations and establishes proper RLS-based security

-- ============================================
-- 1. REVOKE DANGEROUS GRANTS
-- These were added in 20240111150000_fix_rls_policies.sql and 20240111120000_fix_signup_trigger.sql
-- and grant ALL permissions to anon, which bypasses RLS
-- ============================================

REVOKE ALL ON ALL TABLES IN SCHEMA public FROM anon;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM anon;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM anon;

-- Also revoke from authenticated to reset cleanly
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM authenticated;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM authenticated;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM authenticated;

-- ============================================
-- 2. RE-GRANT SCHEMA USAGE (required for any access)
-- ============================================

GRANT USAGE ON SCHEMA public TO anon, authenticated;

-- ============================================
-- 3. RE-ESTABLISH PROPER TABLE PERMISSIONS
-- anon: SELECT only on public-readable tables (respects RLS)
-- authenticated: appropriate CRUD per table (respects RLS)
-- ============================================

-- Profiles: public read, authenticated can update own
GRANT SELECT ON public.profiles TO anon, authenticated;
GRANT INSERT, UPDATE ON public.profiles TO authenticated;

-- Organizations: public read only
GRANT SELECT ON public.organizations TO anon, authenticated;

-- Organization members: public read, authenticated can join
GRANT SELECT ON public.organization_members TO anon, authenticated;
GRANT INSERT ON public.organization_members TO authenticated;

-- Reports: public read, authenticated CRUD (RLS enforces ownership)
GRANT SELECT ON public.reports TO anon, authenticated;
GRANT INSERT, UPDATE, DELETE ON public.reports TO authenticated;

-- Report images: public read, authenticated insert
GRANT SELECT ON public.report_images TO anon, authenticated;
GRANT INSERT ON public.report_images TO authenticated;

-- AI analysis: public read, authenticated insert
GRANT SELECT ON public.ai_analysis TO anon, authenticated;
GRANT INSERT ON public.ai_analysis TO authenticated;

-- Badges: public read only
GRANT SELECT ON public.badges TO anon, authenticated;

-- User badges: public read only (system grants badges via triggers)
GRANT SELECT ON public.user_badges TO anon, authenticated;

-- Notifications: authenticated only (personal data)
GRANT SELECT, UPDATE ON public.notifications TO authenticated;
-- NOTE: No INSERT grant - notifications are created by SECURITY DEFINER triggers only

-- Report thanks: public read, authenticated can add/remove own
GRANT SELECT ON public.report_thanks TO anon, authenticated;
GRANT INSERT, DELETE ON public.report_thanks TO authenticated;

-- Events (if exists)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'events' AND table_schema = 'public') THEN
    EXECUTE 'GRANT SELECT ON public.events TO anon, authenticated';
    EXECUTE 'GRANT INSERT, UPDATE, DELETE ON public.events TO authenticated';
  END IF;
END $$;

-- Event attendees (if exists)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'event_attendees' AND table_schema = 'public') THEN
    EXECUTE 'GRANT SELECT ON public.event_attendees TO anon, authenticated';
    EXECUTE 'GRANT INSERT, DELETE ON public.event_attendees TO authenticated';
  END IF;
END $$;

-- ============================================
-- 4. FIX NOTIFICATIONS INSERT POLICY
-- The old policy "Service role can insert notifications" used WITH CHECK (true)
-- which allows ANYONE to insert. Only triggers should insert notifications.
-- ============================================

DROP POLICY IF EXISTS "Service role can insert notifications." ON public.notifications;

-- No INSERT policy for regular users - notifications are system-generated only
-- The trigger functions use SECURITY DEFINER so they bypass RLS

-- ============================================
-- 5. RE-GRANT FUNCTION EXECUTE PERMISSIONS (SELECTIVE)
-- Only grant to appropriate roles based on function purpose
-- ============================================

-- Public map/feed functions (safe for anonymous viewing)
GRANT EXECUTE ON FUNCTION public.get_reports_with_location() TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_social_feed(uuid, text, text, int, int) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_leaderboard(int) TO anon, authenticated;

-- Spatial query (public data, anonymous allowed for map display)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'get_reports_in_bounds') THEN
    EXECUTE 'GRANT EXECUTE ON FUNCTION public.get_reports_in_bounds(double precision, double precision, double precision, double precision, int) TO anon, authenticated';
  END IF;
END $$;

-- User-specific functions (authenticated only - will add auth.uid() checks in next migration)
GRANT EXECUTE ON FUNCTION public.get_user_reports(uuid, text, int, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_user_rank(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_user_total_xp(uuid) TO authenticated;

-- Event functions (if exist)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'get_events_with_details') THEN
    -- Correct signature: (uuid, text, int) for (p_user_id, p_filter, p_limit)
    EXECUTE 'GRANT EXECUTE ON FUNCTION public.get_events_with_details(uuid, text, int) TO anon, authenticated';
  END IF;
  IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'get_event_attendees') THEN
    EXECUTE 'GRANT EXECUTE ON FUNCTION public.get_event_attendees(uuid) TO anon, authenticated';
  END IF;
END $$;

-- ============================================
-- 6. GRANT SEQUENCE USAGE (needed for INSERT operations)
-- ============================================

GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO authenticated;
