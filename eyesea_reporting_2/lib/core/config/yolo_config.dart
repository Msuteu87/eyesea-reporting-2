/// Centralized configuration for YOLO AI object detection.
///
/// This file contains class mappings and thresholds used by [AIAnalysisService]
/// for pollution detection and categorization.
///
/// ## Updating Mappings
///
/// When the YOLO model is updated or new classes are added:
/// 1. Update [pollutionClasses] with new detectable items
/// 2. Update [objectToType] to map new classes to pollution types
/// 3. Ensure consistency with [PollutionCalculations.objectToPollutionType]
///
/// Future enhancement: Load mappings from JSON config or remote config
/// to enable updates without app releases.
class YoloConfig {
  YoloConfig._();

  // ---------------------------------------------------------------------------
  // Detection Thresholds
  // ---------------------------------------------------------------------------

  /// Minimum confidence threshold for accepting detections.
  /// Lower values catch more items but may increase false positives.
  static const double confidenceThreshold = 0.15;

  /// Model name for YOLO initialization.
  /// iOS uses CoreML (.mlpackage), Android uses TFLite.
  static const String modelName = 'yolo11n';

  // ---------------------------------------------------------------------------
  // COCO Class Mappings
  // ---------------------------------------------------------------------------

  /// COCO classes that are considered pollution items.
  /// These are grouped by category for maintainability.
  static const Set<String> pollutionClasses = {
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

  /// COCO classes that should be ignored (not pollution).
  /// Includes indoor objects and wildlife.
  static const Set<String> ignoreClasses = {
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

  /// Maps detected COCO classes to pollution type strings.
  /// Used by [AIAnalysisService._mapAllPollutionTypes].
  ///
  /// Must stay in sync with [PollutionCalculations.objectToPollutionType].
  static const Map<String, String> objectToType = {
    // Plastic items (bottles, cups - genuine plastic)
    'bottle': 'plastic',
    'cup': 'plastic',
    'toothbrush': 'plastic',

    // Debris/General waste (glass, ceramic, sports equipment, food, e-waste)
    'bowl': 'debris',
    'vase': 'debris',
    'wine glass': 'debris',
    'handbag': 'debris',
    'backpack': 'debris',
    'suitcase': 'debris',
    'umbrella': 'debris',

    // Sports equipment (common beach/outdoor litter)
    'sports ball': 'debris',
    'frisbee': 'debris',
    'kite': 'debris',
    'surfboard': 'debris',
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
    'cell phone': 'debris',
    'remote': 'debris',
    'book': 'debris',
    'tie': 'debris',
    'hair drier': 'debris',

    // Cutlery (common outdoor litter)
    'fork': 'plastic',
    'knife': 'plastic',
    'spoon': 'plastic',

    // Other common litter
    'scissors': 'debris',
    'teddy bear': 'debris',

    // Vehicles (dumped/abandoned)
    'bicycle': 'debris',
    'car': 'debris',
    'motorcycle': 'debris',

    // Furniture
    'bench': 'debris',

    // Marine equipment
    'boat': 'fishingGear',
  };
}
