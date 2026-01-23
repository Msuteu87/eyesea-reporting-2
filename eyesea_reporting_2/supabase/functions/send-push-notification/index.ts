/**
 * Edge Function: send-push-notification
 *
 * Sends push notifications via Firebase Cloud Messaging (FCM) when a notification
 * is inserted into the `notifications` table.
 *
 * ## Setup
 *
 * 1. Get your Firebase Server Key from Firebase Console:
 *    Project Settings > Cloud Messaging > Server key (or use service account JSON)
 *
 * 2. Set the secret in Supabase:
 *    supabase secrets set FCM_SERVER_KEY=your_server_key
 *
 * 3. Create a database trigger to call this function on notification insert
 *
 * ## Trigger SQL
 *
 * See migration: 20260123110000_push_notification_trigger.sql
 */

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

interface NotificationPayload {
  record: {
    id: string;
    user_id: string;
    type: string;
    title: string;
    body?: string;
    data?: Record<string, unknown>;
  };
}

interface FCMMessage {
  to: string;
  notification: {
    title: string;
    body?: string;
  };
  data?: Record<string, string>;
  android?: {
    priority: string;
    notification: {
      channel_id: string;
      click_action: string;
    };
  };
  apns?: {
    payload: {
      aps: {
        badge: number;
        sound: string;
      };
    };
  };
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { record } = (await req.json()) as NotificationPayload;

    if (!record || !record.user_id || !record.title) {
      throw new Error("Invalid notification payload");
    }

    console.log(
      `Sending push for notification: ${record.id} to user: ${record.user_id}`
    );

    // Initialize Supabase client with service role key (to access device_tokens)
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const supabase = createClient(supabaseUrl, supabaseKey);

    // Get FCM server key
    const fcmServerKey = Deno.env.get("FCM_SERVER_KEY");
    if (!fcmServerKey) {
      console.warn("FCM_SERVER_KEY not set - skipping push notification");
      return new Response(
        JSON.stringify({ success: false, reason: "FCM not configured" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Get user's device tokens using the RPC function
    const { data: tokens, error: tokenError } = await supabase.rpc(
      "get_user_push_tokens",
      { p_user_id: record.user_id }
    );

    if (tokenError) {
      throw new Error(`Failed to get tokens: ${tokenError.message}`);
    }

    if (!tokens || tokens.length === 0) {
      console.log("No device tokens found for user");
      return new Response(
        JSON.stringify({ success: true, sent: 0, reason: "No tokens" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    console.log(`Found ${tokens.length} device token(s)`);

    // Prepare notification data (convert to strings for FCM data payload)
    const dataPayload: Record<string, string> = {
      notification_id: record.id,
      type: record.type,
    };

    // Add custom data fields as strings
    if (record.data) {
      for (const [key, value] of Object.entries(record.data)) {
        dataPayload[key] = String(value);
      }
    }

    // Send to each device
    const results = await Promise.allSettled(
      tokens.map(async (tokenRecord: { token: string; platform: string }) => {
        const message: FCMMessage = {
          to: tokenRecord.token,
          notification: {
            title: record.title,
            body: record.body,
          },
          data: dataPayload,
          // Android-specific settings
          android: {
            priority: "high",
            notification: {
              channel_id: "eyesea_notifications",
              click_action: "FLUTTER_NOTIFICATION_CLICK",
            },
          },
          // iOS-specific settings
          apns: {
            payload: {
              aps: {
                badge: 1,
                sound: "default",
              },
            },
          },
        };

        const response = await fetch("https://fcm.googleapis.com/fcm/send", {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `key=${fcmServerKey}`,
          },
          body: JSON.stringify(message),
        });

        const result = await response.json();

        // Check for invalid token (should be removed from database)
        if (result.failure === 1 && result.results?.[0]?.error) {
          const error = result.results[0].error;
          if (
            error === "InvalidRegistration" ||
            error === "NotRegistered"
          ) {
            console.log(`Removing invalid token: ${tokenRecord.token.substring(0, 20)}...`);
            // Remove invalid token from database
            await supabase
              .from("device_tokens")
              .delete()
              .eq("token", tokenRecord.token);
          }
        }

        return {
          token: tokenRecord.token.substring(0, 20) + "...",
          platform: tokenRecord.platform,
          success: result.success === 1,
          error: result.results?.[0]?.error,
        };
      })
    );

    // Count successes
    const successCount = results.filter(
      (r) => r.status === "fulfilled" && (r.value as { success: boolean }).success
    ).length;

    console.log(`Push sent: ${successCount}/${tokens.length} successful`);

    return new Response(
      JSON.stringify({
        success: true,
        sent: successCount,
        total: tokens.length,
        results: results.map((r) =>
          r.status === "fulfilled" ? r.value : { error: r.reason }
        ),
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("Error sending push notification:", error);
    return new Response(
      JSON.stringify({ error: (error as Error).message }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});
