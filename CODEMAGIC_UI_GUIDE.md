# Codemagic UI Navigation Guide

This guide shows you exactly where to find each setting in the Codemagic UI.

## Current Location: Environment Variables Tab

You're currently on the **Environment variables** tab. This is correct for Step 1.

---

## Step 1: Add Environment Variables (You're Here!)

**Location:** You're already on this page ✅

1. In the "Variable name" field, enter: `SUPABASE_URL`
2. In the "Variable value" field, enter your Supabase URL
3. Make sure **"Secret"** checkbox is checked ✅
4. Click **"Add"**
5. Repeat for:
   - `SUPABASE_ANON_KEY` (your Supabase anon key)
   - `MAPBOX_ACCESS_TOKEN` (your Mapbox token)

**After adding each variable:**
- Codemagic will show an encrypted value like `Encrypted(abc123...)`
- **Copy this encrypted value** - you'll need it for `codemagic.yaml`

---

## Step 2: Add Code Signing Identities

**Location:** Click on the **`codemagic.yaml`** tab (top navigation)

1. In the `codemagic.yaml` tab, look for a section called **"Code signing identities"** or **"iOS certificates"**
2. If you don't see it, try:
   - Click **"Repository settings"** (top right) → Look for code signing section
   - Or go to: **Team settings** (if you have team admin access)

### iOS Code Signing:

1. Find **"Code signing identities"** → **iOS** section
2. Click **"Add code signing identity"** or **"Add certificate"**
3. Upload your `.p12` certificate
4. Enter the certificate password
5. Give it a reference name (e.g., `ios_distribution`)
6. Click **"Save"**

4. Go to **"Provisioning profiles"** section
5. Click **"Add provisioning profile"**
6. Upload your `.mobileprovision` file
7. Click **"Save"**

### Android Code Signing:

1. Find **"Code signing identities"** → **Android** section
2. Click **"Add code signing identity"**
3. Enter name: `eyesea_keystore`
4. Upload your `.jks` or `.keystore` file
5. Enter:
   - Keystore password
   - Key alias
   - Key password
6. Click **"Save"**

---

## Step 3: Add App Store Connect Integration

**Location:** This is in **Team settings**, not app settings

1. Click **"Repository settings"** (top right) or look for **"Team"** in the main navigation
2. Go to **"Team integrations"** or **"Integrations"**
3. Find **"Developer Portal"** or **"App Store Connect"**
4. Click **"Manage keys"** or **"Add key"**
5. Enter:
   - **Name:** `app_store_connect_credentials` (or any name you prefer)
   - **Issuer ID** (from App Store Connect)
   - **Key ID** (from App Store Connect)
   - Upload the `.p8` file
6. Click **"Save"**

**Important:** After creating the integration, note the exact name you used. Update `codemagic.yaml` to match:
```yaml
integrations:
  app_store_connect: <the-name-you-used>
```

---

## Step 4: Add Google Play Service Account

**Location:** Same as App Store Connect - **Team integrations**

1. Go to **Team integrations** → **Google Play**
2. Click **"Add Google Play API credentials"**
3. Upload your service account JSON file
4. Click **"Save"**

---

## Alternative: If You Can't Find These Sections

If you don't see these options, you might need:

1. **Team Admin Access:** Some settings require team admin permissions
2. **Different Navigation:** Try:
   - Click your profile/account icon (top right) → Team settings
   - Look for a "Settings" or "Configuration" menu
   - Check the left sidebar for additional options

---

## Quick Checklist

- [ ] Environment variables added (you're here ✅)
- [ ] Encrypted values copied from environment variables
- [ ] iOS certificate uploaded
- [ ] iOS provisioning profile uploaded
- [ ] Android keystore uploaded
- [ ] App Store Connect integration created (Team settings)
- [ ] Google Play service account added (Team settings)
- [ ] `codemagic.yaml` updated with encrypted values
- [ ] Integration name in `codemagic.yaml` matches Team integration name

---

## Need Help?

If you can't find a specific section:
1. Take a screenshot of what you see
2. Check if you have team admin permissions
3. Look for a "Help" or "Documentation" link in Codemagic
4. Try the Codemagic docs: https://docs.codemagic.io
