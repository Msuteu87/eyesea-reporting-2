-- Update AI Analysis table to reflect on-device YOLO analysis instead of Gemini
-- Migration: Replace gemini_response with yolo-specific fields

-- Rename gemini_response column to ai_response for generic AI data storage (if it exists)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'ai_analysis' AND column_name = 'gemini_response'
  ) THEN
    ALTER TABLE public.ai_analysis RENAME COLUMN gemini_response TO ai_response;
  END IF;
END $$;

-- Add comment to clarify the new purpose (only if column exists)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'ai_analysis' AND column_name = 'ai_response'
  ) THEN
    COMMENT ON COLUMN public.ai_analysis.ai_response IS
      'JSONB field storing on-device YOLO analysis results including detected objects, counts, and scene labels';
  END IF;
END $$;

-- Add new columns for YOLO-specific data
alter table public.ai_analysis
  add column if not exists detected_objects jsonb default '[]'::jsonb,
  add column if not exists people_count int default 0,
  add column if not exists scene_labels text[] default '{}',
  add column if not exists pollution_type_counts jsonb default '{}'::jsonb;

-- Add comments for new columns
comment on column public.ai_analysis.detected_objects is
  'Array of detected objects with their class names and confidence scores';

comment on column public.ai_analysis.people_count is
  'Number of people detected in the image (used for privacy filtering)';

comment on column public.ai_analysis.scene_labels is
  'Array of scene/environment labels (e.g., Beach, Outdoor, Water)';

comment on column public.ai_analysis.pollution_type_counts is
  'Object mapping pollution types to their detected item counts (e.g., {"plastic": 4, "fishingGear": 2})';
