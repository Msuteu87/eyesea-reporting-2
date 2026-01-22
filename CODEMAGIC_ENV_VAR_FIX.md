# Fix: "Invalid encryption key" Error in Codemagic

## The Problem

The error "Invalid encryption key - encrypted variables work only with builds in the same team they were created with" means:

- Your environment variables were created in a **different team/app** than where the build is running
- Or the variable group `eyesea_secrets` doesn't exist in the current context

---

## Solution: Re-create Environment Variables in the Correct Context

### Step 1: Identify Where Your Build is Running

1. Go to Codemagic → Your app (`eyesea-reporting-2`)
2. Check which **Team** the app belongs to
3. Note if variables should be at **App level** or **Team level**

### Step 2: Delete Old Variables (if needed)

1. Go to **Environment variables** tab in your app
2. If you see `eyesea_secrets` group, check which team it belongs to
3. If it's in the wrong team, you may need to delete and recreate

### Step 3: Create Variables in the Correct Location

**Option A: App-Level Variables (Recommended for single app)**

1. Go to your app → **Environment variables** tab
2. In the "Select group" dropdown, type: `eyesea_secrets`
3. Add each variable to this group:
   - `SUPABASE_URL` → value: (your Supabase URL) → Mark as **Secret** ✅
   - `SUPABASE_ANON_KEY` → value: (your anon key) → Mark as **Secret** ✅
   - `MAPBOX_ACCESS_TOKEN` → value: (your token) → Mark as **Secret** ✅

**Option B: Team-Level Variables (If you want to share across apps)**

1. Go to **Teams** → Your Team → **Global variables and secrets**
2. Create group: `eyesea_secrets`
3. Add the same three variables
4. Mark each as **Secret** ✅

### Step 4: Verify the Group is Accessible

1. After creating variables, go back to your app
2. Check **Environment variables** tab
3. You should see `eyesea_secrets` group listed
4. Verify all three variables are there

---

## Alternative: Use Individual Variables (If Groups Don't Work)

If the group approach still doesn't work, you can use individual variables:

### Update codemagic.yaml:

```yaml
environment:
  vars:
    SUPABASE_URL: Encrypted(...)  # Copy from Codemagic UI
    SUPABASE_ANON_KEY: Encrypted(...)
    MAPBOX_ACCESS_TOKEN: Encrypted(...)
```

**Steps:**
1. In Codemagic UI → Environment variables
2. Add each variable **without a group** (leave group empty)
3. Copy the `Encrypted(...)` value for each
4. Update `codemagic.yaml` to use `vars:` instead of `groups:`

---

## Quick Fix Checklist

- [ ] Identify which team/app your build runs in
- [ ] Delete old `eyesea_secrets` group if it's in wrong team
- [ ] Create new `eyesea_secrets` group in the **same team/app** as your build
- [ ] Add all 3 variables to the group
- [ ] Mark each as **Secret**
- [ ] Verify the group appears in your app's Environment variables tab
- [ ] Re-run the build

---

## Current Configuration

Your `codemagic.yaml` expects:
```yaml
environment:
  groups:
    - eyesea_secrets
```

So you need:
- A variable group named `eyesea_secrets`
- Created in the **same team/app** as your build
- Containing: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `MAPBOX_ACCESS_TOKEN`

---

## Still Not Working?

If you still get the error after recreating variables:

1. **Check team membership:**
   - Verify you're in the correct team
   - Check app belongs to the team

2. **Try app-level variables:**
   - Create variables directly in the app (not team level)
   - This ensures they're in the same context as the build

3. **Use individual vars instead of groups:**
   - Switch to `vars:` in codemagic.yaml
   - Add variables individually without groups
