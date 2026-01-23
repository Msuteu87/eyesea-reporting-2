-- Migration: Add device_tokens table for push notifications
-- This stores FCM/APNs tokens for each user's devices

-- Create device_tokens table
CREATE TABLE IF NOT EXISTS device_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  token TEXT NOT NULL,
  platform TEXT NOT NULL CHECK (platform IN ('ios', 'android', 'web')),
  device_id TEXT, -- Optional unique device identifier
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

  -- Each token should be unique globally (a token belongs to one device)
  UNIQUE(token)
);

-- Index for efficient lookup by user_id (most common query)
CREATE INDEX idx_device_tokens_user_id ON device_tokens(user_id);

-- Index for token lookup (for cleanup/updates)
CREATE INDEX idx_device_tokens_token ON device_tokens(token);

-- Enable RLS
ALTER TABLE device_tokens ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only see their own tokens
CREATE POLICY "Users can view own device tokens"
  ON device_tokens FOR SELECT
  USING (auth.uid() = user_id);

-- Policy: Users can insert their own tokens
CREATE POLICY "Users can insert own device tokens"
  ON device_tokens FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Policy: Users can update their own tokens
CREATE POLICY "Users can update own device tokens"
  ON device_tokens FOR UPDATE
  USING (auth.uid() = user_id);

-- Policy: Users can delete their own tokens
CREATE POLICY "Users can delete own device tokens"
  ON device_tokens FOR DELETE
  USING (auth.uid() = user_id);

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_device_token_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-update updated_at
CREATE TRIGGER device_tokens_updated_at
  BEFORE UPDATE ON device_tokens
  FOR EACH ROW
  EXECUTE FUNCTION update_device_token_timestamp();

-- Function to upsert device token (insert or update if exists)
-- This handles the case where a token already exists (device reinstall, etc.)
CREATE OR REPLACE FUNCTION upsert_device_token(
  p_token TEXT,
  p_platform TEXT,
  p_device_id TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id UUID;
  v_token_id UUID;
BEGIN
  -- Get current user
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Upsert the token
  INSERT INTO device_tokens (user_id, token, platform, device_id)
  VALUES (v_user_id, p_token, p_platform, p_device_id)
  ON CONFLICT (token) DO UPDATE
    SET user_id = v_user_id,
        platform = p_platform,
        device_id = COALESCE(p_device_id, device_tokens.device_id),
        updated_at = now()
  RETURNING id INTO v_token_id;

  RETURN v_token_id;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION upsert_device_token(TEXT, TEXT, TEXT) TO authenticated;

-- Function to remove a device token (for logout)
CREATE OR REPLACE FUNCTION remove_device_token(p_token TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  DELETE FROM device_tokens
  WHERE token = p_token AND user_id = auth.uid();

  RETURN FOUND;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION remove_device_token(TEXT) TO authenticated;

-- Function to get all tokens for a user (used by Edge Functions)
-- This is SECURITY DEFINER so Edge Functions can access tokens for any user
CREATE OR REPLACE FUNCTION get_user_push_tokens(p_user_id UUID)
RETURNS TABLE(token TEXT, platform TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT dt.token, dt.platform
  FROM device_tokens dt
  WHERE dt.user_id = p_user_id;
END;
$$;

-- Grant to service_role only (Edge Functions use service_role key)
GRANT EXECUTE ON FUNCTION get_user_push_tokens(UUID) TO service_role;

-- Add comment for documentation
COMMENT ON TABLE device_tokens IS 'Stores FCM/APNs push notification tokens for each user device';
COMMENT ON FUNCTION upsert_device_token IS 'Upserts a device token for push notifications - call this on app launch';
COMMENT ON FUNCTION remove_device_token IS 'Removes a device token - call this on logout';
COMMENT ON FUNCTION get_user_push_tokens IS 'Gets all push tokens for a user - used by Edge Functions to send notifications';
