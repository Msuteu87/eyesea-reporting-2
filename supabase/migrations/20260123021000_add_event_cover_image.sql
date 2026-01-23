-- Add cover_image_url column to events table
ALTER TABLE events 
ADD COLUMN IF NOT EXISTS cover_image_url TEXT;

-- Comment for documentation
COMMENT ON COLUMN events.cover_image_url IS 
  'URL to the event cover image stored in Supabase Storage (event-images bucket)';

-- Create storage bucket for event images
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types) 
VALUES ('event-images', 'event-images', true, 5242880, ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif']) 
ON CONFLICT (id) DO NOTHING;

-- Storage policies for event-images bucket
-- Allow authenticated users to upload event images
CREATE POLICY "Authenticated users can upload event images"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'event-images');

-- Allow public read access to event images
CREATE POLICY "Public can view event images"
ON storage.objects FOR SELECT TO public
USING (bucket_id = 'event-images');
