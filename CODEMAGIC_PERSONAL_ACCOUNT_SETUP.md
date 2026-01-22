# Codemagic Setup for Personal Account (No Teams)

Since you're using a **personal account** (no teams), all environment variables must be created at the **app level**.

---

## Step 1: Create Environment Variables in Your App

1. Go to Codemagic → Your app: **eyesea-reporting-2**
2. Click the **"Environment variables"** tab
3. You should see: "Application environment variables" section

### Create the Variable Group

1. In the "Variable name" field, enter: `SUPABASE_URL`
2. In the "Variable value" field, enter your Supabase URL
3. In the "Select group" dropdown, type: `eyesea_secrets` (this will create the group)
4. Check **"Secret"** ✅
5. Click **"Add"**

### Add Remaining Variables

Repeat for the other two variables, **using the same group name** (`eyesea_secrets`):

1. **SUPABASE_ANON_KEY**
   - Variable name: `SUPABASE_ANON_KEY`
   - Variable value: (your Supabase anon key)
   - Group: `eyesea_secrets`
   - Secret: ✅
   - Click "Add"

2. **MAPBOX_ACCESS_TOKEN**
   - Variable name: `MAPBOX_ACCESS_TOKEN`
   - Variable value: (your Mapbox token)
   - Group: `eyesea_secrets`
   - Secret: ✅
   - Click "Add"

---

## Step 2: Verify Variables Are Created

After adding all three variables, you should see:

- **Group:** `eyesea_secrets`
- **Variables in group:**
  - `SUPABASE_URL` (Secret)
  - `SUPABASE_ANON_KEY` (Secret)
  - `MAPBOX_ACCESS_TOKEN` (Secret)

---

## Step 3: Important Notes for Personal Accounts

✅ **DO:**
- Create variables in **App → Environment variables** tab
- Use the same group name for all variables
- Mark all as **Secret**

❌ **DON'T:**
- Don't try to create variables in "Team" settings (you don't have teams)
- Don't create variables in different groups
- Don't forget to mark them as Secret

---

## Step 4: Verify codemagic.yaml

Your `codemagic.yaml` should have:
```yaml
environment:
  groups:
    - eyesea_secrets
```

This is correct! ✅

---

## Troubleshooting

### Error: "Invalid encryption key"

**If you still get this error:**

1. **Delete all existing variables:**
   - Go to Environment variables tab
   - Delete any existing `eyesea_secrets` group or variables
   - Start fresh

2. **Recreate them one by one:**
   - Make sure you're in the **app's** Environment variables tab
   - Not in any team settings
   - Create the group by typing it in the dropdown

3. **Verify the group name:**
   - Must be exactly: `eyesea_secrets`
   - No extra spaces
   - All lowercase (except if you used different casing)

---

## Quick Checklist

- [ ] Using personal account (no teams)
- [ ] In app: **eyesea-reporting-2** → **Environment variables** tab
- [ ] Created group: `eyesea_secrets`
- [ ] Added `SUPABASE_URL` to group (marked Secret)
- [ ] Added `SUPABASE_ANON_KEY` to group (marked Secret)
- [ ] Added `MAPBOX_ACCESS_TOKEN` to group (marked Secret)
- [ ] All three variables visible in the group
- [ ] `codemagic.yaml` references `eyesea_secrets` group

---

## Alternative: Individual Variables (If Groups Still Don't Work)

If the group approach still fails, we can switch to individual variables:

1. I'll update `codemagic.yaml` to use `vars:` instead of `groups:`
2. You'll add each variable individually (without a group)
3. Copy the encrypted values to `codemagic.yaml`

Let me know if you want to try this approach!
