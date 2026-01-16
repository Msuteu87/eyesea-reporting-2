-- External Reporting API: API Keys and Report Attribution
-- This migration adds support for external applications to submit reports via API

-- =============================================================================
-- 0. Enable Required Extensions
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- =============================================================================
-- 1. API Keys Table for Authentication
-- =============================================================================

CREATE TABLE IF NOT EXISTS public.api_keys (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  key_hash TEXT NOT NULL UNIQUE,      -- SHA-256 hash of the actual key
  name TEXT NOT NULL,                  -- Partner/source name (e.g., "Ocean Cleanup App")
  description TEXT,                    -- Optional description
  is_active BOOLEAN DEFAULT true,
  rate_limit_per_day INT DEFAULT 1000, -- Configurable per partner
  requests_today INT DEFAULT 0,
  requests_reset_at DATE DEFAULT CURRENT_DATE,
  total_requests INT DEFAULT 0,        -- Lifetime request count
  created_at TIMESTAMPTZ DEFAULT now(),
  expires_at TIMESTAMPTZ,              -- Optional expiration date
  created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL
);

-- Index for fast key validation
CREATE INDEX IF NOT EXISTS idx_api_keys_hash ON api_keys(key_hash) WHERE is_active = true;

-- =============================================================================
-- 2. Add API Attribution Columns to Reports
-- =============================================================================

ALTER TABLE reports ADD COLUMN IF NOT EXISTS api_source TEXT;      -- Name of external source
ALTER TABLE reports ADD COLUMN IF NOT EXISTS api_reference TEXT;   -- External system's ID

-- Index for filtering API submissions
CREATE INDEX IF NOT EXISTS idx_reports_api_source ON reports(api_source) WHERE api_source IS NOT NULL;

-- =============================================================================
-- 3. Row Level Security for API Keys
-- =============================================================================

ALTER TABLE api_keys ENABLE ROW LEVEL SECURITY;

-- Only admins can view API keys
CREATE POLICY "Admins can view API keys" ON api_keys
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- Only admins can insert new API keys
CREATE POLICY "Admins can create API keys" ON api_keys
  FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- Only admins can update API keys (e.g., deactivate)
CREATE POLICY "Admins can update API keys" ON api_keys
  FOR UPDATE USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- Only admins can delete API keys
CREATE POLICY "Admins can delete API keys" ON api_keys
  FOR DELETE USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- =============================================================================
-- 4. Function to Generate API Key (Admin only)
-- Returns the unhashed key ONCE - store it securely!
-- =============================================================================

CREATE OR REPLACE FUNCTION generate_api_key(
  p_name TEXT,
  p_description TEXT DEFAULT NULL,
  p_rate_limit INT DEFAULT 1000,
  p_expires_at TIMESTAMPTZ DEFAULT NULL
)
RETURNS TABLE(api_key TEXT, key_id UUID)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_raw_key TEXT;
  v_key_hash TEXT;
  v_key_id UUID;
BEGIN
  -- Check caller is admin OR service role (for SQL Editor access)
  -- Service role has no auth.uid(), so we check if current_user is the service role
  IF auth.uid() IS NOT NULL AND NOT EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin') THEN
    RAISE EXCEPTION 'Only admins can generate API keys';
  END IF;

  -- Generate a secure random key with eyesea_ prefix
  v_raw_key := 'eyesea_' || encode(gen_random_bytes(24), 'hex');

  -- Hash the key for storage (SHA-256)
  v_key_hash := encode(sha256(v_raw_key::bytea), 'hex');

  -- Insert the new key
  INSERT INTO api_keys (key_hash, name, description, rate_limit_per_day, expires_at, created_by)
  VALUES (v_key_hash, p_name, p_description, p_rate_limit, p_expires_at, auth.uid())
  RETURNING id INTO v_key_id;

  -- Return the unhashed key (shown only once!)
  RETURN QUERY SELECT v_raw_key, v_key_id;
END;
$$;

-- =============================================================================
-- 5. Function to Validate API Key (Called by Edge Function)
-- Validates key, checks rate limit, increments counter
-- =============================================================================

CREATE OR REPLACE FUNCTION validate_api_key(p_key TEXT)
RETURNS TABLE(is_valid BOOLEAN, key_id UUID, key_name TEXT, rate_limited BOOLEAN)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_key_hash TEXT;
  v_record api_keys%ROWTYPE;
BEGIN
  -- Hash the provided key
  v_key_hash := encode(sha256(p_key::bytea), 'hex');

  -- Look up the key
  SELECT * INTO v_record FROM api_keys
  WHERE key_hash = v_key_hash
    AND is_active = true
    AND (expires_at IS NULL OR expires_at > now());

  -- Key not found or inactive/expired
  IF NOT FOUND THEN
    RETURN QUERY SELECT false, NULL::UUID, NULL::TEXT, false;
    RETURN;
  END IF;

  -- Reset daily counter if new day (UTC)
  IF v_record.requests_reset_at < CURRENT_DATE THEN
    UPDATE api_keys SET
      requests_today = 1,
      requests_reset_at = CURRENT_DATE,
      total_requests = total_requests + 1
    WHERE id = v_record.id;

    RETURN QUERY SELECT true, v_record.id, v_record.name, false;
    RETURN;
  END IF;

  -- Check if rate limited
  IF v_record.requests_today >= v_record.rate_limit_per_day THEN
    RETURN QUERY SELECT true, v_record.id, v_record.name, true;
    RETURN;
  END IF;

  -- Increment request counter
  UPDATE api_keys SET
    requests_today = requests_today + 1,
    total_requests = total_requests + 1
  WHERE id = v_record.id;

  RETURN QUERY SELECT true, v_record.id, v_record.name, false;
END;
$$;

-- =============================================================================
-- 6. Function to Revoke API Key (Admin only)
-- =============================================================================

CREATE OR REPLACE FUNCTION revoke_api_key(p_key_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Check caller is admin
  IF NOT EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin') THEN
    RAISE EXCEPTION 'Only admins can revoke API keys';
  END IF;

  UPDATE api_keys SET is_active = false WHERE id = p_key_id;

  RETURN FOUND;
END;
$$;

-- =============================================================================
-- 7. Function to Get API Key Stats (Admin only)
-- =============================================================================

CREATE OR REPLACE FUNCTION get_api_key_stats()
RETURNS TABLE(
  key_id UUID,
  name TEXT,
  is_active BOOLEAN,
  rate_limit INT,
  requests_today INT,
  total_requests INT,
  created_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Check caller is admin
  IF NOT EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin') THEN
    RAISE EXCEPTION 'Only admins can view API key stats';
  END IF;

  RETURN QUERY
  SELECT
    ak.id,
    ak.name,
    ak.is_active,
    ak.rate_limit_per_day,
    ak.requests_today,
    ak.total_requests,
    ak.created_at,
    ak.expires_at
  FROM api_keys ak
  ORDER BY ak.created_at DESC;
END;
$$;

-- =============================================================================
-- 8. Storage Policy for API Uploads
-- Allow uploads to api/ folder in report-images bucket
-- =============================================================================

-- Note: This policy allows the service role (used by Edge Functions) to upload
-- to the api/ subfolder. The Edge Function uses SUPABASE_SERVICE_ROLE_KEY.

DO $$
BEGIN
  -- Check if policy already exists to avoid error on re-run
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'storage'
    AND tablename = 'objects'
    AND policyname = 'Allow API uploads to report-images'
  ) THEN
    CREATE POLICY "Allow API uploads to report-images" ON storage.objects
      FOR INSERT WITH CHECK (
        bucket_id = 'report-images' AND
        (storage.foldername(name))[1] = 'api'
      );
  END IF;
END $$;

-- =============================================================================
-- 9. Update RLS for Reports to Allow API Inserts
-- Edge Function uses service role key, but we need to ensure reports
-- with null user_id are allowed
-- =============================================================================

-- The existing RLS policy requires user_id = auth.uid() for inserts
-- API submissions have user_id = null, so we need a policy for service role
-- Service role bypasses RLS by default, so no changes needed

-- However, let's add a policy for viewing API-sourced reports
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
    AND tablename = 'reports'
    AND policyname = 'API reports are viewable by everyone'
  ) THEN
    CREATE POLICY "API reports are viewable by everyone" ON reports
      FOR SELECT USING (api_source IS NOT NULL);
  END IF;
END $$;

-- =============================================================================
-- 10. Grant Permissions
-- =============================================================================

-- Grant execute on functions to authenticated users (admins check inside)
GRANT EXECUTE ON FUNCTION generate_api_key(TEXT, TEXT, INT, TIMESTAMPTZ) TO authenticated;
GRANT EXECUTE ON FUNCTION validate_api_key(TEXT) TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION revoke_api_key(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_api_key_stats() TO authenticated;

-- Grant table access (RLS handles authorization)
GRANT SELECT, INSERT, UPDATE, DELETE ON api_keys TO authenticated;
GRANT SELECT ON api_keys TO service_role;

COMMENT ON TABLE api_keys IS 'API keys for external applications to submit reports';
COMMENT ON FUNCTION generate_api_key IS 'Generate a new API key (admin only). Returns unhashed key once!';
COMMENT ON FUNCTION validate_api_key IS 'Validate API key and track rate limits (used by Edge Function)';
