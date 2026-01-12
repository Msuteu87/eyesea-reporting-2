-- Add display_name column to profiles table to match App usages
ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS display_name text;

-- Add city column as it is part of the UserEntity and likely to be used soon
ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS city text;

-- Add index for display_name as it is often queried/displayed
CREATE INDEX IF NOT EXISTS idx_profiles_display_name ON public.profiles(display_name);

-- (Optional) Copy full_name to display_name if display_name is null
UPDATE public.profiles
SET display_name = full_name
WHERE display_name IS NULL AND full_name IS NOT NULL;
