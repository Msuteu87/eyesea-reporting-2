import 'dart:io';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';
import '../../domain/entities/ai_analysis_result.dart';
import '../utils/logger.dart';

// TODO: [PRIVACY] Document people detection blocking behavior
// When peopleDetected > 0, submission is blocked to protect privacy
// This is intentional - users should not submit photos with people visible
// Ensure YOLO model updates don't regress this detection capability

// TODO: [PERFORMANCE] Consider lazy model loading
// Current: Model loaded on first analyze() call and kept in memory
// Fix: Add explicit loadModel()/unloadModel() for memory management
// Could unload when app is backgrounded to free ~50MB RAM

// TODO: [MAINTAINABILITY] Move class mappings to config file
// Current: _pollutionClasses, _ignoreClasses hardcoded here
// Fix: Load from JSON config to allow updates without app release

/// Service for on-device AI analysis of images using Ultralytics YOLO.
/// Uses YOLOv8/v11 for object detection with grouping (pollution vs people).
class AIAnalysisService {
  // Lowered from 0.25 to catch more detections (reduce false negatives)
  static const double _confidenceThreshold = 0.15;
  static const String _modelName = 'yolo11n';

  // COCO classes grouped by category
  static const Set<String> _pollutionClasses = {
    // Containers & packaging
    'bottle',
    'cup',
    'bowl',
    'vase',
    'wine glass',
    'handbag',
    'backpack',
    'suitcase',
    'umbrella',

    // Sports equipment (common beach litter)
    'sports ball',
    'frisbee',
    'kite',
    'surfboard',
    'skateboard',
    'tennis racket',
    'baseball bat',
    'baseball glove',

    // Food waste
    'banana',
    'apple',
    'orange',
    'sandwich',
    'hot dog',
    'pizza',
    'donut',
    'cake',
    'broccoli',
    'carrot',

    // Small items & e-waste
    'toothbrush',
    'book',
    'cell phone',
    'remote',
    'tie',
    'hair drier',

    // Cutlery (common outdoor litter)
    'fork',
    'knife',
    'spoon',

    // Other common litter
    'scissors',
    'teddy bear',

    // Vehicles (dumped/abandoned)
    'bicycle',
    'car',
    'motorcycle',

    // Furniture
    'bench',

    // Marine equipment
    'boat',
  };

  static const Set<String> _ignoreClasses = {
    'person',
    'clock',
    'tv',
    'laptop',
    'mouse',
    'keyboard',
    'oven',
    'microwave',
    'refrigerator',
    'sink',
    'toilet',
    'bed',
    'couch',
    'chair',
    'dining table',
    'potted plant',
    // Wildlife indicators (not pollution)
    'bird',
    'cat',
    'dog',
  };

  YOLO? _yolo;
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _yolo = YOLO(
        modelPath: _modelName,
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

        if (confidence >= _confidenceThreshold) {
          filteredCount++;
          totalConfidence += confidence;

          if (className == 'person') {
            peopleCount++;
            AppLogger.debug(
                'Person detected: ${(confidence * 100).toStringAsFixed(1)}%');
          } else if (_pollutionClasses.contains(className)) {
            pollutionCounts[className] = (pollutionCounts[className] ?? 0) + 1;
            AppLogger.debug(
                'Pollution $className: ${(confidence * 100).toStringAsFixed(1)}%');
          } else if (!_ignoreClasses.contains(className)) {
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

  /// Maps detected objects to all applicable pollution types with counts
  Map<String, int> _mapAllPollutionTypes(Map<String, int> pollutionCounts) {
    // Define mapping from detected objects to pollution types
    final Map<String, String> objectToType = {
      // Plastic items (bottles, cups - genuine plastic)
      'bottle': 'plastic',
      'cup': 'plastic',
      'toothbrush': 'plastic', // Fixed: Small plastic item

      // Debris/General waste (glass, ceramic, sports equipment, food, e-waste)
      'bowl': 'debris', // Fixed: Can be ceramic/metal/glass
      'vase': 'debris', // Fixed: Usually ceramic/glass
      'wine glass': 'debris', // Fixed: Glass, not plastic
      'handbag': 'debris',
      'backpack': 'debris',
      'suitcase': 'debris',
      'umbrella': 'debris',

      // Sports equipment (common beach/outdoor litter)
      'sports ball': 'debris',
      'frisbee': 'debris',
      'kite': 'debris', // Fixed: Sports equipment, not fishing gear
      'surfboard': 'debris', // Fixed: Abandoned sports equipment
      'skateboard': 'debris',
      'tennis racket': 'debris',
      'baseball bat': 'debris',
      'baseball glove': 'debris',

      // Food waste
      'banana': 'debris',
      'apple': 'debris',
      'orange': 'debris',
      'sandwich': 'debris',
      'hot dog': 'debris',
      'pizza': 'debris',
      'donut': 'debris',
      'cake': 'debris',
      'broccoli': 'debris',
      'carrot': 'debris',

      // E-waste & small items
      'cell phone': 'debris', // Fixed: E-waste
      'remote': 'debris', // Fixed: E-waste
      'book': 'debris', // Fixed: Paper waste
      'tie': 'debris', // Clothing waste
      'hair drier': 'debris', // E-waste

      // Cutlery (common outdoor litter)
      'fork': 'plastic', // Often plastic cutlery
      'knife': 'plastic', // Often plastic cutlery
      'spoon': 'plastic', // Often plastic cutlery

      // Other common litter
      'scissors': 'debris', // Potentially hazardous
      'teddy bear': 'debris', // Abandoned toys

      // Vehicles (dumped/abandoned)
      'bicycle': 'debris',
      'car': 'debris',
      'motorcycle': 'debris',

      // Furniture
      'bench': 'debris',

      // Marine equipment
      'boat': 'fishingGear', // Abandoned boats / marine debris

      // Containers (larger storage items)
      // Note: Keeping this category for future additions if needed
    };

    final Map<String, int> typeCounts = {};

    for (final entry in pollutionCounts.entries) {
      final objectName = entry.key;
      final count = entry.value;
      final pollutionType = objectToType[objectName];

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
