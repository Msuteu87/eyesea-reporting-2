/// Represents geographic viewport bounds for map operations.
///
/// Used for tracking visible area, caching decisions, and marker loading.
class ViewportBounds {
  final double minLat;
  final double maxLat;
  final double minLng;
  final double maxLng;

  const ViewportBounds({
    required this.minLat,
    required this.maxLat,
    required this.minLng,
    required this.maxLng,
  });

  /// Latitude range (height) of the viewport
  double get latRange => maxLat - minLat;

  /// Longitude range (width) of the viewport
  double get lngRange => maxLng - minLng;

  /// Convert to Map for storage/comparison
  Map<String, double> toMap() => {
        'minLat': minLat,
        'maxLat': maxLat,
        'minLng': minLng,
        'maxLng': maxLng,
      };

  /// Create from Map
  factory ViewportBounds.fromMap(Map<String, double> map) => ViewportBounds(
        minLat: map['minLat']!,
        maxLat: map['maxLat']!,
        minLng: map['minLng']!,
        maxLng: map['maxLng']!,
      );

  /// Create bounds with buffer applied.
  /// Results are clamped to valid geographic coordinates:
  /// - Latitude: -90 to 90
  /// - Longitude: -180 to 180
  ViewportBounds withBuffer(double bufferPercent) {
    final latBuffer = latRange * bufferPercent;
    final lngBuffer = lngRange * bufferPercent;
    return ViewportBounds(
      minLat: (minLat - latBuffer).clamp(-90.0, 90.0),
      maxLat: (maxLat + latBuffer).clamp(-90.0, 90.0),
      minLng: (minLng - lngBuffer).clamp(-180.0, 180.0),
      maxLng: (maxLng + lngBuffer).clamp(-180.0, 180.0),
    );
  }

  @override
  String toString() =>
      'ViewportBounds(minLat: $minLat, maxLat: $maxLat, minLng: $minLng, maxLng: $maxLng)';
}
