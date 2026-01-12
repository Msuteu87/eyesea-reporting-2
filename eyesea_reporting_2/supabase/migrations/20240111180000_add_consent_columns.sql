-- Add consent tracking columns to profiles table
-- GDPR/NZ Privacy Act compliance

-- GDPR Data Processing Consent (timestamp of consent)
ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS gdpr_consent_at TIMESTAMPTZ;

-- Marketing Communications Opt-In (optional)
ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS marketing_opt_in BOOLEAN DEFAULT FALSE;

-- Terms Accepted At (for audit trail)
ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS terms_accepted_at TIMESTAMPTZ;

-- Add index for consent queries
CREATE INDEX IF NOT EXISTS idx_profiles_gdpr_consent ON public.profiles(gdpr_consent_at);
CREATE INDEX IF NOT EXISTS idx_profiles_marketing_opt_in ON public.profiles(marketing_opt_in) WHERE marketing_opt_in = TRUE;

COMMENT ON COLUMN public.profiles.gdpr_consent_at IS 'Timestamp when user consented to data processing (GDPR/NZ Privacy Act)';
COMMENT ON COLUMN public.profiles.marketing_opt_in IS 'Whether user opted in to receive marketing communications';
COMMENT ON COLUMN public.profiles.terms_accepted_at IS 'Timestamp when user accepted Terms of Service and EULA';
