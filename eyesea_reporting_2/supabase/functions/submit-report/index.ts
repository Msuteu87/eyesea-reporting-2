/**
 * External Reporting API - Submit Report Edge Function
 *
 * Allows external applications to submit pollution reports via API.
 *
 * Endpoint: POST /functions/v1/submit-report
 * Headers: X-API-Key: <api_key>
 *
 * Request Body:
 * {
 *   "latitude": number,        // Required: -90 to 90
 *   "longitude": number,       // Required: -180 to 180
 *   "pollution_type": string,  // Required: plastic|oil|debris|sewage|fishing_gear|container|other
 *   "severity": number,        // Required: 1-5
 *   "notes": string,           // Optional
 *   "city": string,            // Optional
 *   "country": string,         // Optional
 *   "pollution_counts": {},    // Optional: {"plastic": 5, "debris": 2}
 *   "images": [{               // Required: at least one
 *     "data": string,          // Base64 encoded image
 *     "is_primary": boolean    // Optional, first image is primary by default
 *   }],
 *   "source_reference": string // Optional: external system's ID for this report
 * }
 */

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// CORS headers for cross-origin requests
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-api-key",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// Valid pollution type values (must match database enum)
const VALID_POLLUTION_TYPES = [
  "plastic",
  "oil",
  "debris",
  "sewage",
  "fishing_gear",
  "container",
  "other",
];

// Configuration
const MAX_IMAGE_SIZE_BYTES = 5 * 1024 * 1024; // 5MB per image
const MAX_IMAGES_PER_REQUEST = 5;

// TypeScript interfaces
interface ImageData {
  data: string;
  is_primary?: boolean;
}

interface ReportRequest {
  latitude: number;
  longitude: number;
  pollution_type: string;
  severity: number;
  notes?: string;
  city?: string;
  country?: string;
  pollution_counts?: Record<string, number>;
  images: ImageData[];
  source_reference?: string;
}

interface ValidationResult {
  valid: boolean;
  message?: string;
  field?: string;
}

// Main request handler
serve(async (req: Request): Promise<Response> => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  // Only accept POST requests
  if (req.method !== "POST") {
    return errorResponse(405, "METHOD_NOT_ALLOWED", "Only POST method is allowed");
  }

  try {
    // 1. Validate API Key
    const apiKey = req.headers.get("x-api-key");
    if (!apiKey) {
      return errorResponse(401, "MISSING_API_KEY", "X-API-Key header is required");
    }

    // Initialize Supabase client with service role key
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!supabaseUrl || !supabaseKey) {
      console.error("Missing Supabase environment variables");
      return errorResponse(500, "CONFIG_ERROR", "Server configuration error");
    }

    const supabase = createClient(supabaseUrl, supabaseKey);

    // Validate the API key using database function
    const { data: keyValidation, error: keyError } = await supabase.rpc(
      "validate_api_key",
      { p_key: apiKey }
    );

    if (keyError) {
      console.error("API key validation error:", keyError);
      return errorResponse(500, "VALIDATION_ERROR", "Failed to validate API key");
    }

    const validationResult = keyValidation?.[0];
    if (!validationResult?.is_valid) {
      return errorResponse(401, "INVALID_API_KEY", "Invalid or expired API key");
    }
    if (validationResult.rate_limited) {
      return errorResponse(
        429,
        "RATE_LIMITED",
        "Daily rate limit exceeded. Try again tomorrow."
      );
    }

    const sourceName = validationResult.key_name;
    console.log(`API request from: ${sourceName}`);

    // 2. Parse and validate request body
    let body: ReportRequest;
    try {
      body = await req.json();
    } catch {
      return errorResponse(400, "INVALID_JSON", "Request body must be valid JSON");
    }

    const validation = validateRequest(body);
    if (!validation.valid) {
      return errorResponse(
        400,
        "VALIDATION_ERROR",
        validation.message!,
        validation.field
      );
    }

    // 3. Create report record
    const reportId = crypto.randomUUID();
    const { error: reportError } = await supabase.from("reports").insert({
      id: reportId,
      user_id: null, // API submissions don't have an authenticated user
      location: `POINT(${body.longitude} ${body.latitude})`,
      pollution_type: body.pollution_type,
      severity: body.severity,
      notes: body.notes || null,
      city: body.city || null,
      country: body.country || null,
      pollution_counts: body.pollution_counts || {},
      status: "pending",
      is_anonymous: true,
      api_source: sourceName,
      api_reference: body.source_reference || null,
    });

    if (reportError) {
      console.error("Report insert error:", reportError);
      return errorResponse(500, "DATABASE_ERROR", "Failed to create report");
    }

    console.log(`Created report: ${reportId}`);

    // 4. Process and upload images
    const imageUrls: string[] = [];
    const imageErrors: string[] = [];

    for (let i = 0; i < Math.min(body.images.length, MAX_IMAGES_PER_REQUEST); i++) {
      const img = body.images[i];
      const isPrimary = img.is_primary ?? i === 0; // First image is primary by default

      try {
        const imageUrl = await processAndUploadImage(
          supabase,
          img.data,
          reportId,
          sourceName,
          i
        );
        imageUrls.push(imageUrl);

        // Create image record in database
        const { error: imgRecordError } = await supabase
          .from("report_images")
          .insert({
            report_id: reportId,
            storage_path: imageUrl,
            is_primary: isPrimary,
          });

        if (imgRecordError) {
          console.error(`Image record error for image ${i}:`, imgRecordError);
        }
      } catch (imgError) {
        console.error(`Image ${i} processing error:`, imgError);
        imageErrors.push(`Image ${i + 1}: ${(imgError as Error).message}`);
        // Continue processing other images
      }
    }

    // Check if at least one image was uploaded
    if (imageUrls.length === 0) {
      // Rollback: delete the report since no images were uploaded
      await supabase.from("reports").delete().eq("id", reportId);
      return errorResponse(
        400,
        "IMAGE_UPLOAD_FAILED",
        "Failed to upload any images. " + imageErrors.join("; ")
      );
    }

    // 5. Return success response
    const response = {
      success: true,
      data: {
        report_id: reportId,
        status: "pending",
        image_count: imageUrls.length,
        image_urls: imageUrls,
        created_at: new Date().toISOString(),
      },
    };

    // Include warnings if some images failed
    if (imageErrors.length > 0) {
      (response as any).warnings = imageErrors;
    }

    console.log(`Report ${reportId} created successfully with ${imageUrls.length} images`);

    return new Response(JSON.stringify(response), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 201,
    });
  } catch (error) {
    console.error("Unhandled error:", error);
    return errorResponse(
      500,
      "INTERNAL_ERROR",
      "An unexpected error occurred"
    );
  }
});

/**
 * Validate the request body
 */
function validateRequest(body: ReportRequest): ValidationResult {
  // Check latitude
  if (body.latitude === undefined || body.latitude === null) {
    return { valid: false, message: "latitude is required", field: "latitude" };
  }
  if (typeof body.latitude !== "number" || isNaN(body.latitude)) {
    return { valid: false, message: "latitude must be a number", field: "latitude" };
  }
  if (body.latitude < -90 || body.latitude > 90) {
    return {
      valid: false,
      message: "latitude must be between -90 and 90",
      field: "latitude",
    };
  }

  // Check longitude
  if (body.longitude === undefined || body.longitude === null) {
    return { valid: false, message: "longitude is required", field: "longitude" };
  }
  if (typeof body.longitude !== "number" || isNaN(body.longitude)) {
    return { valid: false, message: "longitude must be a number", field: "longitude" };
  }
  if (body.longitude < -180 || body.longitude > 180) {
    return {
      valid: false,
      message: "longitude must be between -180 and 180",
      field: "longitude",
    };
  }

  // Check pollution_type
  if (!body.pollution_type) {
    return {
      valid: false,
      message: "pollution_type is required",
      field: "pollution_type",
    };
  }
  if (!VALID_POLLUTION_TYPES.includes(body.pollution_type)) {
    return {
      valid: false,
      message: `pollution_type must be one of: ${VALID_POLLUTION_TYPES.join(", ")}`,
      field: "pollution_type",
    };
  }

  // Check severity
  if (body.severity === undefined || body.severity === null) {
    return { valid: false, message: "severity is required", field: "severity" };
  }
  if (!Number.isInteger(body.severity) || body.severity < 1 || body.severity > 5) {
    return {
      valid: false,
      message: "severity must be an integer between 1 and 5",
      field: "severity",
    };
  }

  // Check images
  if (!body.images || !Array.isArray(body.images) || body.images.length === 0) {
    return {
      valid: false,
      message: "at least one image is required",
      field: "images",
    };
  }
  if (body.images.length > MAX_IMAGES_PER_REQUEST) {
    return {
      valid: false,
      message: `maximum ${MAX_IMAGES_PER_REQUEST} images allowed per request`,
      field: "images",
    };
  }

  // Validate each image has data
  for (let i = 0; i < body.images.length; i++) {
    if (!body.images[i].data || typeof body.images[i].data !== "string") {
      return {
        valid: false,
        message: `images[${i}].data is required and must be a base64 string`,
        field: `images[${i}].data`,
      };
    }
  }

  // Validate pollution_counts if provided
  if (body.pollution_counts) {
    if (typeof body.pollution_counts !== "object") {
      return {
        valid: false,
        message: "pollution_counts must be an object",
        field: "pollution_counts",
      };
    }
    for (const [key, value] of Object.entries(body.pollution_counts)) {
      if (!VALID_POLLUTION_TYPES.includes(key)) {
        return {
          valid: false,
          message: `pollution_counts key "${key}" is not a valid pollution type`,
          field: "pollution_counts",
        };
      }
      if (!Number.isInteger(value) || value < 0) {
        return {
          valid: false,
          message: `pollution_counts["${key}"] must be a non-negative integer`,
          field: "pollution_counts",
        };
      }
    }
  }

  return { valid: true };
}

/**
 * Process and upload a single image
 */
async function processAndUploadImage(
  supabase: ReturnType<typeof createClient>,
  base64Data: string,
  reportId: string,
  sourceName: string,
  imageIndex: number
): Promise<string> {
  // Remove data URL prefix if present (e.g., "data:image/jpeg;base64,")
  const base64Clean = base64Data.replace(/^data:image\/\w+;base64,/, "");

  // Decode base64 to bytes
  let imageBytes: Uint8Array;
  try {
    const binaryString = atob(base64Clean);
    imageBytes = new Uint8Array(binaryString.length);
    for (let i = 0; i < binaryString.length; i++) {
      imageBytes[i] = binaryString.charCodeAt(i);
    }
  } catch {
    throw new Error("Invalid base64 encoding");
  }

  // Check file size
  if (imageBytes.length > MAX_IMAGE_SIZE_BYTES) {
    throw new Error(
      `Image exceeds maximum size of ${MAX_IMAGE_SIZE_BYTES / 1024 / 1024}MB`
    );
  }

  // Detect image type from magic bytes
  const mimeType = detectImageType(imageBytes);
  if (!mimeType) {
    throw new Error("Unsupported image format. Use JPEG, PNG, or WebP.");
  }

  // Generate unique filename
  const timestamp = new Date().toISOString().replace(/[:.]/g, "-");
  const extension = mimeType.split("/")[1];
  const fileName = `${timestamp}_${imageIndex}.${extension}`;

  // Sanitize source name for path (remove special characters)
  const safeSourceName = sourceName.replace(/[^a-zA-Z0-9_-]/g, "_");

  // Storage path: api/{sourceName}/{reportId}/{filename}
  const path = `api/${safeSourceName}/${reportId}/${fileName}`;

  // Upload to storage
  const { error: uploadError } = await supabase.storage
    .from("report-images")
    .upload(path, imageBytes, {
      contentType: mimeType,
      upsert: false,
    });

  if (uploadError) {
    console.error("Storage upload error:", uploadError);
    throw new Error("Failed to upload image to storage");
  }

  // Get public URL
  const {
    data: { publicUrl },
  } = supabase.storage.from("report-images").getPublicUrl(path);

  return publicUrl;
}

/**
 * Detect image type from magic bytes
 */
function detectImageType(bytes: Uint8Array): string | null {
  // JPEG: starts with FF D8 FF
  if (bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff) {
    return "image/jpeg";
  }
  // PNG: starts with 89 50 4E 47
  if (
    bytes[0] === 0x89 &&
    bytes[1] === 0x50 &&
    bytes[2] === 0x4e &&
    bytes[3] === 0x47
  ) {
    return "image/png";
  }
  // WebP: starts with RIFF....WEBP
  if (
    bytes[0] === 0x52 &&
    bytes[1] === 0x49 &&
    bytes[2] === 0x46 &&
    bytes[3] === 0x46 &&
    bytes[8] === 0x57 &&
    bytes[9] === 0x45 &&
    bytes[10] === 0x42 &&
    bytes[11] === 0x50
  ) {
    return "image/webp";
  }
  return null;
}

/**
 * Create error response
 */
function errorResponse(
  status: number,
  code: string,
  message: string,
  field?: string
): Response {
  const body: Record<string, unknown> = {
    success: false,
    error: {
      code,
      message,
    },
  };

  if (field) {
    (body.error as Record<string, unknown>).field = field;
  }

  return new Response(JSON.stringify(body), {
    headers: { ...corsHeaders, "Content-Type": "application/json" },
    status,
  });
}
