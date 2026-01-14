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

  /// Create bounds with buffer applied
  ViewportBounds withBuffer(double bufferPercent) {
    final latBuffer = latRange * bufferPercent;
    final lngBuffer = lngRange * bufferPercent;
    return ViewportBounds(
      minLat: minLat - latBuffer,
      maxLat: maxLat + latBuffer,
      minLng: minLng - lngBuffer,
      maxLng: maxLng + lngBuffer,
    );
  }

  @override
  String toString() =>
      'ViewportBounds(minLat: $minLat, maxLat: $maxLat, minLng: $minLng, maxLng: $maxLng)';
}
