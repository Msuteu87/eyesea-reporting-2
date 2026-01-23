-- Add 'event_created' to notification_type enum
ALTER TYPE notification_type ADD VALUE IF NOT EXISTS 'event_created';

-- Create trigger function to notify nearby users when an event is created
CREATE OR REPLACE FUNCTION notify_event_created()
RETURNS TRIGGER AS $$
BEGIN
  -- Only notify if event has a location
  IF NEW.location IS NOT NULL THEN
    -- Insert notifications for users who have submitted reports within 100km of event
    -- Excludes the event organizer, limited to 500 users for performance
    INSERT INTO notifications (user_id, type, title, body, data)
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
      )
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

-- Create trigger on events table
DROP TRIGGER IF EXISTS on_event_created ON events;
CREATE TRIGGER on_event_created
  AFTER INSERT ON events
  FOR EACH ROW
  EXECUTE FUNCTION notify_event_created();

-- Add index for efficient proximity queries on events location
CREATE INDEX IF NOT EXISTS idx_events_location_gist 
  ON events USING GIST (location);

-- Comment for documentation
COMMENT ON FUNCTION notify_event_created() IS 
  'Notifies users within 100km who have submitted reports when a new cleanup event is created. Limited to 500 notifications per event.';
