-- Fix fraud detection for API submissions
-- API reports don't have AI analysis (no YOLO processing), so fraud detection
-- incorrectly flags them when pollution_counts are submitted
--
-- Root cause: detect_fraud() Check 0 triggers "AI detected no items, but user entered X"
-- because ai_baseline is empty for API submissions

-- =============================================================================
-- 1. UPDATE validate_report_on_insert() TO SKIP FRAUD DETECTION FOR API REPORTS
-- =============================================================================

CREATE OR REPLACE FUNCTION validate_report_on_insert()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  ai_baseline jsonb;
  server_xp int;
  server_weight decimal;
  fraud_result record;
  client_xp int;
  scene_labels_arr text[];
BEGIN
  -- Calculate weight for all reports (always authoritative)
  server_weight := calculate_total_weight(NEW.pollution_counts);

  -- ==========================================================================
  -- SKIP FRAUD DETECTION FOR API SUBMISSIONS
  -- API reports don't have AI analysis, so fraud checks would incorrectly flag
  -- legitimate submissions. We still calculate weight/XP server-side.
  -- ==========================================================================
  IF NEW.api_source IS NOT NULL THEN
    server_xp := calculate_xp(
      NEW.pollution_counts,
      NEW.severity,
      NEW.location IS NOT NULL,
      true, -- has_photo assumed true (required for API submission)
      ARRAY[]::text[] -- no scene labels for API submissions
    );
    NEW.total_weight_kg := server_weight;
    NEW.xp_earned := server_xp;
    NEW.fraud_score := 0;
    NEW.is_flagged := false;
    NEW.fraud_warnings := NULL;
    RETURN NEW;
  END IF;

  -- ==========================================================================
  -- REGULAR FRAUD DETECTION FOR APP SUBMISSIONS
  -- ==========================================================================

  -- Get AI baseline from ai_analysis table if exists
  SELECT aa.pollution_type_counts, aa.scene_labels
  INTO ai_baseline, scene_labels_arr
  FROM ai_analysis aa
  WHERE aa.report_id = NEW.id
  ORDER BY aa.analyzed_at DESC
  LIMIT 1;

  -- Default to empty if no AI analysis found
  ai_baseline := COALESCE(ai_baseline, '{}'::jsonb);
  scene_labels_arr := COALESCE(scene_labels_arr, ARRAY[]::text[]);

  -- Recalculate XP (authoritative)
  server_xp := calculate_xp(
    NEW.pollution_counts,
    NEW.severity,
    NEW.location IS NOT NULL,
    true, -- has_photo assumed true (required for submission)
    scene_labels_arr
  );

  -- Run fraud detection
  SELECT * INTO fraud_result
  FROM detect_fraud(NEW.pollution_counts, ai_baseline, NEW.severity);

  -- Store client-submitted XP for comparison (optional audit)
  client_xp := COALESCE(NEW.xp_earned, 0);

  -- Check for client XP manipulation
  IF client_xp > server_xp * 1.5 THEN
    fraud_result.warnings := array_append(
      fraud_result.warnings,
      format('Client XP (%s) exceeds server calculation (%s) by >50%%', client_xp, server_xp)
    );
    fraud_result.fraud_score := LEAST(fraud_result.fraud_score + 0.2, 1.0);
    fraud_result.is_suspicious := fraud_result.fraud_score >= 0.5;
  END IF;

  -- Update with server-calculated values (authoritative)
  NEW.total_weight_kg := server_weight;
  NEW.xp_earned := server_xp;

  -- Update fraud fields if server detects more issues
  IF fraud_result.fraud_score > COALESCE(NEW.fraud_score, 0) THEN
    NEW.fraud_score := fraud_result.fraud_score;
    NEW.is_flagged := fraud_result.is_suspicious;
    NEW.fraud_warnings := fraud_result.warnings;
  END IF;

  RETURN NEW;
END;
$$;

-- Note: Trigger already exists on reports table, no need to recreate it

-- =============================================================================
-- 2. ENSURE FEED FUNCTION GRANTS ARE IN PLACE
-- =============================================================================

-- Re-grant execute permissions on get_social_feed (may have been revoked)
GRANT EXECUTE ON FUNCTION get_social_feed TO anon, authenticated;

-- Also ensure report_thanks grants are correct for feed functionality
GRANT SELECT ON public.report_thanks TO anon, authenticated;
GRANT INSERT, DELETE ON public.report_thanks TO authenticated;

-- =============================================================================
-- 3. COMMENT FOR DOCUMENTATION
-- =============================================================================

COMMENT ON FUNCTION validate_report_on_insert IS
  'Server-side validation trigger that runs on report insert.
   Calculates authoritative weight and XP values.
   SKIPS fraud detection for API submissions (api_source IS NOT NULL) since they lack AI analysis.
   For app submissions, compares user counts against AI baseline and flags suspicious patterns.';
