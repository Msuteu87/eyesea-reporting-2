
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { GoogleGenerativeAI } from "https://esm.sh/@google/generative-ai";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { record } = await req.json();
    
    // We expect the trigger to send the whole record from report_images
    // record: { id, report_id, storage_path, ... }
    const reportId = record.report_id;
    const storagePath = record.storage_path;

    if (!reportId || !storagePath) {
      throw new Error('Missing report_id or storage_path');
    }

    console.log(`Analyzing report: ${reportId}, Image: ${storagePath}`);

    // 1. Initialize Supabase Client
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
    const supabase = createClient(supabaseUrl, supabaseKey);

    // 2. Download Image
    const { data: imageData, error: downloadError } = await supabase.storage
      .from('report-images')
      .download(storagePath);

    if (downloadError) throw downloadError;

    // 3. Initialize Gemini
    const geminiKey = Deno.env.get('GEMINI_API_KEY');
    if (!geminiKey) throw new Error('GEMINI_API_KEY not set');

    const genAI = new GoogleGenerativeAI(geminiKey);
    const model = genAI.getGenerativeModel({ model: "gemini-pro-vision" });

    // 4. Prepare Image for Gemini
    // Convert Blob to Uint8Array/Base64 if needed, but SDK handles some formats.
    // For Deno/Edge, we might need to convert arrayBuffer to base64.
    const arrayBuffer = await imageData.arrayBuffer();
    const base64Image = btoa(
      new Uint8Array(arrayBuffer).reduce((data, byte) => data + String.fromCharCode(byte), '')
    );

    const prompt = `
      Analyze this image for ocean/marine pollution. 
      Return a STRICT JSON object (no markdown formatting) with the following fields:
      - pollution_detected: list of strings (e.g. ["plastic", "oil", "fishing_net"]) or [] if clean.
      - severity: integer 1-5 (1=clean, 5=severe).
      - confidence: float 0.0-1.0.
      - description: short summary of the visible pollution.
    `;

    const result = await model.generateContent([
      prompt,
      {
        inlineData: {
          data: base64Image,
          mimeType: "image/jpeg", // Assuming JPEG for now, ideally detect from storagePath
        },
      },
    ]);

    const response = await result.response;
    const text = response.text();
    
    // Clean up markdown code blocks if present
    const cleanJson = text.replace(/```json/g, '').replace(/```/g, '').trim();
    const analysis = JSON.parse(cleanJson);

    console.log('Gemini Analysis:', analysis);

    // 5. Save to Database
    const { error: insertError } = await supabase
      .from('ai_analysis')
      .insert({
        report_id: reportId,
        gemini_response: analysis,
        pollution_detected: analysis.pollution_detected,
        confidence: analysis.confidence,
        description: analysis.description,
      });

    if (insertError) throw insertError;

    return new Response(
      JSON.stringify({ success: true, analysis }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    console.error('Error processing request:', error);
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
