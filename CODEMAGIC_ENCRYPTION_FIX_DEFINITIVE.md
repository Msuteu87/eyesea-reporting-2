# DEFINITIVE FIX: Invalid Encryption Key Error

## Root Cause

Even personal accounts have an implicit "Personal Account" team context. Variables encrypted in one context cannot be decrypted in another. This happens when:
- Variables were created before the app was fully set up
- Variables exist in multiple places (app vs team)
- The app's encryption context changed

---

## Solution: Complete Clean Slate Approach

### Step 1: DELETE Everything (Critical!)

1. Go to Codemagic → Your app: **eyesea-reporting-2**
2. Click **"Environment variables"** tab
3. **Delete the entire `eyesea_secrets` group** (if it exists)
4. **Delete any individual variables** named:
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`
   - `MAPBOX_ACCESS_TOKEN`
5. Make sure **nothing** remains in Environment variables

### Step 2: Verify You're in the Right Place

- You should be in: **App → eyesea-reporting-2 → Environment variables**
- NOT in: Team settings, Global variables, or any other location
- The page should say: **"Application environment variables"**

### Step 3: Create Variables Fresh (Method 1: Groups)

1. **First variable creates the group:**
   - Variable name: `SUPABASE_URL`
   - Variable value: (paste your Supabase URL)
   - Select group: Type `eyesea_secrets` (this creates it)
   - ✅ Check **"Secret"**
   - Click **"Add"**

2. **Add second variable to same group:**
   - Variable name: `SUPABASE_ANON_KEY`
   - Variable value: (paste your anon key)
   - Select group: `eyesea_secrets` (select from dropdown now)
   - ✅ Check **"Secret"**
   - Click **"Add"**

3. **Add third variable to same group:**
   - Variable name: `MAPBOX_ACCESS_TOKEN`
   - Variable value: (paste your token)
   - Select group: `eyesea_secrets` (select from dropdown)
   - ✅ Check **"Secret"**
   - Click **"Add"**

### Step 4: Verify

After adding all three, you should see:
- Group: `eyesea_secrets` (1 group)
- Variables: 3 variables (all marked Secret)

---

## Alternative Solution: Individual Variables (If Groups Still Fail)

If the group approach still gives encryption errors, use individual variables:

### Step 1: Delete Everything (Same as above)

### Step 2: Create Variables WITHOUT Groups

1. **Variable 1:**
   - Variable name: `SUPABASE_URL`
   - Variable value: (your URL)
   - Select group: **Leave EMPTY** (don't select/create a group)
   - ✅ Check **"Secret"**
   - Click **"Add"**
   - **Copy the `Encrypted(...)` value** that appears

2. **Variable 2:**
   - Variable name: `SUPABASE_ANON_KEY`
   - Variable value: (your key)
   - Select group: **Leave EMPTY**
   - ✅ Check **"Secret"**
   - Click **"Add"**
   - **Copy the `Encrypted(...)` value**

3. **Variable 3:**
   - Variable name: `MAPBOX_ACCESS_TOKEN`
   - Variable value: (your token)
   - Select group: **Leave EMPTY**
   - ✅ Check **"Secret"**
   - Click **"Add"**
   - **Copy the `Encrypted(...)` value**

### Step 3: Update codemagic.yaml

I'll update the YAML to use `vars:` instead of `groups:`. You'll need to paste the encrypted values.

---

## Why This Works

- **Fresh encryption:** New variables get encrypted with the current app's encryption key
- **Same context:** Variables created in the app are accessible to builds in that app
- **No conflicts:** Deleting old variables removes encryption key mismatches

---

## Verification Checklist

Before running a build:
- [ ] All old variables deleted
- [ ] Variables created in: **App → eyesea-reporting-2 → Environment variables**
- [ ] All variables marked as **Secret**
- [ ] Group name is exactly: `eyesea_secrets` (if using groups)
- [ ] OR variables have no group (if using individual vars)
- [ ] codemagic.yaml matches the approach (groups vs vars)

---

## Still Not Working?

If you still get the error after following this exactly:

1. **Screenshot your Environment variables page** - show me what you see
2. **Check build logs** - copy the exact error message
3. **Try individual vars approach** - this is more reliable for personal accounts
