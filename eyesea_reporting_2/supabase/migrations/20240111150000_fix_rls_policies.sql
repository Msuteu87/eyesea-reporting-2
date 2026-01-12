-- Migration: Fix RLS Policies
-- Reason: User reported 500 error, and noticed missing RLS policies for organization_members and profiles insertion.

-- 1. Profiles: Allow Users to Insert their own profile (in case trigger fails or client needs to do it)
DROP POLICY IF EXISTS "Users can insert own profile" ON public.profiles;
CREATE POLICY "Users can insert own profile" ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id);

-- 2. Organization Members: Was missing policies entirely!
-- Allow everyone to read members (simplification for MVP)
DROP POLICY IF EXISTS "Organization members public view" ON public.organization_members;
CREATE POLICY "Organization members public view" ON public.organization_members FOR SELECT USING (true);

-- 3. Organizations: Ensure nice insertion just in case (though mostly admin)
-- (Skipping for now to focus on User flow)

-- 4. Re-grant permissions for Enum usage (paranoia check)
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated, service_role;
