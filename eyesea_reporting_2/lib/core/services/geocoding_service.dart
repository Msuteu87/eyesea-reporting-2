import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../secrets.dart';
import '../utils/logger.dart';

/// Service for geocoding locations using Mapbox Geocoding API.
/// Supports cached geocoding via Supabase Edge Function for better performance.
class GeocodingService {
  static const String _baseUrl =
      'https://api.mapbox.com/geocoding/v5/mapbox.places';

  /// Whether to prefer the Edge Function for reverse geocoding (cached).
  /// Falls back to direct Mapbox API if Edge Function fails or is offline.
  static bool preferCachedGeocode = true;

  /// Search for places matching the query.
  /// Returns a list of [GeocodingResult] with place names and coordinates.
  ///
  /// [types] can be used to filter results: 'country', 'region', 'place', 'locality', 'address'
  /// Default searches for countries, regions, places (cities), and localities.
  static Future<List<GeocodingResult>> search(
    String query, {
    int limit = 5,
    List<String> types = const ['country', 'region', 'place', 'locality'],
  }) async {
    if (query.trim().isEmpty) {
      return [];
    }

    try {
      final encodedQuery = Uri.encodeComponent(query);
      final typesParam = types.join(',');
      final url = Uri.parse(
        '$_baseUrl/$encodedQuery.json'
        '?access_token=${Secrets.mapboxAccessToken}'
        '&types=$typesParam'
        '&limit=$limit'
        '&language=en',
      );

      final response = await http.get(url);

      if (response.statusCode != 200) {
        AppLogger.error('[Geocoding] Error: ${response.statusCode} ${response.body}');
        return [];
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final features = data['features'] as List<dynamic>? ?? [];

      return features.map((feature) {
        final properties = feature as Map<String, dynamic>;
        final geometry = properties['geometry'] as Map<String, dynamic>;
        final coordinates = geometry['coordinates'] as List<dynamic>;

        // Extract context for secondary text (e.g., "California, United States")
        final contextList = properties['context'] as List<dynamic>? ?? [];
        final contextParts = contextList
            .map((c) => (c as Map<String, dynamic>)['text'] as String?)
            .where((t) => t != null)
            .take(2)
            .toList();
        final contextText =
            contextParts.isNotEmpty ? contextParts.join(', ') : null;

        return GeocodingResult(
          placeName: properties['text'] as String? ?? properties['place_name'] as String? ?? '',
          fullPlaceName: properties['place_name'] as String? ?? '',
          context: contextText,
          longitude: (coordinates[0] as num).toDouble(),
          latitude: (coordinates[1] as num).toDouble(),
          placeType: (properties['place_type'] as List<dynamic>?)?.first as String?,
        );
      }).toList();
    } catch (e) {
      AppLogger.error('[Geocoding] Exception', e);
      return [];
    }
  }

  /// Reverse geocode coordinates to get place name.
  /// Uses Edge Function with caching if [preferCachedGeocode] is true.
  /// Falls back to direct Mapbox API if Edge Function fails.
  static Future<GeocodingResult?> reverseGeocode(
    double latitude,
    double longitude,
  ) async {
    // Try cached geocoding first (via Edge Function)
    if (preferCachedGeocode) {
      final cached = await _reverseGeocodeCached(latitude, longitude);
      if (cached != null) return cached;
      AppLogger.info('[Geocoding] Edge Function unavailable, using direct API');
    }

    // Fallback to direct Mapbox API
    return _reverseGeocodeDirectMapbox(latitude, longitude);
  }

  /// Reverse geocode using Supabase Edge Function (with caching).
  /// Returns null if Edge Function is unavailable.
  static Future<GeocodingResult?> _reverseGeocodeCached(
    double latitude,
    double longitude,
  ) async {
    try {
      final supabase = Supabase.instance.client;

      final response = await supabase.functions.invoke(
        'geocode',
        body: {
          'lat': latitude,
          'lng': longitude,
          'precision': 4, // ~11m accuracy for cache key
        },
      );

      if (response.status != 200) {
        AppLogger.warning('[Geocoding] Edge Function error: ${response.status}');
        return null;
      }

      final data = response.data as Map<String, dynamic>;
      final cached = data['cached'] as bool? ?? false;

      AppLogger.debug('[Geocoding] ${cached ? "Cache HIT" : "Cache MISS"}');

      return GeocodingResult(
        placeName: data['placeName'] as String? ?? '',
        fullPlaceName: data['placeName'] as String? ?? '',
        city: data['city'] as String?,
        country: data['country'] as String?,
        latitude: latitude,
        longitude: longitude,
      );
    } catch (e) {
      AppLogger.warning('[Geocoding] Edge Function exception: $e');
      return null;
    }
  }

  /// Reverse geocode directly via Mapbox API (no caching).
  static Future<GeocodingResult?> _reverseGeocodeDirectMapbox(
    double latitude,
    double longitude,
  ) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/$longitude,$latitude.json'
        '?access_token=${Secrets.mapboxAccessToken}'
        '&types=place,locality,region,country'
        '&limit=1'
        '&language=en',
      );

      final response = await http.get(url);

      if (response.statusCode != 200) {
        AppLogger.error('[Geocoding] Reverse error: ${response.statusCode}');
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final features = data['features'] as List<dynamic>? ?? [];

      if (features.isEmpty) return null;

      final feature = features.first as Map<String, dynamic>;
      final geometry = feature['geometry'] as Map<String, dynamic>;
      final coordinates = geometry['coordinates'] as List<dynamic>;

      // Extract city and country from context
      String? city;
      String? country;
      final context = feature['context'] as List<dynamic>? ?? [];
      for (final ctx in context) {
        final ctxMap = ctx as Map<String, dynamic>;
        final id = ctxMap['id'] as String? ?? '';
        if (id.startsWith('place.') || id.startsWith('locality.')) {
          city ??= ctxMap['text'] as String?;
        } else if (id.startsWith('country.')) {
          country = ctxMap['text'] as String?;
        }
      }

      // If feature itself is a place, use it as city
      final placeType = (feature['place_type'] as List<dynamic>?)?.first as String?;
      if ((placeType == 'place' || placeType == 'locality') && city == null) {
        city = feature['text'] as String?;
      }

      return GeocodingResult(
        placeName: feature['text'] as String? ?? '',
        fullPlaceName: feature['place_name'] as String? ?? '',
        city: city,
        country: country,
        longitude: (coordinates[0] as num).toDouble(),
        latitude: (coordinates[1] as num).toDouble(),
      );
    } catch (e) {
      AppLogger.error('[Geocoding] Reverse exception', e);
      return null;
    }
  }
}

/// Result from geocoding search.
class GeocodingResult {
  final String placeName;
  final String fullPlaceName;
  final String? context;
  final double latitude;
  final double longitude;
  final String? placeType;
  final String? city;
  final String? country;

  const GeocodingResult({
    required this.placeName,
    required this.fullPlaceName,
    this.context,
    required this.latitude,
    required this.longitude,
    this.placeType,
    this.city,
    this.country,
  });
}
