# Eyesea External Reporting API

## Overview

The Eyesea External Reporting API allows partner applications to submit marine pollution reports programmatically. Reports submitted via the API follow the same verification and display workflow as reports submitted through the mobile app.

**Base URL:** `https://xqbnlvstjkmvqzdkuqpi.supabase.co/functions/v1`

---

## Authentication

All API requests require authentication via an API key.

### Obtaining an API Key

Contact the Eyesea team to request an API key for your application. Each API key is:
- Unique to your organization
- Rate-limited (default: 1,000 requests/day)
- Trackable for usage analytics

### Using Your API Key

Include your API key in the `X-API-Key` header with every request:

```
X-API-Key: eyesea_your_api_key_here
```

> **Security Note:** Keep your API key confidential. Do not expose it in client-side code, public repositories, or logs.

---

## Endpoints

### Submit Report

Creates a new pollution report with images.

```
POST /submit-report
```

#### Headers

| Header | Required | Description |
|--------|----------|-------------|
| `Content-Type` | Yes | Must be `application/json` |
| `X-API-Key` | Yes | Your API key |

#### Request Body

```json
{
  "latitude": 37.7749,
  "longitude": -122.4194,
  "pollution_type": "plastic",
  "severity": 3,
  "notes": "Large accumulation of plastic bottles on shoreline",
  "city": "San Francisco",
  "country": "USA",
  "pollution_counts": {
    "plastic": 15,
    "debris": 3
  },
  "images": [
    {
      "data": "base64_encoded_image_data...",
      "is_primary": true
    }
  ],
  "source_reference": "your-internal-id-123"
}
```

#### Field Reference

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `latitude` | number | Yes | Latitude coordinate (-90 to 90) |
| `longitude` | number | Yes | Longitude coordinate (-180 to 180) |
| `pollution_type` | string | Yes | Primary pollution category (see below) |
| `severity` | integer | Yes | Severity level (1-5, where 5 is most severe) |
| `notes` | string | No | Additional description or observations |
| `city` | string | No | City name where pollution was observed |
| `country` | string | No | Country name |
| `pollution_counts` | object | No | Count of items by pollution type |
| `images` | array | Yes | Array of image objects (1-5 images) |
| `source_reference` | string | No | Your system's internal ID for this report |

#### Pollution Types

The `pollution_type` field must be one of:

| Value | Description |
|-------|-------------|
| `plastic` | Plastic bottles, bags, containers, microplastics |
| `oil` | Oil spills, fuel slicks, petroleum products |
| `debris` | General marine debris, mixed waste |
| `sewage` | Sewage discharge, wastewater |
| `fishing_gear` | Nets, lines, traps, buoys |
| `container` | Shipping containers, large industrial debris |
| `other` | Other pollution not fitting above categories |

#### Severity Scale

| Level | Description |
|-------|-------------|
| 1 | Minor - Small amount, localized |
| 2 | Low - Noticeable but limited impact |
| 3 | Moderate - Significant accumulation |
| 4 | High - Large area affected, potential harm |
| 5 | Critical - Severe pollution, immediate concern |

#### Image Requirements

- **Format:** JPEG, PNG, or WebP
- **Encoding:** Base64 (with or without data URL prefix)
- **Max size:** 5 MB per image
- **Max count:** 5 images per request
- **Min count:** 1 image required

Image data can include the data URL prefix:
```
data:image/jpeg;base64,/9j/4AAQSkZJRgABAQ...
```

Or be raw base64:
```
/9j/4AAQSkZJRgABAQ...
```

#### Success Response (201 Created)

```json
{
  "success": true,
  "data": {
    "report_id": "550e8400-e29b-41d4-a716-446655440000",
    "status": "pending",
    "image_count": 1,
    "image_urls": [
      "https://xqbnlvstjkmvqzdkuqpi.supabase.co/storage/v1/object/public/report-images/api/YourPartner/550e8400.../2026-01-14T10-30-00-000Z_0.jpeg"
    ],
    "created_at": "2026-01-14T10:30:00.000Z"
  }
}
```

#### Response with Warnings

If some images fail but at least one succeeds:

```json
{
  "success": true,
  "data": {
    "report_id": "550e8400-e29b-41d4-a716-446655440000",
    "status": "pending",
    "image_count": 2,
    "image_urls": ["..."],
    "created_at": "2026-01-14T10:30:00.000Z"
  },
  "warnings": [
    "Image 3: Image exceeds maximum size of 5MB"
  ]
}
```

---

## Error Responses

All error responses follow this format:

```json
{
  "success": false,
  "error": {
    "code": "ERROR_CODE",
    "message": "Human-readable error description",
    "field": "field_name"
  }
}
```

### Error Codes

| HTTP Status | Code | Description |
|-------------|------|-------------|
| 401 | `MISSING_API_KEY` | X-API-Key header not provided |
| 401 | `INVALID_API_KEY` | API key is invalid or expired |
| 429 | `RATE_LIMITED` | Daily rate limit exceeded |
| 400 | `INVALID_JSON` | Request body is not valid JSON |
| 400 | `VALIDATION_ERROR` | Request validation failed (see message/field) |
| 400 | `IMAGE_UPLOAD_FAILED` | All images failed to upload |
| 500 | `DATABASE_ERROR` | Server error creating report |
| 500 | `CONFIG_ERROR` | Server configuration issue |
| 500 | `INTERNAL_ERROR` | Unexpected server error |

### Validation Errors

The `field` property indicates which field caused the error:

```json
{
  "success": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "latitude must be between -90 and 90",
    "field": "latitude"
  }
}
```

---

## Rate Limiting

- **Default limit:** 1,000 requests per day per API key
- **Reset time:** Daily at 00:00 UTC
- **Response when exceeded:** HTTP 429 with `RATE_LIMITED` error

Contact us if you need a higher rate limit for your integration.

---

## Report Lifecycle

Reports submitted via the API go through the following statuses:

1. **pending** - Initial state, awaiting review
2. **verified** - Confirmed as valid pollution report
3. **resolved** - Pollution has been cleaned up
4. **rejected** - Report was invalid or duplicate

Your `source_reference` can be used to track which reports in your system correspond to Eyesea reports.

---

## Code Examples

### cURL

```bash
curl -X POST https://xqbnlvstjkmvqzdkuqpi.supabase.co/functions/v1/submit-report \
  -H "Content-Type: application/json" \
  -H "X-API-Key: eyesea_your_api_key_here" \
  -d '{
    "latitude": 37.7749,
    "longitude": -122.4194,
    "pollution_type": "plastic",
    "severity": 3,
    "notes": "Plastic debris on beach",
    "images": [{
      "data": "'$(base64 -i photo.jpg)'",
      "is_primary": true
    }]
  }'
```

### Python

```python
import requests
import base64

API_KEY = "eyesea_your_api_key_here"
BASE_URL = "https://xqbnlvstjkmvqzdkuqpi.supabase.co/functions/v1"

def submit_report(image_path, latitude, longitude, pollution_type, severity, notes=None):
    # Read and encode image
    with open(image_path, "rb") as f:
        image_data = base64.b64encode(f.read()).decode("utf-8")

    payload = {
        "latitude": latitude,
        "longitude": longitude,
        "pollution_type": pollution_type,
        "severity": severity,
        "notes": notes,
        "images": [{"data": image_data, "is_primary": True}]
    }

    response = requests.post(
        f"{BASE_URL}/submit-report",
        json=payload,
        headers={
            "Content-Type": "application/json",
            "X-API-Key": API_KEY
        }
    )

    return response.json()

# Example usage
result = submit_report(
    image_path="pollution_photo.jpg",
    latitude=37.7749,
    longitude=-122.4194,
    pollution_type="plastic",
    severity=3,
    notes="Plastic bottles found near pier"
)

if result["success"]:
    print(f"Report created: {result['data']['report_id']}")
else:
    print(f"Error: {result['error']['message']}")
```

### JavaScript / Node.js

```javascript
const fs = require('fs');

const API_KEY = 'eyesea_your_api_key_here';
const BASE_URL = 'https://xqbnlvstjkmvqzdkuqpi.supabase.co/functions/v1';

async function submitReport(imagePath, latitude, longitude, pollutionType, severity, notes) {
  // Read and encode image
  const imageBuffer = fs.readFileSync(imagePath);
  const imageData = imageBuffer.toString('base64');

  const payload = {
    latitude,
    longitude,
    pollution_type: pollutionType,
    severity,
    notes,
    images: [{ data: imageData, is_primary: true }]
  };

  const response = await fetch(`${BASE_URL}/submit-report`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-API-Key': API_KEY
    },
    body: JSON.stringify(payload)
  });

  return response.json();
}

// Example usage
submitReport(
  'pollution_photo.jpg',
  37.7749,
  -122.4194,
  'plastic',
  3,
  'Plastic bottles found near pier'
).then(result => {
  if (result.success) {
    console.log(`Report created: ${result.data.report_id}`);
  } else {
    console.error(`Error: ${result.error.message}`);
  }
});
```

### Swift (iOS)

```swift
import Foundation

struct EyeseaAPI {
    static let apiKey = "eyesea_your_api_key_here"
    static let baseURL = "https://xqbnlvstjkmvqzdkuqpi.supabase.co/functions/v1"

    static func submitReport(
        imageData: Data,
        latitude: Double,
        longitude: Double,
        pollutionType: String,
        severity: Int,
        notes: String? = nil
    ) async throws -> [String: Any] {
        let base64Image = imageData.base64EncodedString()

        let payload: [String: Any] = [
            "latitude": latitude,
            "longitude": longitude,
            "pollution_type": pollutionType,
            "severity": severity,
            "notes": notes as Any,
            "images": [["data": base64Image, "is_primary": true]]
        ]

        var request = URLRequest(url: URL(string: "\(baseURL)/submit-report")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONSerialization.jsonObject(with: data) as! [String: Any]
    }
}
```

### Kotlin (Android)

```kotlin
import okhttp3.*
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.util.Base64

object EyeseaAPI {
    private const val API_KEY = "eyesea_your_api_key_here"
    private const val BASE_URL = "https://xqbnlvstjkmvqzdkuqpi.supabase.co/functions/v1"

    private val client = OkHttpClient()

    fun submitReport(
        imageFile: File,
        latitude: Double,
        longitude: Double,
        pollutionType: String,
        severity: Int,
        notes: String? = null
    ): JSONObject {
        val imageData = Base64.getEncoder().encodeToString(imageFile.readBytes())

        val payload = JSONObject().apply {
            put("latitude", latitude)
            put("longitude", longitude)
            put("pollution_type", pollutionType)
            put("severity", severity)
            notes?.let { put("notes", it) }
            put("images", JSONArray().put(JSONObject().apply {
                put("data", imageData)
                put("is_primary", true)
            }))
        }

        val request = Request.Builder()
            .url("$BASE_URL/submit-report")
            .post(payload.toString().toRequestBody("application/json".toMediaType()))
            .addHeader("X-API-Key", API_KEY)
            .build()

        client.newCall(request).execute().use { response ->
            return JSONObject(response.body?.string() ?: "{}")
        }
    }
}
```

---

## Best Practices

1. **Compress images** before encoding to base64 to reduce payload size and improve upload speed.

2. **Include accurate coordinates** - GPS accuracy significantly impacts report usefulness.

3. **Use meaningful notes** - Describe what you observed, approximate quantity, and any hazards.

4. **Handle errors gracefully** - Implement retry logic for 5xx errors with exponential backoff.

5. **Store report IDs** - Save the returned `report_id` to track report status in your system.

6. **Respect rate limits** - Implement client-side rate limiting to avoid 429 errors.

---

## Support

For API support, questions, or to request a higher rate limit:

- **Email:** api@eyesea.app
- **GitHub Issues:** https://github.com/eyesea-app/issues

---

## Changelog

### v1.0.0 (January 2026)
- Initial API release
- Submit report endpoint with image upload
- API key authentication with rate limiting
