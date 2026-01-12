-- Migration: Add Social Feed support with Thank You feature
-- Creates report_thanks table and get_social_feed RPC function

-- ============================================
-- 1. Create report_thanks table for "Thank You" feature
-- ============================================

CREATE TABLE IF NOT EXISTS public.report_thanks (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  report_id uuid REFERENCES public.reports(id) ON DELETE CASCADE NOT NULL,
  user_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  created_at timestamptz DEFAULT now(),
  UNIQUE(report_id, user_id)  -- Prevent duplicate thanks from same user
);

-- Enable RLS
ALTER TABLE public.report_thanks ENABLE ROW LEVEL SECURITY;

-- RLS Policies for report_thanks

-- Anyone can view thanks (needed for counting)
DROP POLICY IF EXISTS "Thanks are viewable by everyone" ON public.report_thanks;
CREATE POLICY "Thanks are viewable by everyone"
  ON public.report_thanks FOR SELECT USING (true);

-- Authenticated users can insert thanks (but not for their own reports)
DROP POLICY IF EXISTS "Authenticated users can thank others reports" ON public.report_thanks;
CREATE POLICY "Authenticated users can thank others reports"
  ON public.report_thanks FOR INSERT
  WITH CHECK (
    auth.uid() = user_id
    AND auth.uid() != (SELECT r.user_id FROM public.reports r WHERE r.id = report_id)
  );

-- Users can remove their own thanks
DROP POLICY IF EXISTS "Users can remove their own thanks" ON public.report_thanks;
CREATE POLICY "Users can remove their own thanks"
  ON public.report_thanks FOR DELETE
  USING (auth.uid() = user_id);

-- Performance indexes
CREATE INDEX IF NOT EXISTS idx_report_thanks_report_id ON public.report_thanks(report_id);
CREATE INDEX IF NOT EXISTS idx_report_thanks_user_id ON public.report_thanks(user_id);

-- ============================================
-- 2. Create RPC function for fetching social feed
-- ============================================

CREATE OR REPLACE FUNCTION public.get_social_feed(
  p_user_id uuid DEFAULT NULL,
  p_country text DEFAULT NULL,
  p_city text DEFAULT NULL,
  p_limit int DEFAULT 20,
  p_offset int DEFAULT 0
)
RETURNS TABLE (
  id uuid,
  user_id uuid,
  display_name text,
  avatar_url text,
  location text,
  city text,
  country text,
  pollution_type pollution_type,
  severity int,
  status report_status,
  notes text,
  reported_at timestamptz,
  total_weight_kg decimal,
  pollution_counts jsonb,
  image_url text,
  scene_labels text[],
  thanks_count bigint,
  user_has_thanked boolean
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    r.id,
    r.user_id,
    p.display_name,
    p.avatar_url,
    ST_AsText(r.location) as location,
    r.city,
    r.country,
    r.pollution_type,
    r.severity,
    r.status,
    r.notes,
    r.reported_at,
    r.total_weight_kg,
    r.pollution_counts,
    (
      SELECT ri.storage_path
      FROM report_images ri
      WHERE ri.report_id = r.id AND ri.is_primary = true
      LIMIT 1
    ) as image_url,
    (
      SELECT ai.scene_labels
      FROM ai_analysis ai
      WHERE ai.report_id = r.id
      LIMIT 1
    ) as scene_labels,
    (
      SELECT COUNT(*)
      FROM report_thanks rt
      WHERE rt.report_id = r.id
    ) as thanks_count,
    (
      p_user_id IS NOT NULL
      AND EXISTS(
        SELECT 1
        FROM report_thanks rt
        WHERE rt.report_id = r.id AND rt.user_id = p_user_id
      )
    ) as user_has_thanked
  FROM reports r
  LEFT JOIN profiles p ON r.user_id = p.id
  WHERE
    (p_country IS NULL OR r.country = p_country)
    AND (p_city IS NULL OR r.city = p_city)
  ORDER BY r.reported_at DESC
  LIMIT p_limit
  OFFSET p_offset;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION public.get_social_feed(uuid, text, text, int, int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_social_feed(uuid, text, text, int, int) TO anon;
