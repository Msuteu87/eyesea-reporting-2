class EventEntity {
  final String id;
  final String organizerId;
  final String title;
  final String description;
  final String? location; // Text address for now
  final double? lat;
  final double? lon;
  final DateTime startTime;
  final DateTime endTime;
  final String status; // 'planned', 'ongoing', 'completed', 'cancelled'

  const EventEntity({
    required this.id,
    required this.organizerId,
    required this.title,
    required this.description,
    this.location,
    this.lat,
    this.lon,
    required this.startTime,
    required this.endTime,
    this.status = 'planned',
  });
}
