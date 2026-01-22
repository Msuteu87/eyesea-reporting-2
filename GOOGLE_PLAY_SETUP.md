# Google Play Console Setup Checklist

## Important: Keystore vs Account

**The keystore itself doesn't have account information** - it's just a signing key. What matters is:
- **Which Google Play Console account** you create the app listing under
- **The package name** (`com.mariussuteu.eyesea.eyeseareporting`) - this must match in Play Console

---

## Current Setup Status

✅ **Keystore exists:** `android/app/eyesea-release-key.jks`  
✅ **Package name:** `com.mariussuteu.eyesea.eyeseareporting`  
✅ **Signing configured:** `key.properties` file exists  
⚠️ **Passwords:** Currently using placeholder (`changeme123`) - **CHANGE THESE!**

---

## Step 1: Verify Google Play Console Account

**Critical Decision:** Which account should publish the app?

- **Personal account:** If you want to publish under your personal Google account
- **Corporate account (Eyesea):** If you want to publish under Eyesea's Google Play Console account

**Action Required:**
1. Decide which account to use
2. If corporate: Ensure you have access to Eyesea's Google Play Console
3. If personal: Use your personal Google account

**Note:** The package name `com.mariussuteu.eyesea.eyeseareporting` suggests personal, but you can still publish under corporate account - the package name just needs to match what you register in Play Console.

---

## Step 2: Create App in Google Play Console

1. Go to [Google Play Console](https://play.google.com/console)
2. Sign in with the account you chose (personal or corporate)
3. Click **"Create app"**
4. Fill in:
   - **App name:** "Eyesea Reporting"
   - **Default language:** English (or your preference)
   - **App or game:** App
   - **Free or paid:** Free
   - **Declarations:** Check all required boxes
5. Click **"Create app"**

---

## Step 3: Register Package Name

1. In Play Console → Your app → **Setup → App integrity**
2. Under **"App signing"**, you'll see your package name
3. **Important:** The package name must be exactly: `com.mariussuteu.eyesea.eyeseareporting`
4. If you need to change it, you'll need to update:
   - `android/app/build.gradle` → `applicationId`
   - `android/app/src/main/AndroidManifest.xml` → package references
   - Rebuild the app

---

## Step 4: Verify Keystore is Correct

Your keystore is just a signing key - it doesn't matter if it was created with personal or corporate credentials. However:

**If you want to use a NEW keystore for corporate account:**
1. Create a new keystore with corporate naming:
   ```bash
   keytool -genkey -v -keystore eyesea-corporate-release-key.jks \
     -keyalg RSA -keysize 2048 -validity 10000 \
     -alias eyesea-corporate-key \
     -storepass <strong-password> \
     -keypass <strong-password>
   ```
2. Update `key.properties` to point to the new keystore
3. **Important:** Once you upload an AAB to Play Console, you CANNOT change the keystore

**If keeping existing keystore:**
- Just ensure the passwords in `key.properties` are secure (not `changeme123`)

---

## Step 5: Complete Required Store Listing

1. **App access:** Set to "All users" or configure restricted access
2. **Content rating:** Complete questionnaire
3. **Target audience:** Set age groups
4. **Data safety:** Fill out data safety form (required for Supabase, location, camera)
5. **Privacy policy:** Upload privacy policy URL
6. **App icon:** Upload 512x512 icon
7. **Feature graphic:** Upload 1024x500 graphic
8. **Screenshots:** Upload screenshots (phone, tablet if applicable)

---

## Step 6: Prepare for First Upload

### 6a. Secure Your Keystore Passwords

1. Open `android/key.properties`
2. Change `storePassword` and `keyPassword` from `changeme123` to strong passwords
3. **Save these passwords securely** - you'll need them for:
   - Local builds
   - Codemagic CI/CD
   - Future updates

### 6b. Build App Bundle (AAB)

```bash
cd eyesea_reporting_2
flutter build appbundle --release \
  --dart-define=SUPABASE_URL=your_url \
  --dart-define=SUPABASE_ANON_KEY=your_key \
  --dart-define=MAPBOX_ACCESS_TOKEN=your_token
```

Output: `build/app/outputs/bundle/release/app-release.aab`

### 6c. Upload to Play Console

1. Go to Play Console → Your app → **Production** (or **Internal testing** for beta)
2. Click **"Create new release"**
3. Upload the `.aab` file
4. Fill in **Release notes**
5. Review and **Start rollout** (or save as draft)

---

## Step 7: Data Safety Form (Critical for Your App)

Since your app uses:
- **Supabase** (backend data)
- **Location services** (GPS)
- **Camera** (photo capture)
- **Photo library** (gallery access)

You MUST declare these in the Data Safety form:

1. Go to Play Console → **Policy → Data safety**
2. Answer questions about:
   - **Data collection:** Yes
   - **Data types collected:**
     - Location (approximate, precise)
     - Photos/Media
     - User content (reports)
   - **Data sharing:** With Supabase (your backend)
   - **Data security:** Encrypted in transit
   - **Data deletion:** Explain your deletion policy

---

## Step 8: Create Service Account for Codemagic (Optional)

If you want Codemagic to auto-upload:

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Create a service account
3. Download JSON key
4. In Play Console → **Setup → API access**, grant the service account access
5. Upload the JSON to Codemagic

---

## Checklist Summary

### Before First Upload
- [ ] Decided on account (personal vs corporate)
- [ ] Created app in Play Console
- [ ] Package name matches: `com.mariussuteu.eyesea.eyeseareporting`
- [ ] Keystore passwords changed from `changeme123`
- [ ] Keystore passwords saved securely
- [ ] Built AAB file successfully
- [ ] Data Safety form completed
- [ ] Privacy policy URL added
- [ ] Store listing information filled out

### For Codemagic CI/CD
- [ ] Keystore file located and accessible
- [ ] Keystore password, key alias, and key password documented
- [ ] Service account created (if using auto-upload)
- [ ] Service account JSON uploaded to Codemagic

---

## Important Notes

1. **Keystore is permanent:** Once you upload your first AAB, you CANNOT change the keystore. Keep backups!

2. **Package name:** Must match exactly between your app and Play Console

3. **Account choice:** The keystore doesn't determine the account - you choose the account when creating the app in Play Console

4. **Corporate vs Personal:** If you want to switch accounts later, you'd need to:
   - Create a new app in the other account
   - Use a different package name (or transfer the app, which is complex)

---

## Next Steps

1. **Decide on account** (personal vs corporate Eyesea)
2. **Secure keystore passwords** (change from `changeme123`)
3. **Create app in Play Console** under chosen account
4. **Complete Data Safety form** (required for apps with location/camera)
5. **Build and upload first AAB**

Need help with any specific step? Let me know!
