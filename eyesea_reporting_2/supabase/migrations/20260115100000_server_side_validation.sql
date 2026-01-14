-- Server-Side Validation & Gamification Migration
-- Implements dual-calculation pattern: client calculates for UX, server validates as authoritative
-- Preserves offline-first functionality - client values used until sync, then server recalculates

-- ============================================================================
-- 1. AVERAGE WEIGHTS TABLE (mirrors Dart _averageWeights)
-- ============================================================================

CREATE TABLE IF NOT EXISTS pollution_weights (
  pollution_type pollution_type PRIMARY KEY,
  weight_kg decimal NOT NULL
);

INSERT INTO pollution_weights (pollution_type, weight_kg) VALUES
  ('plastic', 0.025),
  ('oil', 0.5),
  ('debris', 0.15),
  ('sewage', 1.0),
  ('fishing_gear', 2.5),
  ('container', 0.5),
  ('other', 0.1)
ON CONFLICT (pollution_type) DO UPDATE SET weight_kg = EXCLUDED.weight_kg;

-- ============================================================================
-- 2. SERVER-SIDE WEIGHT CALCULATION FUNCTION
-- ============================================================================

CREATE OR REPLACE FUNCTION calculate_total_weight(pollution_counts jsonb)
RETURNS decimal
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  total_weight decimal := 0;
  pollution_key text;
  item_count int;
  weight_per_item decimal;
BEGIN
  IF pollution_counts IS NULL OR pollution_counts = '{}'::jsonb THEN
    RETURN 0;
  END IF;

  FOR pollution_key, item_count IN
    SELECT key, (value)::int FROM jsonb_each_text(pollution_counts)
  LOOP
    -- Get weight from lookup table, default to 0.1 if not found
    SELECT COALESCE(pw.weight_kg, 0.1) INTO weight_per_item
    FROM pollution_weights pw
    WHERE pw.pollution_type::text = pollution_key;

    IF weight_per_item IS NULL THEN
      weight_per_item := 0.1;
    END IF;

    total_weight := total_weight + (weight_per_item * item_count);
  END LOOP;

  RETURN total_weight;
END;
$$;

-- ============================================================================
-- 3. SERVER-SIDE XP CALCULATION FUNCTION
-- Mirrors Dart PollutionCalculations.calculateXP()
-- ============================================================================

CREATE OR REPLACE FUNCTION calculate_xp(
  pollution_counts jsonb,
  severity int,
  has_location boolean DEFAULT true,
  has_photo boolean DEFAULT true,
  scene_labels text[] DEFAULT ARRAY[]::text[]
)
RETURNS int
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  total_xp int := 0;
  total_items int := 0;
  total_weight decimal;
  type_count int;
  item_bonus int;
  weight_bonus int;
  severity_bonus int;
  label text;
  has_beach_water boolean := false;
BEGIN
  -- Base XP for submitting a report
  total_xp := 25;

  -- Photo bonus
  IF has_photo THEN
    total_xp := total_xp + 5;
  END IF;

  -- Location bonus
  IF has_location THEN
    total_xp := total_xp + 10;
  END IF;

  -- Check for beach/water/ocean in scene labels
  FOREACH label IN ARRAY scene_labels
  LOOP
    IF lower(label) LIKE '%beach%' OR lower(label) LIKE '%water%' OR lower(label) LIKE '%ocean%' THEN
      has_beach_water := true;
      EXIT;
    END IF;
  END LOOP;

  IF has_beach_water THEN
    total_xp := total_xp + 10;
  END IF;

  -- Severity bonus: (severity - 1) * 5
  severity_bonus := (severity - 1) * 5;
  total_xp := total_xp + severity_bonus;

  -- Count pollution types and total items
  IF pollution_counts IS NOT NULL AND pollution_counts != '{}'::jsonb THEN
    SELECT COUNT(*), COALESCE(SUM((value)::int), 0)
    INTO type_count, total_items
    FROM jsonb_each_text(pollution_counts);

    -- Multiple types bonus
    IF type_count > 1 THEN
      total_xp := total_xp + ((type_count - 1) * 5);
    END IF;

    -- Calculate weight
    total_weight := calculate_total_weight(pollution_counts);

    -- Per-item bonus (capped at 50)
    item_bonus := LEAST(total_items, 50);
    total_xp := total_xp + item_bonus;

    -- Weight bonus: +3 XP per kg (capped at 30)
    weight_bonus := LEAST(ROUND(total_weight * 3)::int, 30);
    total_xp := total_xp + weight_bonus;

    -- Volume tier bonus
    IF total_items >= 20 THEN
      total_xp := total_xp + 20;
    ELSIF total_items >= 10 THEN
      total_xp := total_xp + 10;
    ELSIF total_items >= 5 THEN
      total_xp := total_xp + 5;
    END IF;
  END IF;

  RETURN total_xp;
END;
$$;

-- ============================================================================
-- 4. SERVER-SIDE FRAUD DETECTION FUNCTION
-- Compares user-submitted counts vs AI analysis baseline
-- ============================================================================

CREATE OR REPLACE FUNCTION detect_fraud(
  user_counts jsonb,
  ai_baseline jsonb,
  severity int
)
RETURNS TABLE (
  is_suspicious boolean,
  fraud_score decimal,
  warnings text[]
)
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  warnings_list text[] := ARRAY[]::text[];
  fraud_score_calc decimal := 0;
  user_total int := 0;
  ai_total int := 0;
  pollution_key text;
  user_count int;
  ai_count int;
  expected_severity int;
  max_reasonable int;
BEGIN
  -- Calculate totals
  IF user_counts IS NOT NULL AND user_counts != '{}'::jsonb THEN
    SELECT COALESCE(SUM((value)::int), 0) INTO user_total
    FROM jsonb_each_text(user_counts);
  END IF;

  IF ai_baseline IS NOT NULL AND ai_baseline != '{}'::jsonb THEN
    SELECT COALESCE(SUM((value)::int), 0) INTO ai_total
    FROM jsonb_each_text(ai_baseline);
  END IF;

  -- Check 0: AI detected nothing but user added many items
  IF ai_total = 0 AND user_total > 10 THEN
    warnings_list := array_append(warnings_list,
      format('AI detected no items, but user entered %s', user_total));
    fraud_score_calc := fraud_score_calc + 0.25;
  END IF;

  -- Check 1: Massive inflation (user > 3x AI baseline)
  IF ai_total > 0 AND user_total > ai_total * 3 THEN
    warnings_list := array_append(warnings_list,
      format('Count inflated %s%% above AI detection',
        ROUND((user_total::decimal / ai_total) * 100)));
    fraud_score_calc := fraud_score_calc + 0.4;
  END IF;

  -- Check 2: Per-type inflation
  IF user_counts IS NOT NULL THEN
    FOR pollution_key, user_count IN
      SELECT key, (value)::int FROM jsonb_each_text(user_counts)
    LOOP
      ai_count := COALESCE((ai_baseline->>pollution_key)::int, 0);

      -- Flag if user count > 2x AI count
      IF ai_count > 0 AND user_count > ai_count * 2 THEN
        warnings_list := array_append(warnings_list,
          format('%s count inflated %s%%', pollution_key,
            ROUND((user_count::decimal / ai_count) * 100)));
        fraud_score_calc := fraud_score_calc + 0.2;
      END IF;

      -- Check unrealistic counts per type
      max_reasonable := CASE pollution_key
        WHEN 'plastic' THEN 500
        WHEN 'oil' THEN 50
        WHEN 'debris' THEN 1000
        WHEN 'sewage' THEN 20
        WHEN 'fishing_gear' THEN 100
        WHEN 'container' THEN 200
        ELSE 500
      END;

      IF user_count > max_reasonable THEN
        warnings_list := array_append(warnings_list,
          format('%s: %s items exceeds reasonable maximum (%s)',
            pollution_key, user_count, max_reasonable));
        fraud_score_calc := fraud_score_calc + 0.3;
      END IF;
    END LOOP;
  END IF;

  -- Check 3: Severity mismatch (simplified heuristic)
  IF user_total >= 20 THEN
    expected_severity := 5;
  ELSIF user_total >= 10 THEN
    expected_severity := 4;
  ELSIF user_total >= 5 THEN
    expected_severity := 3;
  ELSIF user_total >= 2 THEN
    expected_severity := 2;
  ELSE
    expected_severity := 1;
  END IF;

  IF ABS(severity - expected_severity) >= 2 THEN
    warnings_list := array_append(warnings_list,
      format('Severity (%s) does not match item count (expected ~%s)',
        severity, expected_severity));
    fraud_score_calc := fraud_score_calc + 0.2;
  END IF;

  -- Check 4: Added types not detected by AI
  IF user_counts IS NOT NULL AND ai_baseline IS NOT NULL THEN
    FOR pollution_key IN
      SELECT key FROM jsonb_each_text(user_counts)
      WHERE (user_counts->>key)::int > 0
    LOOP
      IF NOT ai_baseline ? pollution_key OR (ai_baseline->>pollution_key)::int = 0 THEN
        warnings_list := array_append(warnings_list,
          format('%s added but not detected by AI', pollution_key));
        fraud_score_calc := fraud_score_calc + 0.1;
      END IF;
    END LOOP;
  END IF;

  -- Clamp fraud score
  fraud_score_calc := LEAST(GREATEST(fraud_score_calc, 0), 1);

  RETURN QUERY SELECT
    fraud_score_calc >= 0.5,
    fraud_score_calc,
    warnings_list;
END;
$$;

-- ============================================================================
-- 5. VALIDATION TRIGGER - Runs AFTER INSERT on reports
-- Recalculates XP/weight as authoritative, validates fraud
-- ============================================================================

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

  -- Recalculate weight (authoritative)
  server_weight := calculate_total_weight(NEW.pollution_counts);

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

-- Create trigger (BEFORE INSERT to modify values)
DROP TRIGGER IF EXISTS validate_report_trigger ON reports;
CREATE TRIGGER validate_report_trigger
  BEFORE INSERT ON reports
  FOR EACH ROW
  EXECUTE FUNCTION validate_report_on_insert();

-- ============================================================================
-- 6. ADD STATUS FILTERING TO BOUNDS RPC
-- ============================================================================

-- Drop and recreate with status parameter
DROP FUNCTION IF EXISTS public.get_reports_in_bounds_with_images(
  double precision, double precision, double precision, double precision, int, timestamptz
);

CREATE OR REPLACE FUNCTION public.get_reports_in_bounds_with_images(
  min_lng double precision,
  min_lat double precision,
  max_lng double precision,
  max_lat double precision,
  max_results int DEFAULT 500,
  p_updated_since timestamptz DEFAULT NULL,
  p_statuses report_status[] DEFAULT NULL
)
RETURNS TABLE (
  id uuid,
  user_id uuid,
  org_id uuid,
  location text,
  address text,
  pollution_type pollution_type,
  severity int,
  status report_status,
  notes text,
  is_anonymous boolean,
  reported_at timestamptz,
  city text,
  country text,
  pollution_counts jsonb,
  total_weight_kg decimal,
  xp_earned int,
  is_flagged boolean,
  fraud_score decimal,
  fraud_warnings text[],
  image_urls text[],
  updated_at timestamptz
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    r.id,
    r.user_id,
    r.org_id,
    ST_AsText(r.location) as location,
    r.address,
    r.pollution_type,
    r.severity,
    r.status,
    r.notes,
    r.is_anonymous,
    r.reported_at,
    r.city,
    r.country,
    r.pollution_counts,
    r.total_weight_kg,
    r.xp_earned,
    r.is_flagged,
    r.fraud_score,
    r.fraud_warnings,
    COALESCE(
      (SELECT array_agg(ri.storage_path ORDER BY ri.is_primary DESC)
       FROM report_images ri
       WHERE ri.report_id = r.id),
      ARRAY[]::text[]
    ) as image_urls,
    COALESCE(r.updated_at, r.reported_at) as updated_at
  FROM reports r
  WHERE r.location IS NOT NULL
    AND ST_Intersects(
      r.location,
      ST_MakeEnvelope(min_lng, min_lat, max_lng, max_lat, 4326)::geography
    )
    AND (p_updated_since IS NULL OR COALESCE(r.updated_at, r.reported_at) > p_updated_since)
    AND (p_statuses IS NULL OR r.status = ANY(p_statuses))
  ORDER BY r.reported_at DESC
  LIMIT max_results;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION public.get_reports_in_bounds_with_images(
  double precision, double precision, double precision, double precision, int, timestamptz, report_status[]
) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_reports_in_bounds_with_images(
  double precision, double precision, double precision, double precision, int, timestamptz, report_status[]
) TO anon;

-- ============================================================================
-- 7. GEOCODING CACHE TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS location_cache (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  lat decimal NOT NULL,
  lng decimal NOT NULL,
  precision int NOT NULL DEFAULT 4, -- decimal places for lat/lng rounding
  place_name text,
  city text,
  country text,
  full_response jsonb,
  created_at timestamptz DEFAULT now(),
  expires_at timestamptz DEFAULT (now() + interval '30 days'),

  -- Unique constraint on rounded coordinates
  CONSTRAINT unique_location UNIQUE (lat, lng, precision)
);

-- Index for fast lookups
CREATE INDEX IF NOT EXISTS location_cache_coords_idx
  ON location_cache (lat, lng, precision);

-- Index for cleanup of expired entries
CREATE INDEX IF NOT EXISTS location_cache_expires_idx
  ON location_cache (expires_at);

-- RLS policies
ALTER TABLE location_cache ENABLE ROW LEVEL SECURITY;

-- Anyone can read cached locations
CREATE POLICY "location_cache_read" ON location_cache
  FOR SELECT USING (true);

-- Only authenticated users can insert (via Edge Function)
CREATE POLICY "location_cache_insert" ON location_cache
  FOR INSERT WITH CHECK (true);

-- Function to clean up expired cache entries (run via cron)
CREATE OR REPLACE FUNCTION cleanup_expired_location_cache()
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  deleted_count int;
BEGIN
  DELETE FROM location_cache WHERE expires_at < now();
  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  RETURN deleted_count;
END;
$$;

-- ============================================================================
-- 8. BATCH PROFILE DATA FUNCTION
-- Combines user rank + badges in single call
-- ============================================================================

CREATE OR REPLACE FUNCTION get_user_profile_data(p_user_id uuid)
RETURNS TABLE (
  -- Rank info
  rank int,
  total_xp bigint,
  reports_count bigint,
  -- Badge summary
  badges_earned int,
  badges_total int,
  recent_badge_slug text,
  recent_badge_earned_at timestamptz
)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  WITH user_stats AS (
    SELECT
      p.total_xp,
      p.reports_count,
      (SELECT COUNT(*) + 1 FROM profiles p2 WHERE p2.total_xp > p.total_xp) as rank
    FROM profiles p
    WHERE p.id = p_user_id
  ),
  badge_stats AS (
    SELECT
      COUNT(ub.badge_id)::int as badges_earned,
      (SELECT COUNT(*)::int FROM badges) as badges_total,
      (SELECT b.slug FROM user_badges ub2
       JOIN badges b ON b.id = ub2.badge_id
       WHERE ub2.user_id = p_user_id
       ORDER BY ub2.earned_at DESC LIMIT 1) as recent_badge_slug,
      (SELECT ub2.earned_at FROM user_badges ub2
       WHERE ub2.user_id = p_user_id
       ORDER BY ub2.earned_at DESC LIMIT 1) as recent_badge_earned_at
    FROM user_badges ub
    WHERE ub.user_id = p_user_id
  )
  SELECT
    us.rank::int,
    us.total_xp,
    us.reports_count,
    bs.badges_earned,
    bs.badges_total,
    bs.recent_badge_slug,
    bs.recent_badge_earned_at
  FROM user_stats us, badge_stats bs;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION get_user_profile_data(uuid) TO authenticated;
