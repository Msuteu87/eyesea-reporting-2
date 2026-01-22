# Codemagic App Store Connect Integration Troubleshooting

## Error: "app_store_connect key is not correct"

If you see this error even though the integration is configured in Codemagic UI, try these solutions:

---

## Solution 1: Verify Exact Name Match (Case-Sensitive)

The integration name in `codemagic.yaml` must **exactly match** the name in Codemagic UI.

1. **In Codemagic UI:**
   - Go to Team integrations → Apple Developer Portal
   - Check the **exact name** shown (including capitalization)
   - Copy it exactly

2. **In codemagic.yaml:**
   - Verify the name matches exactly:
   ```yaml
   integrations:
     app_store_connect: Eyesea_reporting_codemagic  # Must match exactly
   ```

3. **Common issues:**
   - Extra spaces
   - Different capitalization
   - Special characters

---

## Solution 2: Check Team vs App Level

If the integration is at **Team level**, make sure:

1. **Your app has access to the team:**
   - Go to your app → Settings
   - Verify the team is selected
   - Check that you have access to team integrations

2. **Integration is shared:**
   - Team integrations should be accessible to all apps in the team
   - If not, you may need to add it at app level instead

---

## Solution 3: Verify Integration Status

1. **Check integration status:**
   - Go to Team integrations → Apple Developer Portal
   - Verify the integration shows **green/active** status
   - Check for any error messages

2. **Verify API key details:**
   - Key ID is correct
   - Issuer ID is correct
   - .p8 file is uploaded and valid

---

## Solution 4: Check Apple Developer Account

1. **Verify agreements:**
   - Go to [App Store Connect → Agreements](https://appstoreconnect.apple.com/agreements/#/)
   - Ensure all agreements are **Active** (not expired)
   - Accept any pending agreements

2. **Verify API key permissions:**
   - Go to [App Store Connect → Users and Access → Keys](https://appstoreconnect.apple.com/access/api)
   - Check that the API key has **App Manager** role (or higher)
   - Verify the key is **Active**

3. **Check bundle ID access:**
   - The API key must have access to the bundle ID: `com.mariussuteu.eyesea.eyeseareporting`
   - Verify in App Store Connect that this bundle ID exists

---

## Solution 5: Try Alternative Configuration

If using `auth: integration` doesn't work, try using the API key directly:

```yaml
publishing:
  app_store_connect:
    auth: api_key
    api_key: Encrypted(...)  # Your .p8 file content (base64 encoded)
    key_id: YOUR_KEY_ID
    issuer_id: YOUR_ISSUER_ID
```

**Note:** This requires encoding the .p8 file as base64 and storing it as an encrypted environment variable.

---

## Solution 6: Check Build Logs

1. **Look for specific error messages:**
   - "Unable to authenticate"
   - "A required agreement is missing"
   - "Bundle ID not found"
   - "Insufficient permissions"

2. **Check the exact error code:**
   - Error codes can indicate specific issues
   - Common codes: -22020, -19209

---

## Solution 7: Re-create Integration

If nothing else works:

1. **Delete the integration in Codemagic:**
   - Team integrations → Apple Developer Portal
   - Delete "Eyesea_reporting_codemagic"

2. **Re-create it:**
   - Use the exact same name: `Eyesea_reporting_codemagic`
   - Re-upload the .p8 file
   - Re-enter Key ID and Issuer ID

3. **Verify it's active:**
   - Check for green status indicator
   - Wait a few minutes for propagation

---

## Quick Checklist

- [ ] Integration name in YAML matches UI exactly (case-sensitive)
- [ ] Integration shows green/active status in Codemagic
- [ ] API key is active in App Store Connect
- [ ] All Apple Developer agreements are active
- [ ] Bundle ID exists in App Store Connect
- [ ] API key has App Manager role
- [ ] Team/app has access to the integration
- [ ] No typos or extra spaces in integration name

---

## Current Configuration

**In codemagic.yaml:**
```yaml
integrations:
  app_store_connect: Eyesea_reporting_codemagic
```

**Verify in Codemagic UI:**
- Team integrations → Apple Developer Portal
- Should see: "Eyesea_reporting_codemagic" with green status

---

## Still Not Working?

1. **Check Codemagic build logs** for the exact error message
2. **Verify the integration name** character-by-character
3. **Try creating a new integration** with a simpler name (e.g., `eyesea_asc`)
4. **Contact Codemagic support** with:
   - Build log error
   - Integration name
   - Screenshot of integration status
