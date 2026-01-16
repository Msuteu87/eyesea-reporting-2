-- ============================================================================
-- SECURITY & PERFORMANCE FIXES
-- Addresses Supabase Advisor warnings and errors
-- ============================================================================
--
-- USER ROLE RULES:
-- ┌──────────────────┬──────────────┬────────────────┬────────────────────────┐
-- │ Role             │ Can Create   │ Vessel/Ship    │ Organization           │
-- │                  │ Events       │                │                        │
-- ├──────────────────┼──────────────┼────────────────┼────────────────────────┤
-- │ volunteer        │ No           │ Cannot join    │ Optional               │
-- │ seafarer         │ No           │ Required       │ Required               │
-- │ ambassador       │ Yes          │ N/A            │ N/A                    │
-- │ eyesea_rep       │ Yes          │ Cannot join    │ Must be Eyesea org     │
-- │ admin            │ N/A          │ N/A            │ N/A                    │
-- └──────────────────┴──────────────┴────────────────┴────────────────────────┘
--

-- ============================================================================
-- PART 0: ADD NEW USER ROLE
-- ============================================================================
-- IMPORTANT: Run this FIRST in a separate query, then run the rest.
-- PostgreSQL requires enum values to be committed before they can be used.
--
-- Step 1 - Run this alone first:
--   ALTER TYPE public.user_role ADD VALUE IF NOT EXISTS 'eyesea_rep';
--
-- Step 2 - Then run everything below this comment.
-- ============================================================================

-- ============================================================================
-- PART 1: SECURITY FIXES
-- ============================================================================

-- 1A. Enable RLS on tables missing it (ERROR level)
-- NOTE: spatial_ref_sys is a PostGIS system table owned by postgres superuser.
-- We cannot modify it via SQL Editor. Dismiss this warning in Supabase Advisor
-- as it's a read-only reference table with no sensitive data.

ALTER TABLE public.pollution_weights ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS pollution_weights_read ON public.pollution_weights;
CREATE POLICY pollution_weights_read ON public.pollution_weights FOR SELECT USING (true);

-- 1B. Fix location_cache INSERT policy (require authentication)
DROP POLICY IF EXISTS location_cache_insert ON location_cache;
CREATE POLICY location_cache_insert ON location_cache
  FOR INSERT WITH CHECK ((select auth.role()) = 'authenticated');

-- 1C. Set immutable search_path on all SECURITY DEFINER functions
ALTER FUNCTION public.detect_fraud SET search_path = public;
ALTER FUNCTION public.calculate_xp SET search_path = public;
ALTER FUNCTION public.calculate_total_weight SET search_path = public;
ALTER FUNCTION public.join_event SET search_path = public;
ALTER FUNCTION public.leave_event SET search_path = public;
ALTER FUNCTION public.check_and_award_badges SET search_path = public;
ALTER FUNCTION public.award_team_player_badge SET search_path = public;
ALTER FUNCTION public.update_user_xp SET search_path = public;
ALTER FUNCTION public.update_reports_count SET search_path = public;
ALTER FUNCTION public.update_reports_updated_at SET search_path = public;
ALTER FUNCTION public.update_updated_at_column SET search_path = public;
ALTER FUNCTION public.cleanup_expired_location_cache SET search_path = public;
ALTER FUNCTION public.get_events_with_details SET search_path = public;
ALTER FUNCTION public.get_event_attendees SET search_path = public;
ALTER FUNCTION public.notify_report_recovered SET search_path = public;

-- ============================================================================
-- PART 2: PERFORMANCE FIXES - Remove Duplicate Policies
-- ============================================================================

-- profiles: Remove duplicate INSERT policy
DROP POLICY IF EXISTS "Users can insert own profile" ON profiles;

-- events: Remove duplicate SELECT policy (typo version without period)
DROP POLICY IF EXISTS "Events are viewable by everyone" ON events;

-- events: Remove duplicate INSERT policy (keep Ambassadors version which has role check)
DROP POLICY IF EXISTS "Users can create events" ON events;

-- events: Remove duplicate UPDATE policy (keep Ambassadors version which has role check)
DROP POLICY IF EXISTS "Organizers can update their events" ON events;

-- ============================================================================
-- PART 3: PERFORMANCE FIXES - Optimize RLS Policies with (select auth.uid())
-- This prevents re-evaluation of auth.uid() for each row
-- ============================================================================

-- profiles policies
DROP POLICY IF EXISTS "Users can insert their own profile." ON profiles;
CREATE POLICY "Users can insert their own profile." ON profiles
  FOR INSERT WITH CHECK ((select auth.uid()) = id);

DROP POLICY IF EXISTS "Users can update own profile." ON profiles;
CREATE POLICY "Users can update own profile." ON profiles
  FOR UPDATE USING ((select auth.uid()) = id);

-- reports policies
DROP POLICY IF EXISTS "Authenticated users can insert reports." ON reports;
CREATE POLICY "Authenticated users can insert reports." ON reports
  FOR INSERT WITH CHECK ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can update own reports." ON reports;
CREATE POLICY "Users can update own reports." ON reports
  FOR UPDATE USING ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can delete own reports." ON reports;
CREATE POLICY "Users can delete own reports." ON reports
  FOR DELETE USING ((select auth.uid()) = user_id);

-- events policies
-- Only ambassadors and eyesea_reps can create events
DROP POLICY IF EXISTS "Ambassadors can create events." ON events;
DROP POLICY IF EXISTS "Ambassadors and Eyesea reps can create events" ON events;
CREATE POLICY "Ambassadors and Eyesea reps can create events" ON events
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = (select auth.uid())
      AND role IN ('ambassador'::user_role, 'eyesea_rep'::user_role)
    )
  );

-- Only the organizer (who must be ambassador or eyesea_rep) can update their events
DROP POLICY IF EXISTS "Ambassadors can update own events." ON events;
DROP POLICY IF EXISTS "Event organizers can update own events" ON events;
CREATE POLICY "Event organizers can update own events" ON events
  FOR UPDATE USING (
    (select auth.uid()) = organizer_id
    AND EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = (select auth.uid())
      AND role IN ('ambassador'::user_role, 'eyesea_rep'::user_role)
    )
  );

-- Only the organizer can delete their events
DROP POLICY IF EXISTS "Organizers can delete their events" ON events;
DROP POLICY IF EXISTS "Event organizers can delete their events" ON events;
CREATE POLICY "Event organizers can delete their events" ON events
  FOR DELETE USING (
    (select auth.uid()) = organizer_id
    AND EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = (select auth.uid())
      AND role IN ('ambassador'::user_role, 'eyesea_rep'::user_role)
    )
  );

-- event_attendees policies
DROP POLICY IF EXISTS "Users can join events" ON event_attendees;
CREATE POLICY "Users can join events" ON event_attendees
  FOR INSERT WITH CHECK ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can leave events" ON event_attendees;
CREATE POLICY "Users can leave events" ON event_attendees
  FOR DELETE USING ((select auth.uid()) = user_id);

-- event_participants policies (if table exists)
DROP POLICY IF EXISTS "Users can update their participation status." ON event_participants;
CREATE POLICY "Users can update their participation status." ON event_participants
  FOR UPDATE USING ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS "Authenticated users can join events." ON event_participants;
CREATE POLICY "Authenticated users can join events." ON event_participants
  FOR INSERT WITH CHECK ((select auth.uid()) = user_id);

-- report_images policy
DROP POLICY IF EXISTS "Users can insert images for their reports." ON report_images;
CREATE POLICY "Users can insert images for their reports." ON report_images
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM reports
      WHERE id = report_images.report_id
      AND user_id = (select auth.uid())
    )
  );

-- ai_analysis policy
DROP POLICY IF EXISTS "Users can insert AI analysis for their reports." ON ai_analysis;
CREATE POLICY "Users can insert AI analysis for their reports." ON ai_analysis
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM reports
      WHERE id = ai_analysis.report_id
      AND user_id = (select auth.uid())
    )
  );

-- notifications policies
DROP POLICY IF EXISTS "Users can view own notifications." ON notifications;
CREATE POLICY "Users can view own notifications." ON notifications
  FOR SELECT USING ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can update own notifications." ON notifications;
CREATE POLICY "Users can update own notifications." ON notifications
  FOR UPDATE USING ((select auth.uid()) = user_id);

-- report_thanks policies
DROP POLICY IF EXISTS "Authenticated users can thank others reports" ON report_thanks;
CREATE POLICY "Authenticated users can thank others reports" ON report_thanks
  FOR INSERT WITH CHECK ((select auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can remove their own thanks" ON report_thanks;
CREATE POLICY "Users can remove their own thanks" ON report_thanks
  FOR DELETE USING ((select auth.uid()) = user_id);

-- ============================================================================
-- PART 4: PERFORMANCE FIXES - Add Missing Foreign Key Indexes
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_event_participants_user_id ON event_participants(user_id);
CREATE INDEX IF NOT EXISTS idx_organization_members_org_id ON organization_members(org_id);
CREATE INDEX IF NOT EXISTS idx_profiles_current_vessel_id ON profiles(current_vessel_id);
CREATE INDEX IF NOT EXISTS idx_report_images_report_id ON report_images(report_id);
CREATE INDEX IF NOT EXISTS idx_reports_event_id ON reports(event_id);
CREATE INDEX IF NOT EXISTS idx_reports_org_id ON reports(org_id);
CREATE INDEX IF NOT EXISTS idx_reports_user_id ON reports(user_id);
CREATE INDEX IF NOT EXISTS idx_reports_vessel_id ON reports(vessel_id);
CREATE INDEX IF NOT EXISTS idx_user_badges_badge_id ON user_badges(badge_id);
CREATE INDEX IF NOT EXISTS idx_vessels_org_id ON vessels(org_id);
