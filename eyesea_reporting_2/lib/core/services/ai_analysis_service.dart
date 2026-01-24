import 'dart:io';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';
import '../../domain/entities/ai_analysis_result.dart';
import '../config/yolo_config.dart';
import '../utils/logger.dart';

/// Service for on-device AI analysis of images using Ultralytics YOLO.
///
/// Uses YOLOv11 for object detection with categorization into pollution items,
/// people (for privacy protection), and ignored classes (indoor objects).
///
/// ## Privacy Protection
///
/// **People detection blocks submission** - When `peopleDetected > 0` in the
/// analysis result, the UI should prevent report submission. This is an
/// intentional privacy feature to ensure users don't submit photos containing
/// identifiable individuals.
///
/// When updating the YOLO model, verify that person detection accuracy is
/// maintained to prevent privacy regressions.
///
/// ## Memory Management
///
/// **Current behavior:** Model is loaded on first `analyzeImage()` call and
/// remains in memory (~50MB RAM on iOS/Android) until `dispose()` is called.
///
/// **Future enhancement:** For memory-constrained devices, consider:
/// - Explicit `loadModel()`/`unloadModel()` methods
/// - Automatic unload when app is backgrounded
/// - Lazy re-loading when analysis is requested
///
/// ## Configuration
///
/// Class mappings are centralized in [YoloConfig] for maintainability.
/// These must stay in sync with [PollutionCalculations.objectToPollutionType].
class AIAnalysisService {

  YOLO? _yolo;
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _yolo = YOLO(
        modelPath: YoloConfig.modelName,
        task: YOLOTask.detect,
      );
      await _yolo!.loadModel();
      _isInitialized = true;
      AppLogger.info(' YOLO AI Analysis Service initialized successfully');
    } catch (e) {
      AppLogger.warning(' YOLO initialization failed: $e');
    }
  }

  Future<AIAnalysisResult?> analyzeImage(String imagePath) async {
    if (!_isInitialized) {
      await initialize();
      if (!_isInitialized) {
        AppLogger.warning(' AI Analysis skipped: YOLO not initialized');
        return null;
      }
    }

    try {
      final imageFile = File(imagePath);
      if (!imageFile.existsSync()) {
        AppLogger.error(' Image file not found: $imagePath');
        return null;
      }

      final imageBytes = await imageFile.readAsBytes();
      final results = await _yolo!.predict(imageBytes);
      final boxes = results['boxes'] as List<dynamic>? ?? [];

      if (boxes.isEmpty) {
        AppLogger.info(' YOLO Analysis: No objects detected');
        return const AIAnalysisResult(
          pollutionCounts: {},
          confidence: 0,
        );
      }

      // Group detections by category
      final pollutionCounts = <String, int>{};
      final otherCounts = <String, int>{};
      int peopleCount = 0;
      double totalConfidence = 0;
      int filteredCount = 0;

      for (final box in boxes) {
        final confidence = (box['confidence'] as num?)?.toDouble() ?? 0;
        final className = (box['class'] as String?)?.toLowerCase() ?? 'unknown';

        AppLogger.debug(' Raw Detection: $className ($confidence)');

        if (confidence >= YoloConfig.confidenceThreshold) {
          filteredCount++;
          totalConfidence += confidence;

          if (className == 'person') {
            peopleCount++;
            AppLogger.debug(
                'Person detected: ${(confidence * 100).toStringAsFixed(1)}%');
          } else if (YoloConfig.pollutionClasses.contains(className)) {
            pollutionCounts[className] = (pollutionCounts[className] ?? 0) + 1;
            AppLogger.debug(
                'Pollution $className: ${(confidence * 100).toStringAsFixed(1)}%');
          } else if (!YoloConfig.ignoreClasses.contains(className)) {
            otherCounts[className] = (otherCounts[className] ?? 0) + 1;
            AppLogger.debug(
                'Other $className: ${(confidence * 100).toStringAsFixed(1)}%');
          }
        }
      }

      // Determine scene context
      final sceneLabels = <String>[];
      if (pollutionCounts.containsKey('surfboard') ||
          otherCounts.containsKey('boat')) {
        sceneLabels.add('Beach');
      } else {
        sceneLabels.add('Outdoor');
      }

      // Generate user warning if needed
      String? userWarning;
      final totalPollution = pollutionCounts.values.fold(0, (a, b) => a + b);
      final totalOther = otherCounts.values.fold(0, (a, b) => a + b);
      final totalDetections = totalPollution + peopleCount + totalOther;

      if (totalDetections > 0 && peopleCount > totalDetections * 0.5) {
        userWarning =
            'Many people detected. For better results, retake focusing on the pollution.';
      } else if (totalPollution == 0 && totalDetections > 0) {
        userWarning =
            'No pollution items detected. Try capturing the debris more closely.';
      }

      final detectedTypes = _mapAllPollutionTypes(pollutionCounts);

      final analysisResult = AIAnalysisResult(
        pollutionCounts: pollutionCounts,
        peopleCount: peopleCount,
        otherCounts: otherCounts,
        sceneLabels: sceneLabels,
        likelyPollutionType: _mapToPollutionType(pollutionCounts),
        detectedPollutionTypes: detectedTypes,
        confidence: filteredCount > 0 ? totalConfidence / filteredCount : 0,
        userWarning: userWarning,
      );

      AppLogger.info('YOLO Analysis Summary: Pollution=$totalPollution, People=$peopleCount, Types=$detectedTypes');
      if (userWarning != null) {
        AppLogger.warning('AI Warning: $userWarning');
      }

      return analysisResult;
    } catch (e) {
      AppLogger.error(' Error during YOLO analysis: $e');
      return null;
    }
  }

  String? _mapToPollutionType(Map<String, int> pollutionCounts) {
    final typeCounts = _mapAllPollutionTypes(pollutionCounts);

    // Return the most common type
    if (typeCounts.isEmpty) return null;

    final sortedTypes = typeCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedTypes.first.key;
  }

  /// Maps detected objects to all applicable pollution types with counts.
  /// Uses mappings from [YoloConfig.objectToType].
  Map<String, int> _mapAllPollutionTypes(Map<String, int> pollutionCounts) {
    final Map<String, int> typeCounts = {};

    for (final entry in pollutionCounts.entries) {
      final objectName = entry.key;
      final count = entry.value;
      final pollutionType = YoloConfig.objectToType[objectName];

      if (pollutionType != null) {
        typeCounts[pollutionType] = (typeCounts[pollutionType] ?? 0) + count;
      } else {
        // Default to 'debris' for unclassified pollution items
        typeCounts['debris'] = (typeCounts['debris'] ?? 0) + count;
      }
    }

    return typeCounts;
  }

  void dispose() {
    _yolo?.dispose();
  }
}
