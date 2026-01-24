# Email Templates Setup Guide

This directory contains HTML email templates for Supabase Auth email notifications.

## Logo Setup

The templates use the Eyesea logo from Supabase Storage. Follow these steps to set it up:

### 1. Create the Storage Bucket

**IMPORTANT:** For hosted Supabase, you must create the bucket manually via the dashboard first, then run the migration for policies.

**Step 1: Create Bucket via Dashboard**
1. Go to your Supabase project dashboard
2. Navigate to **Storage** → **Buckets**
3. Click **New Bucket**
4. Configure:
   - **Name:** `static-assets`
   - **Public bucket:** ✅ Yes (checked)
   - **File size limit:** 5MB
   - **Allowed MIME types:** `image/png`, `image/jpeg`, `image/svg+xml`, `image/webp`
5. Click **Create bucket**

**Step 2: Run Migration for Policies**
After creating the bucket, run the migration to create the storage policies:

```bash
supabase db push
```

Or apply the migration via the Supabase dashboard SQL editor.

### 2. Upload the Logo

Upload your logo to Supabase Storage:

**Option A: Using Supabase Dashboard**
1. Go to your Supabase project dashboard
2. Navigate to **Storage** → **Buckets**
3. Open the `static-assets` bucket
4. Click **Upload file**
5. Upload `eyesea_reporting_2/assets/images/logo.png`
6. The file will be accessible at: `https://[your-project-ref].supabase.co/storage/v1/object/public/static-assets/logo.png`

**Option B: Using Supabase CLI**
```bash
supabase storage upload logo.png static-assets/logo.png --project-ref [your-project-ref]
```

### 3. Update Templates with Your Project URL

Replace `[YOUR-PROJECT-REF]` in all template files with your actual Supabase project reference.

The logo URL format is:
```
https://[YOUR-PROJECT-REF].supabase.co/storage/v1/object/public/static-assets/logo.png
```

**Quick find & replace:**
```bash
# Replace [YOUR-PROJECT-REF] with your actual project ref in all templates
find supabase/templates -name "*.html" -exec sed -i '' 's/\[YOUR-PROJECT-REF\]/your-actual-project-ref/g' {} \;
```

### 4. Configure Templates in Supabase

In your Supabase dashboard:
1. Go to **Authentication** → **Email Templates**
2. For each template type, click **Edit**
3. Upload or paste the HTML from the corresponding template file
4. Save

Or configure in `config.toml`:
```toml
[auth.email.template.confirm_signup]
subject = "Confirm Your Email - Eyesea"
content_path = "./supabase/templates/confirm_signup.html"

[auth.email.template.invite]
subject = "You've Been Invited to Join Eyesea"
content_path = "./supabase/templates/invite.html"

[auth.email.template.magic_link]
subject = "Sign In to Eyesea"
content_path = "./supabase/templates/magic_link.html"

[auth.email.template.change_email]
subject = "Verify Your New Email - Eyesea"
content_path = "./supabase/templates/change_email_address.html"

[auth.email.template.reset_password]
subject = "Reset Your Password - Eyesea"
content_path = "./supabase/templates/reset_password.html"

[auth.email.template.reauthentication]
subject = "Re-authenticate Your Account - Eyesea"
content_path = "./supabase/templates/reauthentication.html"
```

## Available Templates

1. **confirm_signup.html** - Email confirmation after signup
2. **invite.html** - User invitation emails
3. **magic_link.html** - Magic link sign-in emails
4. **change_email_address.html** - New email verification
5. **reset_password.html** - Password reset emails
6. **reauthentication.html** - Re-authentication for sensitive actions

## Template Variables

Supabase provides these variables in email templates:
- `{{ .ConfirmationURL }}` - Full confirmation URL with token
- `{{ .Token }}` - 6-digit OTP code
- `{{ .TokenHash }}` - Hashed token
- `{{ .SiteURL }}` - Your site URL from config
- `{{ .Email }}` - User's email address
- `{{ .RedirectTo }}` - Redirect URL after confirmation

## Testing

Test your email templates:
1. Use Supabase's email testing feature in the dashboard
2. Or trigger each email type through your app and check the inbox
3. Verify the logo displays correctly in various email clients

## Notes

- The logo must be publicly accessible (bucket must be public)
- Email clients have varying CSS support - templates use inline styles for maximum compatibility
- Test in multiple email clients (Gmail, Outlook, Apple Mail, etc.)
