# Codemagic Setup Checklist

Use this checklist to track your progress setting up Codemagic CI/CD.

## Account & Repository Setup

- [ ] Sign up at [codemagic.io](https://codemagic.io) with GitHub
- [ ] Add application: `Msuteu87/eyesea-reporting-2`
- [ ] Select "Flutter App" and "codemagic.yaml" configuration

## iOS Credentials

- [ ] Export Apple Distribution certificate (.p12) from Keychain Access
- [ ] Download App Store provisioning profile (.mobileprovision)
- [ ] Create App Store Connect API key (.p8 file)
- [ ] Note Key ID and Issuer ID
- [ ] Upload .p12 certificate to Codemagic (with password)
- [ ] Upload .mobileprovision file to Codemagic
- [ ] Add App Store Connect API key to Codemagic (Key ID, Issuer ID, .p8 file)

## Android Credentials

- [ ] Locate upload keystore file (.jks or .keystore)
- [ ] Note keystore password, key alias, and key password
- [ ] Create Google Cloud service account
- [ ] Download service account JSON key
- [ ] Grant Play Console access to service account
- [ ] Upload keystore to Codemagic (name: `eyesea_keystore`)
- [ ] Upload Google Play service account JSON to Codemagic

## Environment Variables (eyesea_secrets group)

All variables below go in **Codemagic → your app → Environment variables**, variable group **`eyesea_secrets`**. Mark each as **Secure** (encrypted).

| Name | Value | You have? |
|------|--------|-----------|
| `SUPABASE_URL` | `https://YOUR_PROJECT.supabase.co` | ✓ |
| `SUPABASE_ANON_KEY` | Your Supabase anon key | ✓ |
| `MAPBOX_ACCESS_TOKEN` | Your Mapbox token | ✓ |
| `GOOGLE_SERVICES_JSON_BASE64` | Base64 of `android/app/google-services.json` | ✓ |
| `GCLOUD_SERVICE_ACCOUNT_CREDENTIALS` | **Raw JSON** of Google Play service account key (not base64) | ✓ |
| `GOOGLE_SERVICE_INFO_PLIST_BASE64` | Base64 of `ios/Runner/GoogleService-Info.plist` | **→ ADD** |

### Add the missing variable

1. **Name:** `GOOGLE_SERVICE_INFO_PLIST_BASE64`
2. **Variable group:** `eyesea_secrets`
3. **Value:** Base64-encode your `GoogleService-Info.plist`:

   ```bash
   base64 -i eyesea_reporting_2/ios/Runner/GoogleService-Info.plist | pbcopy
   ```

   Then paste the copied string as the value in Codemagic. Or on Linux:

   ```bash
   base64 -w0 eyesea_reporting_2/ios/Runner/GoogleService-Info.plist
   ```

4. **Secure:** Yes (checkbox)

### Do **not** change

- Keep `GCLOUD_SERVICE_ACCOUNT_CREDENTIALS` as-is (name and value). The YAML uses this.
- Keep all other existing variables; no renames or value changes needed.

## Configuration

- [ ] Commit and push `codemagic.yaml` to repository
- [ ] Verify Codemagic detects the configuration file

## First Build

- [ ] Trigger test build: `ios-release` workflow
- [ ] Verify build succeeds
- [ ] Check TestFlight for uploaded build
- [ ] Trigger test build: `android-release` workflow
- [ ] Verify build succeeds
- [ ] Check Play Console for uploaded build

## Verification

- [ ] iOS build appears in TestFlight
- [ ] Android build appears in Play Console (internal track)
- [ ] Both builds are properly signed
- [ ] App version numbers are correct

---

**Estimated time:** 30-45 minutes for initial setup

**Reference:** See `CODEMAGIC_SETUP.md` for detailed instructions
