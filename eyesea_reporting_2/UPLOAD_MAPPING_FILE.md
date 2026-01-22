# How to Upload mapping.txt to Google Play Console

## What is mapping.txt?

When R8/ProGuard is enabled (which we just did), your app's code gets **obfuscated** (class and method names are renamed to short codes like `a`, `b`, `c`). This makes your app smaller and harder to reverse-engineer.

**The problem:** When your app crashes, Google Play will send you crash reports with obfuscated names like:
```
java.lang.NullPointerException: at a.b.c.d(SourceFile:123)
```

**The solution:** The `mapping.txt` file maps these obfuscated names back to your original code:
```
a.b.c.d → com.eyesea.reporting.ReportScreen.onSubmit()
```

This makes crash reports readable so you can actually debug issues!

---

## Where to Upload mapping.txt

### Step 1: Go to Your Release
1. Open [Google Play Console](https://play.google.com/console)
2. Select your app: **"Eyesea Reporting"**
3. In the left sidebar, go to **"Release"** → **"Production"** (or **"Internal testing"** / **"Closed testing"**)
4. Click **"Create new release"** (or edit an existing release)

### Step 2: Upload Your AAB
1. In the release page, scroll to **"App bundles and APKs"**
2. Click **"Upload"** or drag-and-drop your AAB file:
   - File: `build/app/outputs/bundle/release/app-release.aab`
3. Wait for the upload to complete

### Step 3: Upload mapping.txt
After the AAB uploads, you'll see one of these options:

#### Option A: "Deobfuscation file" section (most common)
- Look for a section labeled **"Deobfuscation file"** or **"ProGuard mapping file"**
- It appears right below or near the uploaded AAB
- Click **"Upload"** next to it
- Select: `build/app/outputs/mapping/release/mapping.txt`

#### Option B: "App bundle explorer" (alternative)
1. After uploading the AAB, click on the AAB file name or **"App bundle explorer"**
2. In the bundle details, look for **"Deobfuscation file"** or **"Upload mapping file"**
3. Click **"Upload"** and select `mapping.txt`

#### Option C: "Release details" page
1. After uploading the AAB, scroll down to **"Release details"**
2. Look for **"Deobfuscation file"** section
3. Click **"Upload"** and select `mapping.txt`

### Step 4: Verify Upload
- You should see a checkmark or confirmation that the mapping file is uploaded
- The warning message about missing deobfuscation file should disappear

---

## Visual Guide

```
Google Play Console
└── Your App: "Eyesea Reporting"
    └── Release → Production
        └── Create new release
            ├── App bundles and APKs
            │   └── [Upload AAB here] ✅
            │       └── Deobfuscation file ← [Upload mapping.txt here] ✅
            ├── Release name
            ├── Release notes
            └── Review and publish
```

---

## File Locations

- **AAB file:** `eyesea_reporting_2/build/app/outputs/bundle/release/app-release.aab`
- **Mapping file:** `eyesea_reporting_2/build/app/outputs/mapping/release/mapping.txt`

---

## Important Notes

1. **Upload mapping.txt for EVERY release** - Each build generates a new mapping file that matches that specific AAB
2. **Keep mapping.txt files** - Store them with your release builds in case you need to debug old crashes later
3. **The warning will disappear** - Once uploaded, Google Play will stop showing the "no deobfuscation file" warning
4. **Automatic deobfuscation** - Google Play will automatically use this file when processing crash reports

---

## Troubleshooting

**Q: I don't see a "Deobfuscation file" option**
- Make sure you've uploaded the AAB first
- Try refreshing the page
- Check if you're on the correct release page (Production/Internal testing)

**Q: The upload button is grayed out**
- Ensure the AAB has finished uploading completely
- Wait a few seconds and refresh

**Q: Can I upload it later?**
- Yes, you can upload the mapping file even after publishing, but it's better to do it before publishing

---

## Next Steps

After uploading both files:
1. ✅ AAB uploaded
2. ✅ mapping.txt uploaded
3. Fill in release notes
4. Review the release
5. Click **"Save"** or **"Start rollout to Production"**
