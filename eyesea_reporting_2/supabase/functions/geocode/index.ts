import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

interface GeocodingRequest {
  lat: number;
  lng: number;
  precision?: number; // Decimal places for cache key (default: 4 = ~11m accuracy)
}

interface GeocodingResponse {
  placeName: string;
  city: string | null;
  country: string | null;
  cached: boolean;
}

/**
 * Geocoding Edge Function with caching
 *
 * - Checks location_cache table first
 * - Falls back to Mapbox API if not cached
 * - Caches results for 30 days
 * - Reduces Mapbox API calls by ~80%
 */
serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { lat, lng, precision = 4 }: GeocodingRequest = await req.json();

    if (lat === undefined || lng === undefined) {
      throw new Error('Missing lat or lng parameters');
    }

    // Round coordinates for cache key
    const roundedLat = parseFloat(lat.toFixed(precision));
    const roundedLng = parseFloat(lng.toFixed(precision));

    console.log(`Geocoding: ${roundedLat}, ${roundedLng} (precision: ${precision})`);

    // Initialize Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
    const supabase = createClient(supabaseUrl, supabaseKey);

    // 1. Check cache first
    const { data: cached, error: cacheError } = await supabase
      .from('location_cache')
      .select('place_name, city, country')
      .eq('lat', roundedLat)
      .eq('lng', roundedLng)
      .eq('precision', precision)
      .gt('expires_at', new Date().toISOString())
      .single();

    if (cached && !cacheError) {
      console.log('Cache HIT');
      return new Response(
        JSON.stringify({
          placeName: cached.place_name,
          city: cached.city,
          country: cached.country,
          cached: true,
        } as GeocodingResponse),
        {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 200,
        }
      );
    }

    console.log('Cache MISS - calling Mapbox API');

    // 2. Get Mapbox access token
    const mapboxToken = Deno.env.get('MAPBOX_ACCESS_TOKEN');
    if (!mapboxToken) {
      throw new Error('MAPBOX_ACCESS_TOKEN not configured');
    }

    // 3. Call Mapbox Geocoding API
    const mapboxUrl = `https://api.mapbox.com/geocoding/v5/mapbox.places/${lng},${lat}.json` +
      `?access_token=${mapboxToken}` +
      `&types=place,locality,region,country` +
      `&limit=1` +
      `&language=en`;

    const mapboxResponse = await fetch(mapboxUrl);

    if (!mapboxResponse.ok) {
      throw new Error(`Mapbox API error: ${mapboxResponse.status}`);
    }

    const mapboxData = await mapboxResponse.json();
    const features = mapboxData.features ?? [];

    let placeName = '';
    let city: string | null = null;
    let country: string | null = null;

    if (features.length > 0) {
      const feature = features[0];
      placeName = feature.place_name ?? '';

      // Extract city and country from context
      const context = feature.context ?? [];
      for (const ctx of context) {
        const id = ctx.id ?? '';
        if (id.startsWith('place.') || id.startsWith('locality.')) {
          city = city ?? ctx.text;
        } else if (id.startsWith('country.')) {
          country = ctx.text;
        }
      }

      // If feature itself is a place, use it as city
      const placeType = feature.place_type?.[0] ?? '';
      if ((placeType === 'place' || placeType === 'locality') && !city) {
        city = feature.text;
      }
    }

    // 4. Cache the result
    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + 30); // 30 days

    const { error: insertError } = await supabase
      .from('location_cache')
      .upsert({
        lat: roundedLat,
        lng: roundedLng,
        precision: precision,
        place_name: placeName,
        city: city,
        country: country,
        full_response: mapboxData,
        expires_at: expiresAt.toISOString(),
      }, {
        onConflict: 'lat,lng,precision',
      });

    if (insertError) {
      console.warn('Failed to cache geocoding result:', insertError);
      // Continue anyway - caching is optional
    } else {
      console.log('Cached geocoding result');
    }

    // 5. Return response
    return new Response(
      JSON.stringify({
        placeName,
        city,
        country,
        cached: false,
      } as GeocodingResponse),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      }
    );

  } catch (error) {
    console.error('Geocoding error:', error);
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      }
    );
  }
});
