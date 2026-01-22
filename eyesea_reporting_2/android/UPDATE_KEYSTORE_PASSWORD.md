# How to Update Keystore Password

## ⚠️ CRITICAL WARNING

**If you've already uploaded an AAB to Google Play Console, you CANNOT change the keystore!**

Google Play requires the **same keystore** for all app updates. If you create a new keystore:
- ❌ You won't be able to update your existing app
- ❌ You'll have to publish as a completely new app
- ❌ You'll lose all existing users and ratings

---

## Option 1: Update key.properties (Recommended)

If you know the actual keystore password (not the placeholder), just update the file:

1. Open `android/key.properties`
2. Change the passwords:
   ```properties
   storePassword=your-actual-keystore-password
   keyPassword=your-actual-key-password
   ```
3. Save the file

**Note:** This only updates the file that stores the password. The keystore file itself still has the original password embedded in it.

---

## Option 2: Create New Keystore (ONLY if NOT published yet)

**⚠️ Only do this if you haven't uploaded to Google Play yet!**

### Step 1: Generate New Keystore

```bash
cd eyesea_reporting_2/android/app

keytool -genkey -v -keystore eyesea-release-key-new.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias eyesea-key \
  -storepass YOUR_STRONG_PASSWORD \
  -keypass YOUR_STRONG_PASSWORD
```

You'll be prompted for:
- **First and last name:** Your name or company name
- **Organizational unit:** (optional)
- **Organization:** Eyesea (or your company)
- **City:** Your city
- **State:** Your state/province
- **Country code:** US (or your country code)

### Step 2: Update key.properties

```properties
storePassword=YOUR_STRONG_PASSWORD
keyPassword=YOUR_STRONG_PASSWORD
keyAlias=eyesea-key
storeFile=app/eyesea-release-key-new.jks
```

### Step 3: Backup Old Keystore (Just in Case)

```bash
mv eyesea-release-key.jks eyesea-release-key-old.jks.backup
mv eyesea-release-key-new.jks eyesea-release-key.jks
```

### Step 4: Test Build

```bash
cd ../../..
flutter build appbundle --release
```

---

## Option 3: Change Keystore Password (Advanced - Not Recommended)

You can use `keytool` to change the password of an existing keystore, but this is risky:

```bash
keytool -storepasswd -keystore eyesea-release-key.jks
```

**Risks:**
- If you make a mistake, you could lock yourself out
- If the keystore is corrupted, you lose everything
- Google Play still requires the same keystore file (even with changed password)

**Better approach:** Just update `key.properties` with the correct password if you know it.

---

## For Codemagic

When uploading to Codemagic, use:
- **Keystore file:** `eyesea-release-key.jks`
- **Keystore password:** The password from `key.properties` (or the actual keystore password)
- **Key alias:** `eyesea-key`
- **Key password:** Same as keystore password (or from `key.properties`)

---

## Security Best Practices

1. **Use strong passwords:** At least 16 characters, mix of letters, numbers, symbols
2. **Store passwords securely:** Use a password manager
3. **Backup keystore:** Keep a secure backup of your keystore file
4. **Never commit keystore to git:** Already in `.gitignore` ✅
5. **Document passwords:** Store in a secure location (password manager, encrypted file)

---

## Current Status

- **Keystore file:** `android/app/eyesea-release-key.jks` ✅
- **Passwords in key.properties:** `changeme123` (placeholder) ⚠️
- **Action needed:** 
  - If already published: Keep existing keystore, just document the actual password
  - If NOT published: Create new keystore with strong password

---

## Quick Decision Tree

```
Have you uploaded to Google Play?
├─ YES → Keep existing keystore, just update key.properties with correct password
└─ NO  → Create new keystore with strong password, update key.properties
```
