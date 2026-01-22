# Codemagic Quick Start

## What's Been Set Up

✅ **Configuration file created:** `codemagic.yaml`  
✅ **Setup guide created:** `CODEMAGIC_SETUP.md`  
✅ **Checklist created:** `CODEMAGIC_CHECKLIST.md`

## Next Steps (Manual)

The following steps require manual action in various web interfaces:

### 1. Create Codemagic Account (5 minutes)
- Go to [codemagic.io](https://codemagic.io)
- Sign up with GitHub
- Add your repository: `Msuteu87/eyesea-reporting-2`

### 2. Gather Signing Credentials (15-20 minutes)
- **iOS:** Export certificate, download provisioning profile, create API key
- **Android:** Locate keystore, create Google Play service account
- See `CODEMAGIC_SETUP.md` for detailed instructions

### 3. Upload to Codemagic (10 minutes)
- Upload all certificates, profiles, and keys via Codemagic UI
- Add environment variables (SUPABASE_URL, SUPABASE_ANON_KEY, MAPBOX_ACCESS_TOKEN)

### 4. Update codemagic.yaml (5 minutes)
- Copy encrypted environment variable values from Codemagic UI
- Replace `Encrypted(...)` placeholders in `codemagic.yaml`
- Commit and push the updated file

### 5. Test Build (10 minutes)
- Trigger your first build in Codemagic
- Verify it uploads to TestFlight/Play Console

**Total estimated time:** 45-60 minutes

## Workflows Available

After setup, you'll have three workflows:

1. **`ios-release`** - Build and upload iOS to TestFlight
2. **`android-release`** - Build and upload Android to Play Console
3. **`all-platforms`** - Build and upload both platforms

All workflows use **manual triggers** - you control when builds run.

## Need Help?

- **Detailed guide:** See `CODEMAGIC_SETUP.md`
- **Checklist:** Use `CODEMAGIC_CHECKLIST.md` to track progress
- **Codemagic docs:** [docs.codemagic.io](https://docs.codemagic.io)
