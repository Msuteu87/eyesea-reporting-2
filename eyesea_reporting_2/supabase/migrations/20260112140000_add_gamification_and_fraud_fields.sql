-- Migration: Add gamification (XP) and fraud detection fields to reports
-- Also adds total_xp tracking to profiles

-- Add 'container' to pollution_type enum (Flutter has it, DB doesn't)
ALTER TYPE pollution_type ADD VALUE IF NOT EXISTS 'container';

-- Expand reports table with new fields
ALTER TABLE public.reports
  ADD COLUMN IF NOT EXISTS pollution_counts jsonb DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS total_weight_kg decimal(10,3) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS xp_earned int DEFAULT 0,
  ADD COLUMN IF NOT EXISTS is_flagged boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS fraud_score decimal(3,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS fraud_warnings text[] DEFAULT '{}';

-- Add total_xp to profiles for gamification tracking
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS total_xp int DEFAULT 0;

-- Trigger to update user's total XP when report is inserted/deleted
CREATE OR REPLACE FUNCTION public.update_user_xp()
RETURNS TRIGGER AS $$
BEGIN
  IF (TG_OP = 'INSERT') THEN
    UPDATE public.profiles
    SET total_xp = total_xp + NEW.xp_earned
    WHERE id = NEW.user_id;
  ELSIF (TG_OP = 'DELETE') THEN
    UPDATE public.profiles
    SET total_xp = total_xp - OLD.xp_earned
    WHERE id = OLD.user_id;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_report_xp_change ON public.reports;
CREATE TRIGGER on_report_xp_change
  AFTER INSERT OR DELETE ON public.reports
  FOR EACH ROW EXECUTE FUNCTION public.update_user_xp();

-- Add RLS policy for ai_analysis INSERT (currently missing)
DROP POLICY IF EXISTS "Users can insert AI analysis for their reports." ON public.ai_analysis;
CREATE POLICY "Users can insert AI analysis for their reports." ON public.ai_analysis
  FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM public.reports WHERE id = ai_analysis.report_id AND user_id = auth.uid())
  );

-- Add comments for new columns
COMMENT ON COLUMN public.reports.pollution_counts IS 'JSON object mapping pollution types to item counts (e.g., {"plastic": 5, "debris": 3})';
COMMENT ON COLUMN public.reports.total_weight_kg IS 'Estimated total weight in kilograms based on item counts';
COMMENT ON COLUMN public.reports.xp_earned IS 'XP points earned for this report';
COMMENT ON COLUMN public.reports.is_flagged IS 'Whether this report was flagged by fraud detection';
COMMENT ON COLUMN public.reports.fraud_score IS 'Fraud detection score (0.0 = clean, 1.0 = highly suspicious)';
COMMENT ON COLUMN public.reports.fraud_warnings IS 'Array of fraud detection warning messages';
COMMENT ON COLUMN public.profiles.total_xp IS 'Cumulative XP earned across all reports';
