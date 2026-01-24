-- IMPORTANT: Create the bucket manually via Supabase Dashboard first!
-- Go to: Storage → New Bucket
-- Name: static-assets
-- Public: Yes
-- File size limit: 5MB
-- Allowed MIME types: image/png, image/jpeg, image/svg+xml, image/webp
--
-- For hosted Supabase, bucket creation via SQL requires owner privileges.
-- This migration only creates the storage policies.

-- Storage policies for static-assets bucket
-- Allow public read access to static assets (for email templates, etc.)
CREATE POLICY "Public can view static assets"
ON storage.objects FOR SELECT TO public
USING (bucket_id = 'static-assets');

-- Allow authenticated users to upload static assets (for admin use)
CREATE POLICY "Authenticated users can upload static assets"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'static-assets');

-- Allow authenticated users to update static assets
CREATE POLICY "Authenticated users can update static assets"
ON storage.objects FOR UPDATE TO authenticated
USING (bucket_id = 'static-assets');

-- Allow authenticated users to delete static assets
CREATE POLICY "Authenticated users can delete static assets"
ON storage.objects FOR DELETE TO authenticated
USING (bucket_id = 'static-assets');
