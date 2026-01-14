-- Fix missing table grants after security hardening
-- The security hardening migration revoked ALL but didn't re-grant for vessels table

-- Vessels: public read, authenticated can view
GRANT SELECT ON public.vessels TO anon, authenticated;

-- If users need to create/update vessels (check if needed)
-- GRANT INSERT, UPDATE ON public.vessels TO authenticated;
