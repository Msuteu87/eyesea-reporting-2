-- Migration: Fix Signup Trigger Permissions and Logic
-- Reason: User reported 500 error on sign up.

-- 1. Ensure Permissions are robust
GRANT USAGE ON SCHEMA public TO postgres, anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO postgres, anon, authenticated, service_role;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA public TO postgres, anon, authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO postgres, anon, authenticated, service_role;

-- 2. Verify user_role type existence (should exist, but ensuring valid state)
DO $$ BEGIN
    CREATE TYPE user_role AS ENUM ('volunteer', 'ambassador', 'admin', 'seafarer');
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

-- 3. Recreate the handle_new_user function with explicit search_path and robust insertion
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
DECLARE
  default_role public.user_role := 'volunteer';
BEGIN
  -- Insert with explicit casting and defaults
  INSERT INTO public.profiles (id, display_name, avatar_url, role)
  VALUES (
    new.id,
    new.raw_user_meta_data->>'full_name',
    new.raw_user_meta_data->>'avatar_url',
    -- Try to parse role from metadata, fallback to volunteer
    COALESCE(
      (new.raw_user_meta_data->>'role')::public.user_role,
      default_role
    )
  )
  ON CONFLICT (id) DO NOTHING;
  
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- 4. Ensure trigger is attached
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();
