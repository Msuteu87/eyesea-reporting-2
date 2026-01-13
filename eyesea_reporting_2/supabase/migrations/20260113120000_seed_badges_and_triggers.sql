-- Add additional columns to badges table for automation
ALTER TABLE public.badges
ADD COLUMN IF NOT EXISTS slug text UNIQUE,
ADD COLUMN IF NOT EXISTS threshold_type text,
ADD COLUMN IF NOT EXISTS threshold_value int,
ADD COLUMN IF NOT EXISTS color text DEFAULT '#3B82F6';

-- Seed badge definitions
INSERT INTO public.badges (id, name, slug, icon, description, threshold_type, threshold_value, color) VALUES
  (gen_random_uuid(), 'First Report', 'first_report', 'award', 'Submit your first pollution report', 'reports_count', 1, '#F59E0B'),
  (gen_random_uuid(), 'Ocean Scout', 'ocean_scout', 'compass', 'Submit 10 pollution reports', 'reports_count', 10, '#3B82F6'),
  (gen_random_uuid(), 'Ocean Guardian', 'ocean_guardian', 'shield', 'Submit 50 pollution reports', 'reports_count', 50, '#8B5CF6'),
  (gen_random_uuid(), 'Ocean Hero', 'ocean_hero', 'trophy', 'Submit 100 pollution reports', 'reports_count', 100, '#EC4899'),
  (gen_random_uuid(), 'Week Warrior', 'week_warrior', 'flame', 'Maintain a 7-day reporting streak', 'streak_days', 7, '#EF4444'),
  (gen_random_uuid(), 'Month Master', 'month_master', 'zap', 'Maintain a 30-day reporting streak', 'streak_days', 30, '#F97316'),
  (gen_random_uuid(), 'Team Player', 'team_player', 'users', 'Join an organization', 'org_member', 1, '#14B8A6')
ON CONFLICT (slug) DO UPDATE SET
  name = EXCLUDED.name,
  icon = EXCLUDED.icon,
  description = EXCLUDED.description,
  threshold_type = EXCLUDED.threshold_type,
  threshold_value = EXCLUDED.threshold_value,
  color = EXCLUDED.color;

-- Function to check and award badges based on profile updates
CREATE OR REPLACE FUNCTION public.check_and_award_badges()
RETURNS TRIGGER AS $$
DECLARE
  badge_record RECORD;
BEGIN
  -- Check reports_count based badges
  FOR badge_record IN
    SELECT id FROM badges
    WHERE threshold_type = 'reports_count'
    AND threshold_value <= NEW.reports_count
  LOOP
    INSERT INTO user_badges (user_id, badge_id)
    VALUES (NEW.id, badge_record.id)
    ON CONFLICT (user_id, badge_id) DO NOTHING;
  END LOOP;

  -- Check streak_days based badges
  FOR badge_record IN
    SELECT id FROM badges
    WHERE threshold_type = 'streak_days'
    AND threshold_value <= NEW.streak_days
  LOOP
    INSERT INTO user_badges (user_id, badge_id)
    VALUES (NEW.id, badge_record.id)
    ON CONFLICT (user_id, badge_id) DO NOTHING;
  END LOOP;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to auto-award badges on profile update
DROP TRIGGER IF EXISTS on_profile_update_check_badges ON public.profiles;
CREATE TRIGGER on_profile_update_check_badges
  AFTER UPDATE OF reports_count, streak_days ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.check_and_award_badges();

-- Also check on insert (for new users who might already qualify)
DROP TRIGGER IF EXISTS on_profile_insert_check_badges ON public.profiles;
CREATE TRIGGER on_profile_insert_check_badges
  AFTER INSERT ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.check_and_award_badges();

-- Function to award team_player badge when user joins an organization
CREATE OR REPLACE FUNCTION public.award_team_player_badge()
RETURNS TRIGGER AS $$
DECLARE
  team_badge_id uuid;
BEGIN
  SELECT id INTO team_badge_id FROM badges WHERE slug = 'team_player';

  IF team_badge_id IS NOT NULL THEN
    INSERT INTO user_badges (user_id, badge_id)
    VALUES (NEW.user_id, team_badge_id)
    ON CONFLICT (user_id, badge_id) DO NOTHING;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to award team_player badge when joining an org
DROP TRIGGER IF EXISTS on_org_member_insert_award_badge ON public.organization_members;
CREATE TRIGGER on_org_member_insert_award_badge
  AFTER INSERT ON public.organization_members
  FOR EACH ROW
  EXECUTE FUNCTION public.award_team_player_badge();

-- RPC to fetch user badges with badge details
CREATE OR REPLACE FUNCTION public.get_user_badges(p_user_id uuid)
RETURNS TABLE (
  id uuid,
  badge_id uuid,
  name text,
  slug text,
  icon text,
  description text,
  color text,
  earned_at timestamptz
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    ub.id,
    b.id as badge_id,
    b.name,
    b.slug,
    b.icon,
    b.description,
    b.color,
    ub.earned_at
  FROM user_badges ub
  JOIN badges b ON b.id = ub.badge_id
  WHERE ub.user_id = p_user_id
  ORDER BY ub.earned_at DESC;
$$;

-- RPC to get all available badges (for showing locked badges)
CREATE OR REPLACE FUNCTION public.get_all_badges()
RETURNS TABLE (
  id uuid,
  name text,
  slug text,
  icon text,
  description text,
  color text,
  threshold_type text,
  threshold_value int
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    id,
    name,
    slug,
    icon,
    description,
    color,
    threshold_type,
    threshold_value
  FROM badges
  ORDER BY threshold_value ASC NULLS LAST;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION public.get_user_badges(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_user_badges(uuid) TO anon;
GRANT EXECUTE ON FUNCTION public.get_all_badges() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_all_badges() TO anon;
