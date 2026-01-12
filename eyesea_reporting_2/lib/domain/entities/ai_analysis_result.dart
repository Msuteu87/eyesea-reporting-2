/// Result of AI analysis on an image
class AIAnalysisResult {
  /// Map of detected pollution-related objects to their count
  /// Example: {'bottle': 3, 'cup': 1}
  final Map<String, int> pollutionCounts;

  /// Count of people detected in the image
  final int peopleCount;

  /// Other non-pollution objects detected
  /// Example: {'car': 1, 'dog': 1}
  final Map<String, int> otherCounts;

  /// The most likely high-level pollution type based on detections
  /// Example: 'plastic'
  final String? likelyPollutionType;

  /// All detected pollution types with their item counts
  /// Example: {'plastic': 4, 'fishingGear': 2}
  final Map<String, int> detectedPollutionTypes;

  /// Average confidence of detections
  final double confidence;

  /// Scene/environment labels detected (e.g., 'Beach', 'Water', 'Outdoor')
  final List<String> sceneLabels;

  /// Warning message to show user (e.g., "Too many people in frame")
  final String? userWarning;

  const AIAnalysisResult({
    required this.pollutionCounts,
    this.peopleCount = 0,
    this.otherCounts = const {},
    this.likelyPollutionType,
    this.detectedPollutionTypes = const {},
    required this.confidence,
    this.sceneLabels = const [],
    this.userWarning,
  });

  /// Total pollution items detected
  int get totalPollutionCount =>
      pollutionCounts.values.fold(0, (a, b) => a + b);

  /// Check if image is dominated by people (>50% of detections)
  bool get hasTooManyPeople {
    final totalDetections = totalPollutionCount +
        peopleCount +
        otherCounts.values.fold(0, (a, b) => a + b);
    if (totalDetections == 0) return false;
    return peopleCount > totalDetections * 0.5;
  }

  /// Legacy getter for backward compatibility
  Map<String, int> get objectCounts => pollutionCounts;

  @override
  String toString() =>
      'AIAnalysisResult(pollution: $pollutionCounts, people: $peopleCount, likely: $likelyPollutionType)';
}
