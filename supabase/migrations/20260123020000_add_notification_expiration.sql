-- Add expires_at column for notification auto-cleanup
ALTER TABLE notifications 
ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ;

-- Add index for efficient expiration queries
CREATE INDEX IF NOT EXISTS idx_notifications_expires_at 
  ON notifications (expires_at) 
  WHERE expires_at IS NOT NULL;

-- Update the event notification trigger to set expiration
CREATE OR REPLACE FUNCTION notify_event_created()
RETURNS TRIGGER AS $$
BEGIN
  -- Only notify if event has a location
  IF NEW.location IS NOT NULL THEN
    -- Insert notifications for users who have submitted reports within 100km of event
    -- Notification expires when the event ends (or start_time + 1 day if no end_time)
    INSERT INTO notifications (user_id, type, title, body, data, expires_at)
    SELECT DISTINCT 
      r.user_id,
      'event_created'::notification_type,
      'New cleanup event nearby!',
      COALESCE(
        (SELECT display_name FROM profiles WHERE id = NEW.organizer_id),
        'Someone'
      ) || ' created: ' || NEW.title,
      jsonb_build_object(
        'event_id', NEW.id,
        'event_title', NEW.title,
        'start_time', NEW.start_time,
        'address', NEW.address
      ),
      -- Expire after event ends, or 1 day after start if no end time
      COALESCE(NEW.end_time, NEW.start_time + INTERVAL '1 day')
    FROM reports r
    WHERE r.user_id IS NOT NULL
      AND r.user_id != NEW.organizer_id
      AND r.location IS NOT NULL
      AND ST_DWithin(
        r.location::geography,
        NEW.location::geography,
        100000  -- 100km in meters
      )
    LIMIT 500;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create a function to clean up expired notifications (can be called by cron)
CREATE OR REPLACE FUNCTION cleanup_expired_notifications()
RETURNS INTEGER AS $$
DECLARE
  deleted_count INTEGER;
BEGIN
  DELETE FROM notifications 
  WHERE expires_at IS NOT NULL 
    AND expires_at < NOW();
  
  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  RETURN deleted_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Comment for documentation
COMMENT ON COLUMN notifications.expires_at IS 
  'When this notification should be auto-deleted. NULL means no expiration.';

COMMENT ON FUNCTION cleanup_expired_notifications() IS 
  'Deletes expired notifications. Call periodically via cron or pg_cron.';
