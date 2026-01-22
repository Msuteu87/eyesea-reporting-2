# Codemagic CI/CD Setup Guide

This guide walks you through setting up automated builds and deployments for iOS and Android using Codemagic.

## Overview

Codemagic provides:
- ✅ Automated builds for iOS and Android
- ✅ Code signing management (certificates, provisioning profiles, keystores)
- ✅ Automatic uploads to TestFlight and Google Play
- ✅ 500 free build minutes/month (enough for ~15-20 releases)
- ✅ Manual triggers (you control when builds run)

---

## Step 1: Create Codemagic Account

1. Go to [codemagic.io](https://codemagic.io)
2. Click **"Sign up"** and choose **"Sign up with GitHub"**
3. Authorize Codemagic to access your GitHub account
4. After signing in, click **"Add application"**
5. Select your repository: `Msuteu87/eyesea-reporting-2`
6. Choose **"Flutter App"** as project type
7. Select **"codemagic.yaml"** as configuration method (this gives you full control)

---

## Step 2: Gather iOS Signing Credentials

### 2a. Export Distribution Certificate

1. Open **Keychain Access** on your Mac
2. In the left sidebar, select **"login"** keychain
3. In the search box, type **"Apple Distribution"**
4. Find your distribution certificate (should show your name/team)
5. Right-click the certificate → **"Export [Certificate Name]"**
6. Choose **".p12 Personal Information Exchange"** format
7. Save it with a strong password (you'll need this password in Codemagic)
8. **Important:** Keep this password safe - you'll need it to upload to Codemagic

### 2b. Download Provisioning Profile

1. Go to [Apple Developer Portal → Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/profiles/list)
2. Find your **App Store** provisioning profile for `com.mariussuteu.eyesea.eyeseareporting`
3. Click **"Download"** to save the `.mobileprovision` file

### 2c. Create App Store Connect API Key

This allows Codemagic to automatically upload builds to TestFlight.

1. Go to [App Store Connect → Users and Access → Keys](https://appstoreconnect.apple.com/access/api)
2. Click the **"+"** button to generate a new key
3. Enter a name (e.g., "Codemagic CI/CD")
4. Select **"App Manager"** role
5. Click **"Generate"**
6. **Download the .p8 file immediately** (you can only download it once!)
7. Note the **Key ID** (shown in the list)
8. Note the **Issuer ID** (shown at the top of the Keys page)

**Save these three things:**
- `.p8` file
- Key ID
- Issuer ID

---

## Step 3: Gather Android Signing Credentials

### 3a. Locate Your Upload Keystore

You should already have a keystore file from your previous Android release. If not:

1. Check if `android/app/eyesea-release-key.jks` exists
2. Or check `android/key.properties` for the keystore path
3. If you don't have one, you'll need to create it (see Android documentation)

**You'll need:**
- Keystore file (`.jks` or `.keystore`)
- Keystore password
- Key alias (usually `upload` or `key`)
- Key password (may be same as keystore password)

### 3b. Create Google Play Service Account

This allows Codemagic to automatically upload builds to Google Play.

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Create a new project (or select existing)
3. Go to **"IAM & Admin" → "Service Accounts"**
4. Click **"Create Service Account"**
5. Enter name: `codemagic-uploader`
6. Click **"Create and Continue"**
7. Grant role: **"Service Account User"**
8. Click **"Continue"** then **"Done"**
9. Click on the newly created service account
10. Go to **"Keys"** tab → **"Add Key" → "Create new key"**
11. Choose **JSON** format and download the file

**Next, grant Play Console access:**

1. Go to [Google Play Console → Setup → API Access](https://play.google.com/console)
2. Under **"Service accounts"**, click **"Link service account"**
3. Select the service account you just created
4. Grant **"Release apps"** permission
5. Click **"Grant access"**

---

## Step 4: Upload Credentials to Codemagic

In the Codemagic dashboard, go to your app → **Settings**:

### iOS Code Signing

1. Go to **"Code signing identities"** → **iOS**
2. Click **"Add code signing identity"**
3. Upload your `.p12` certificate file
4. Enter the certificate password
5. Click **"Save"**

6. Go to **"Provisioning profiles"**
7. Click **"Add provisioning profile"**
8. Upload your `.mobileprovision` file
9. Click **"Save"**

10. Go to **"App Store Connect API key"**
11. Click **"Add App Store Connect API key"**
12. Enter:
    - **Key ID** (from Step 2c)
    - **Issuer ID** (from Step 2c)
    - Upload the `.p8` file
13. Click **"Save"**

### Android Code Signing

1. Go to **"Code signing identities"** → **Android**
2. Click **"Add code signing identity"**
3. Enter a name: `eyesea_keystore`
4. Upload your keystore file (`.jks` or `.keystore`)
5. Enter:
    - **Keystore password**
    - **Key alias**
    - **Key password**
6. Click **"Save"**

### Google Play Service Account

1. Go to **"Google Play API"**
2. Click **"Add Google Play API credentials"**
3. Upload the service account JSON file (from Step 3b)
4. Click **"Save"**

---

## Step 5: Add Environment Variables

In Codemagic → Your App → **Environment Variables**:

1. Click **"Add variable"**
2. Add each of these (mark as **"Secure"** for each):
   - `SUPABASE_URL` = Your Supabase project URL
   - `SUPABASE_ANON_KEY` = Your Supabase anon key
   - `MAPBOX_ACCESS_TOKEN` = Your Mapbox access token

3. After adding each variable, Codemagic will show an encrypted value like `Encrypted(abc123...)`
4. Copy these encrypted values

### Update codemagic.yaml

1. Open `codemagic.yaml` in your repository
2. Replace all `Encrypted(...)` placeholders with the actual encrypted values from Codemagic
3. For the Android keystore reference, make sure the name matches what you entered (e.g., `eyesea_keystore`)
4. For Google Play credentials, replace `Encrypted(...)` with the encrypted service account JSON value

**Example:**
```yaml
vars:
  SUPABASE_URL: Encrypted(abc123def456...)
  SUPABASE_ANON_KEY: Encrypted(ghi789jkl012...)
  MAPBOX_ACCESS_TOKEN: Encrypted(mno345pqr678...)
```

---

## Step 6: Commit and Push codemagic.yaml

1. Commit the `codemagic.yaml` file to your repository:
   ```bash
   git add codemagic.yaml
   git commit -m "Add Codemagic CI/CD configuration"
   git push
   ```

2. Codemagic will automatically detect the configuration file

---

## Step 7: Trigger Your First Build

1. Go to Codemagic dashboard
2. Select your app
3. Click **"Start new build"**
4. Choose:
   - **Workflow:** `ios-release`, `android-release`, or `all-platforms`
   - **Branch:** `main` (or your release branch)
5. Click **"Start build"**

The build will:
- ✅ Install dependencies
- ✅ Build the app
- ✅ Sign with your certificates
- ✅ Upload to TestFlight (iOS) or Play Console (Android)
- ✅ Show you the build logs

---

## Workflow Options

You have three workflows configured:

| Workflow | What It Does |
|----------|--------------|
| `ios-release` | Builds iOS only, uploads to TestFlight |
| `android-release` | Builds Android only, uploads to Play Console (internal track) |
| `all-platforms` | Builds both iOS and Android, uploads to both stores |

---

## Troubleshooting

### Build fails with "Code signing error"
- Verify certificates are uploaded correctly
- Check that bundle ID matches: `com.mariussuteu.eyesea.eyeseareporting`
- Ensure provisioning profile matches the bundle ID

### Environment variables not found
- Make sure you added them in Codemagic UI
- Verify the encrypted values are correctly pasted in `codemagic.yaml`
- Check variable names match exactly (case-sensitive)

### Android build fails
- Verify keystore is uploaded
- Check keystore password and alias are correct
- Ensure keystore name in `codemagic.yaml` matches what you entered in Codemagic

### Upload to TestFlight fails
- Verify App Store Connect API key is configured
- Check that the API key has "App Manager" role
- Ensure the app exists in App Store Connect

---

## Cost

- **Free tier:** 500 build minutes/month
- **iOS build:** ~15-20 minutes
- **Android build:** ~10-15 minutes
- **Both platforms:** ~25-30 minutes

With manual triggers, 500 minutes gives you approximately **15-20 full releases per month**, which should be plenty for beta testing.

---

## Next Steps

After your first successful build:

1. ✅ Verify the build appears in TestFlight/Play Console
2. ✅ Test the app on a device
3. ✅ Promote to beta testers
4. ✅ Set up release notes workflow (optional)

For questions or issues, check [Codemagic documentation](https://docs.codemagic.io/) or their support.
