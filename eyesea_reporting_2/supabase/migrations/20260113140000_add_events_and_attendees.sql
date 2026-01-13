-- ========================================
-- Events and Event Attendees Schema
-- ========================================

-- Enable PostGIS if not already enabled
CREATE EXTENSION IF NOT EXISTS postgis;

-- ========================================
-- EVENTS TABLE
-- ========================================
CREATE TABLE IF NOT EXISTS public.events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organizer_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title text NOT NULL,
  description text NOT NULL,
  address text,
  location geography(POINT, 4326),
  start_time timestamptz NOT NULL,
  end_time timestamptz NOT NULL,
  max_attendees int,
  status text NOT NULL DEFAULT 'planned' CHECK (status IN ('planned', 'ongoing', 'completed', 'cancelled')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Index for faster queries
CREATE INDEX IF NOT EXISTS idx_events_start_time ON public.events(start_time DESC);
CREATE INDEX IF NOT EXISTS idx_events_organizer ON public.events(organizer_id);
CREATE INDEX IF NOT EXISTS idx_events_status ON public.events(status);

-- ========================================
-- EVENT ATTENDEES TABLE
-- ========================================
CREATE TABLE IF NOT EXISTS public.event_attendees (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id uuid NOT NULL REFERENCES public.events(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  joined_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(event_id, user_id)
);

-- Index for faster lookups
CREATE INDEX IF NOT EXISTS idx_event_attendees_event ON public.event_attendees(event_id);
CREATE INDEX IF NOT EXISTS idx_event_attendees_user ON public.event_attendees(user_id);

-- ========================================
-- ROW LEVEL SECURITY (RLS)
-- ========================================

-- Enable RLS
ALTER TABLE public.events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.event_attendees ENABLE ROW LEVEL SECURITY;

-- Events Policies
-- Everyone can view events
CREATE POLICY "Events are viewable by everyone"
ON public.events FOR SELECT
TO authenticated
USING (true);

-- Authenticated users can create events
CREATE POLICY "Users can create events"
ON public.events FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = organizer_id);

-- Only organizers can update their events
CREATE POLICY "Organizers can update their events"
ON public.events FOR UPDATE
TO authenticated
USING (auth.uid() = organizer_id)
WITH CHECK (auth.uid() = organizer_id);

-- Only organizers can delete their events
CREATE POLICY "Organizers can delete their events"
ON public.events FOR DELETE
TO authenticated
USING (auth.uid() = organizer_id);

-- Event Attendees Policies
-- Everyone can view attendees
CREATE POLICY "Event attendees are viewable by everyone"
ON public.event_attendees FOR SELECT
TO authenticated
USING (true);

-- Users can join events (insert their own attendance)
CREATE POLICY "Users can join events"
ON public.event_attendees FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

-- Users can leave events (delete their own attendance)
CREATE POLICY "Users can leave events"
ON public.event_attendees FOR DELETE
TO authenticated
USING (auth.uid() = user_id);

-- ========================================
-- RPC FUNCTIONS
-- ========================================

-- Get events with attendee count and user attendance status
CREATE OR REPLACE FUNCTION get_events_with_details(
  p_user_id uuid DEFAULT NULL,
  p_filter text DEFAULT 'upcoming',
  p_limit int DEFAULT 50
)
RETURNS TABLE (
  id uuid,
  organizer_id uuid,
  organizer_name text,
  organizer_avatar text,
  title text,
  description text,
  address text,
  location_lat double precision,
  location_lng double precision,
  start_time timestamptz,
  end_time timestamptz,
  max_attendees int,
  status text,
  created_at timestamptz,
  attendee_count bigint,
  is_attending boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT
    e.id,
    e.organizer_id,
    COALESCE(p.display_name, 'Unknown') as organizer_name,
    p.avatar_url as organizer_avatar,
    e.title,
    e.description,
    e.address,
    ST_Y(e.location::geometry) as location_lat,
    ST_X(e.location::geometry) as location_lng,
    e.start_time,
    e.end_time,
    e.max_attendees,
    e.status,
    e.created_at,
    COUNT(DISTINCT ea.id) as attendee_count,
    CASE
      WHEN p_user_id IS NOT NULL THEN
        EXISTS(
          SELECT 1 FROM public.event_attendees
          WHERE event_id = e.id AND user_id = p_user_id
        )
      ELSE false
    END as is_attending
  FROM public.events e
  LEFT JOIN public.profiles p ON p.id = e.organizer_id
  LEFT JOIN public.event_attendees ea ON ea.event_id = e.id
  WHERE
    CASE
      WHEN p_filter = 'upcoming' THEN e.start_time > now() AND e.status = 'planned'
      WHEN p_filter = 'past' THEN e.end_time < now() OR e.status IN ('completed', 'cancelled')
      WHEN p_filter = 'my_organized' THEN e.organizer_id = p_user_id
      WHEN p_filter = 'my_attending' THEN EXISTS(
        SELECT 1 FROM public.event_attendees
        WHERE event_id = e.id AND user_id = p_user_id
      )
      ELSE true
    END
  GROUP BY e.id, p.display_name, p.avatar_url
  ORDER BY e.start_time ASC
  LIMIT p_limit;
END;
$$;

-- Get attendees for a specific event
CREATE OR REPLACE FUNCTION get_event_attendees(p_event_id uuid)
RETURNS TABLE (
  user_id uuid,
  display_name text,
  avatar_url text,
  joined_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT
    p.id as user_id,
    COALESCE(p.display_name, 'Anonymous') as display_name,
    p.avatar_url,
    ea.joined_at
  FROM public.event_attendees ea
  JOIN public.profiles p ON p.id = ea.user_id
  WHERE ea.event_id = p_event_id
  ORDER BY ea.joined_at ASC;
END;
$$;

-- Join event function (with max attendee check)
CREATE OR REPLACE FUNCTION join_event(p_event_id uuid, p_user_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_max_attendees int;
  v_current_count int;
  v_result json;
BEGIN
  -- Get event max attendees
  SELECT max_attendees INTO v_max_attendees
  FROM public.events
  WHERE id = p_event_id;

  -- Count current attendees
  SELECT COUNT(*) INTO v_current_count
  FROM public.event_attendees
  WHERE event_id = p_event_id;

  -- Check if event is full (if max_attendees is set)
  IF v_max_attendees IS NOT NULL AND v_current_count >= v_max_attendees THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Event is full'
    );
  END IF;

  -- Check if already attending
  IF EXISTS(
    SELECT 1 FROM public.event_attendees
    WHERE event_id = p_event_id AND user_id = p_user_id
  ) THEN
    RETURN json_build_object(
      'success', false,
      'message', 'Already attending'
    );
  END IF;

  -- Insert attendance
  INSERT INTO public.event_attendees (event_id, user_id)
  VALUES (p_event_id, p_user_id);

  RETURN json_build_object(
    'success', true,
    'message', 'Successfully joined event'
  );
END;
$$;

-- Leave event function
CREATE OR REPLACE FUNCTION leave_event(p_event_id uuid, p_user_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Delete attendance record
  DELETE FROM public.event_attendees
  WHERE event_id = p_event_id AND user_id = p_user_id;

  IF FOUND THEN
    RETURN json_build_object(
      'success', true,
      'message', 'Successfully left event'
    );
  ELSE
    RETURN json_build_object(
      'success', false,
      'message', 'Not attending this event'
    );
  END IF;
END;
$$;

-- ========================================
-- UPDATED_AT TRIGGER
-- ========================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_events_updated_at
BEFORE UPDATE ON public.events
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();
