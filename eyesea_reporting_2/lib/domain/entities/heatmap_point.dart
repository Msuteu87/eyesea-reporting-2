/// Lightweight entity for global heatmap visualization
class HeatmapPoint {
  final String id;
  final double latitude;
  final double longitude;
  final double weight; // 0.0 to 1.0

  const HeatmapPoint({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.weight,
  });

  factory HeatmapPoint.fromJson(Map<String, dynamic> json) {
    return HeatmapPoint(
      id: json['id'] as String,
      latitude: (json['lat'] as num).toDouble(),
      longitude: (json['lng'] as num).toDouble(),
      weight: (json['weight'] as num).toDouble(),
    );
  }
}
