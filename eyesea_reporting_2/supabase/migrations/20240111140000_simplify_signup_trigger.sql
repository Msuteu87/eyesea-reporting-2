-- Migration: Simplify Signup Trigger (Debug)
-- Reason: Still getting 500 error. Simplifying to minimal insert to isolate the issue.

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  -- Minimal insert: rely on DB defaults for everything else
  -- We only take ID. 
  -- We try to take full_name if available, but no casting of enums.
  INSERT INTO public.profiles (id, display_name, avatar_url)
  VALUES (
    new.id,
    new.raw_user_meta_data->>'full_name',
    new.raw_user_meta_data->>'avatar_url'
  )
  ON CONFLICT (id) DO NOTHING;
  
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;
