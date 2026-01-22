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

## Environment Variables

- [ ] Add `SUPABASE_URL` to Codemagic (mark as Secure)
- [ ] Add `SUPABASE_ANON_KEY` to Codemagic (mark as Secure)
- [ ] Add `MAPBOX_ACCESS_TOKEN` to Codemagic (mark as Secure)
- [ ] Copy encrypted values from Codemagic
- [ ] Update `codemagic.yaml` with encrypted values

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
