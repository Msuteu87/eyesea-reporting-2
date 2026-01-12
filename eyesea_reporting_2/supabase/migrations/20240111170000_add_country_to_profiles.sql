-- Add country column to profiles table
ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS country text;

-- Add index for potential filtering/analytics
CREATE INDEX IF NOT EXISTS idx_profiles_country ON public.profiles(country);
