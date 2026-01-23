import '../../domain/entities/report.dart';

// TODO: [DOCUMENTATION] Add player-facing explanation of Credits system
// Current: Credits calculation has base + bonuses but no in-app explanation
// Fix: Create wiki/help screen explaining how EyeSea Credits are earned:
//   - Base: 25 Credits per report
//   - Photo bonus: +5 Credits
//   - Location bonus: +10 Credits
//   - Beach/water bonus: +10 Credits
//   - Severity bonus: 0-20 Credits based on severity level
//   - Multi-type bonus: +5 Credits per additional pollution type
//   - Item count bonus: +1 Credit per 5 items (capped at 50 Credits)

// TODO: [MAINTAINABILITY] Move weight constants to config/database
// Current: _averageWeights hardcoded - can't adjust based on real data
// Fix: Store in Supabase config table, cache locally, allow admin updates

// TODO: [VALIDATION] Handle user-adjusted counts vs AI detection
// Current: If user manually adjusts pollution counts after AI detection,
// fraud score will flag as suspicious (count mismatch)
// Consider: Add UI warning when user deviates significantly from AI counts

/// Fraud detection result
class FraudAnalysis {
  final bool isSuspicious;
  final double fraudScore; // 0.0 = clean, 1.0 = highly suspicious
  final List<String> warnings;
  final Map<PollutionType, int> suggestedCounts; // AI baseline

  const FraudAnalysis({
    required this.isSuspicious,
    required this.fraudScore,
    required this.warnings,
    required this.suggestedCounts,
  });
}

/// Utility class for pollution-related calculations
class PollutionCalculations {
  /// Average weight per item in kilograms
  static const Map<PollutionType, double> _averageWeights = {
    PollutionType.plastic: 0.025, // ~25g per plastic bottle/cup
    PollutionType.oil: 0.5, // Oil spill estimation per unit
    PollutionType.debris: 0.15, // ~150g per debris item
    PollutionType.sewage: 1.0, // Sewage incident estimation
    PollutionType.fishingGear: 2.5, // ~2.5kg per fishing gear item
    PollutionType.container: 0.5, // ~500g per container
    PollutionType.other: 0.1, // Generic weight
  };

  /// Calculate total estimated weight from pollution counts
  static double calculateTotalWeight(Map<PollutionType, int> typeCounts) {
    double totalWeight = 0.0;

    for (final entry in typeCounts.entries) {
      final type = entry.key;
      final count = entry.value;
      final weightPerItem = _averageWeights[type] ?? 0.1;
      totalWeight += weightPerItem * count;
    }

    return totalWeight;
  }

  /// Calculate breakdown of weight by type
  static Map<PollutionType, double> calculateWeightBreakdown(
    Map<PollutionType, int> typeCounts,
  ) {
    final breakdown = <PollutionType, double>{};

    for (final entry in typeCounts.entries) {
      final type = entry.key;
      final count = entry.value;
      final weightPerItem = _averageWeights[type] ?? 0.1;
      breakdown[type] = weightPerItem * count;
    }

    return breakdown;
  }

  /// Calculate XP earned from a report
  /// XP scales dynamically with item count and weight for better gamification
  static int calculateXP({
    required Map<PollutionType, int> typeCounts,
    required int severity,
    required bool hasLocation,
    required bool hasPhoto,
    List<String> sceneLabels = const [],
  }) {
    int totalXP = 0;

    // Base XP for submitting a report
    totalXP += 25;

    // Bonus XP for photo verification
    if (hasPhoto) {
      totalXP += 5;
    }

    // Bonus XP for location data
    if (hasLocation) {
      totalXP += 10;
    }

    // Bonus XP for beach/water locations (environmental priority)
    if (sceneLabels.any((label) =>
        label.toLowerCase().contains('beach') ||
        label.toLowerCase().contains('water') ||
        label.toLowerCase().contains('ocean'))) {
      totalXP += 10;
    }

    // Severity multiplier (higher severity = more XP)
    final severityBonus = (severity - 1) * 5; // 0, 5, 10, 15, 20 XP
    totalXP += severityBonus;

    // Multiple pollution types bonus (thorough reporting)
    if (typeCounts.length > 1) {
      totalXP += (typeCounts.length - 1) * 5;
    }

    // === DYNAMIC SCALING BASED ON ITEMS & WEIGHT ===
    final totalItems = typeCounts.values.fold(0, (sum, count) => sum + count);
    final totalWeight = calculateTotalWeight(typeCounts);

    // Per-item bonus: +1 XP per item (capped at 50 XP to prevent abuse)
    final itemBonus = totalItems.clamp(0, 50);
    totalXP += itemBonus;

    // Weight bonus: +3 XP per kg (capped at 30 XP / 10kg)
    final weightBonus = (totalWeight * 3).round().clamp(0, 30);
    totalXP += weightBonus;

    // Volume tier bonus (on top of per-item)
    if (totalItems >= 20) {
      totalXP += 20; // Major cleanup bonus
    } else if (totalItems >= 10) {
      totalXP += 10; // Significant cleanup bonus
    } else if (totalItems >= 5) {
      totalXP += 5; // Moderate cleanup bonus
    }

    return totalXP;
  }

  /// Get simplified XP breakdown for display (max 3 categories)
  static Map<String, int> getXPBreakdown({
    required Map<PollutionType, int> typeCounts,
    required int severity,
    required bool hasLocation,
    required bool hasPhoto,
    List<String> sceneLabels = const [],
  }) {
    final breakdown = <String, int>{};

    // Always show base report + photo + location as one combined entry
    int baseXP = 25;
    if (hasPhoto) baseXP += 5;
    if (hasLocation) baseXP += 10;
    breakdown['Report'] = baseXP;

    // Category 2: Environment bonus (beach/water priority locations)
    if (sceneLabels.any((label) =>
        label.toLowerCase().contains('beach') ||
        label.toLowerCase().contains('water') ||
        label.toLowerCase().contains('ocean'))) {
      breakdown['Location'] = 10;
    }

    // Category 3: Cleanup (items collected + weight bonus)
    final totalItems = typeCounts.values.fold(0, (sum, count) => sum + count);
    final totalWeight = calculateTotalWeight(typeCounts);

    int cleanupXP = 0;
    // Per-item bonus (capped at 50)
    cleanupXP += totalItems.clamp(0, 50);
    // Weight bonus (capped at 30)
    cleanupXP += (totalWeight * 3).round().clamp(0, 30);
    // Volume tier bonus
    if (totalItems >= 20) {
      cleanupXP += 20;
    } else if (totalItems >= 10) {
      cleanupXP += 10;
    } else if (totalItems >= 5) {
      cleanupXP += 5;
    }

    if (cleanupXP > 0) {
      breakdown['Cleanup'] = cleanupXP;
    }

    // Category 4: Impact (severity + variety bonus)
    int impactXP = 0;
    // Severity contribution
    final severityBonus = (severity - 1) * 5;
    impactXP += severityBonus;
    // Variety contribution (multiple types)
    if (typeCounts.length > 1) {
      impactXP += (typeCounts.length - 1) * 5;
    }

    if (impactXP > 0) {
      breakdown['Impact'] = impactXP;
    }

    return breakdown;
  }

  /// Calculate severity heuristic based on AI detection
  static int calculateSeverityHeuristic({
    required Map<PollutionType, int> typeCounts,
    List<String> sceneLabels = const [],
  }) {
    final totalItems = typeCounts.values.fold(0, (sum, count) => sum + count);

    // Start with base severity
    int severity = 2; // Default: Low

    // Increase based on total item count
    if (totalItems >= 20) {
      severity = 5; // Critical: Large pollution event
    } else if (totalItems >= 10) {
      severity = 4; // High: Significant pollution
    } else if (totalItems >= 5) {
      severity = 3; // Moderate: Notable pollution
    } else if (totalItems >= 2) {
      severity = 2; // Low: Some pollution
    } else {
      severity = 1; // Minor: Minimal pollution
    }

    // Boost severity for fishing gear or oil (environmental hazard)
    if (typeCounts.containsKey(PollutionType.fishingGear) ||
        typeCounts.containsKey(PollutionType.oil)) {
      severity = (severity + 1).clamp(1, 5);
    }

    // Boost severity for water/beach locations (higher environmental impact)
    if (sceneLabels.any((label) =>
        label.toLowerCase().contains('beach') ||
        label.toLowerCase().contains('water') ||
        label.toLowerCase().contains('ocean'))) {
      severity = (severity + 1).clamp(1, 5);
    }

    return severity;
  }

  /// Format weight for display (e.g., "2.5 kg" or "150 g")
  static String formatWeight(double weightKg) {
    if (weightKg < 0.001) {
      return '< 1 g';
    } else if (weightKg < 1.0) {
      return '${(weightKg * 1000).round()} g';
    } else if (weightKg < 10.0) {
      return '${weightKg.toStringAsFixed(2)} kg';
    } else {
      return '${weightKg.toStringAsFixed(1)} kg';
    }
  }

  /// Calculate environmental impact metrics
  static Map<String, dynamic> calculateImpact({
    required Map<PollutionType, int> typeCounts,
    required int severity,
    List<String> sceneLabels = const [],
  }) {
    final totalItems = typeCounts.values.fold(0, (sum, count) => sum + count);
    final typeCount = typeCounts.length;

    // Ecosystem risk (1-5 scale with context boost)
    int ecosystemRisk = severity;
    final isMarineEnvironment = sceneLabels.any((label) =>
        label.toLowerCase().contains('beach') ||
        label.toLowerCase().contains('water') ||
        label.toLowerCase().contains('ocean'));

    if (isMarineEnvironment) {
      ecosystemRisk = (ecosystemRisk + 1).clamp(1, 5);
    }

    // Hazardous materials boost
    if (typeCounts.containsKey(PollutionType.oil) ||
        typeCounts.containsKey(PollutionType.sewage)) {
      ecosystemRisk = (ecosystemRisk + 1).clamp(1, 5);
    }

    // Cleanup time estimation (minutes)
    int cleanupMinutes = (totalItems * 2.5).round(); // ~2.5 min per item base
    if (typeCounts.containsKey(PollutionType.fishingGear)) {
      cleanupMinutes += 15; // Fishing gear adds complexity
    }
    cleanupMinutes = cleanupMinutes.clamp(5, 180); // Min 5min, max 3hrs

    // Volunteers needed (1-10 scale)
    int volunteersNeeded = 1;
    if (totalItems >= 50) {
      volunteersNeeded = 8;
    } else if (totalItems >= 30) {
      volunteersNeeded = 5;
    } else if (totalItems >= 15) {
      volunteersNeeded = 3;
    } else if (totalItems >= 8) {
      volunteersNeeded = 2;
    }

    // Type diversity increases volunteer need
    if (typeCount >= 3) {
      volunteersNeeded += 1;
    }

    volunteersNeeded = volunteersNeeded.clamp(1, 10);

    return {
      'ecosystemRisk': ecosystemRisk, // 1-5
      'riskLevel': _getRiskLabel(ecosystemRisk),
      'cleanupMinutes': cleanupMinutes,
      'cleanupFormatted': formatCleanupTime(cleanupMinutes),
      'volunteersNeeded': volunteersNeeded,
      'volunteersFormatted': _formatVolunteers(volunteersNeeded),
    };
  }

  static String _getRiskLabel(int risk) {
    switch (risk) {
      case 1:
        return 'MINIMAL';
      case 2:
        return 'LOW';
      case 3:
        return 'MODERATE';
      case 4:
        return 'HIGH';
      case 5:
        return 'CRITICAL';
      default:
        return 'LOW';
    }
  }

  static String formatCleanupTime(int minutes) {
    if (minutes < 60) {
      return '~$minutes min';
    } else {
      final hours = (minutes / 60).round();
      return '~$hours hr${hours > 1 ? 's' : ''}';
    }
  }

  static String _formatVolunteers(int count) {
    if (count == 1) return '1 volunteer';
    if (count <= 3) return '$count volunteers';
    return '$count+ volunteers';
  }

  /// Get dynamic educational fact based on pollution types
  static String getEducationalFact({
    required Map<PollutionType, int> typeCounts,
    List<String> sceneLabels = const [],
  }) {
    // Priority order: Most impactful pollution types first
    if (typeCounts.containsKey(PollutionType.oil)) {
      return 'Oil on beaches takes 20+ years to degrade and affects 150+ marine species.';
    }

    if (typeCounts.containsKey(PollutionType.sewage)) {
      return 'Sewage pollution causes harmful algae blooms that deplete oxygen and kill marine life.';
    }

    if (typeCounts.containsKey(PollutionType.fishingGear)) {
      return 'Abandoned fishing gear (ghost nets) kills 650,000 marine animals annually.';
    }

    if (typeCounts.containsKey(PollutionType.plastic)) {
      final count = typeCounts[PollutionType.plastic]!;
      if (count >= 10) {
        return 'Plastic bottles take 450 years to decompose. You\'re preventing decades of harm!';
      }
      return 'Every plastic bottle removed saves marine life from ingesting microplastics.';
    }

    if (typeCounts.containsKey(PollutionType.debris)) {
      return 'Marine debris injures or kills over 100,000 marine animals each year globally.';
    }

    // Default fact
    return 'Ocean pollution affects 267 species worldwide, including 86% of sea turtles.';
  }

  /// Detect potential fraud by comparing user counts vs AI baseline
  static FraudAnalysis detectFraud({
    required Map<PollutionType, int> userCounts,
    required Map<PollutionType, int> aiBaseline,
    required int severity,
  }) {
    final warnings = <String>[];
    double fraudScore = 0.0;

    // Calculate total items
    final userTotal = userCounts.values.fold(0, (sum, count) => sum + count);
    final aiTotal = aiBaseline.values.fold(0, (sum, count) => sum + count);

    // Check 0: AI detected nothing but user added many items (soft warning)
    // This is a legitimate edge case (AI can fail on low quality images)
    // Only add soft warning if user enters a high count (>10 items)
    if (aiTotal == 0 && userTotal > 10) {
      warnings.add(
          'AI detected no items, but you entered $userTotal - please verify your counts');
      fraudScore += 0.25; // Soft penalty - not enough to block alone
    }

    // Check 1: Massive inflation (user count > 3x AI baseline)
    if (aiTotal > 0 && userTotal > aiTotal * 3) {
      warnings.add(
          'Count inflated ${((userTotal / aiTotal) * 100).toInt()}% above AI detection');
      fraudScore += 0.4;
    }

    // Check 2: Per-type inflation
    for (final entry in userCounts.entries) {
      final type = entry.key;
      final userCount = entry.value;
      final aiCount = aiBaseline[type] ?? 0;

      // Allow +50% variance (reasonable adjustment)
      // Flag if user count > 2x AI count for any type
      if (aiCount > 0 && userCount > aiCount * 2) {
        warnings.add(
            '${type.displayLabel} count inflated ${((userCount / aiCount) * 100).toInt()}%');
        fraudScore += 0.2;
      }

      // Flag unrealistic counts per type
      final maxReasonable = _getMaxReasonableCount(type);
      if (userCount > maxReasonable) {
        warnings.add(
            '${type.displayLabel}: $userCount items exceeds reasonable maximum ($maxReasonable)');
        fraudScore += 0.3;
      }
    }

    // Check 3: Severity mismatch
    final expectedSeverity = calculateSeverityHeuristic(
      typeCounts: userCounts,
      sceneLabels: [],
    );

    if ((severity - expectedSeverity).abs() >= 2) {
      warnings.add(
          'Severity ($severity) doesn\'t match item count (expected ~$expectedSeverity)');
      fraudScore += 0.2;
    }

    // Check 4: Added types not detected by AI
    for (final type in userCounts.keys) {
      if (!aiBaseline.containsKey(type) && userCounts[type]! > 0) {
        warnings.add('${type.displayLabel} added but not detected by AI');
        fraudScore += 0.1;
      }
    }

    fraudScore = fraudScore.clamp(0.0, 1.0);
    final isSuspicious = fraudScore >= 0.5; // Threshold for flagging

    return FraudAnalysis(
      isSuspicious: isSuspicious,
      fraudScore: fraudScore,
      warnings: warnings,
      suggestedCounts: aiBaseline,
    );
  }

  /// Get maximum reasonable count per pollution type
  static int _getMaxReasonableCount(PollutionType type) {
    switch (type) {
      case PollutionType.plastic:
        return 500; // Bottles/cups - beach cleanup could have hundreds
      case PollutionType.oil:
        return 50; // Oil spills - lower count
      case PollutionType.debris:
        return 1000; // General debris - highest variance
      case PollutionType.sewage:
        return 20; // Sewage incidents - typically low count
      case PollutionType.fishingGear:
        return 100; // Nets/ropes - moderate
      case PollutionType.container:
        return 200; // Containers/drums
      case PollutionType.other:
        return 500; // Generic
    }
  }

  /// Calculate XP with optional fraud penalty
  static int calculateXPWithFraudCheck({
    required Map<PollutionType, int> typeCounts,
    required Map<PollutionType, int> aiBaseline,
    required int severity,
    required bool hasLocation,
    required bool hasPhoto,
    List<String> sceneLabels = const [],
  }) {
    // Calculate base XP
    int baseXP = calculateXP(
      typeCounts: typeCounts,
      severity: severity,
      hasLocation: hasLocation,
      hasPhoto: hasPhoto,
      sceneLabels: sceneLabels,
    );

    // Apply fraud penalty if suspicious
    final fraud = detectFraud(
      userCounts: typeCounts,
      aiBaseline: aiBaseline,
      severity: severity,
    );

    if (fraud.isSuspicious) {
      // Reduce XP by fraud score percentage
      final penalty = (baseXP * fraud.fraudScore).round();
      baseXP = (baseXP - penalty).clamp(10, baseXP); // Min 10 XP
    }

    return baseXP;
  }

  /// Maps YOLO-detected object names to PollutionType.
  /// Must stay in sync with AIAnalysisService._mapAllPollutionTypes().
  static const Map<String, PollutionType> objectToPollutionType = {
    // Plastic items (bottles, cups - genuine plastic)
    'bottle': PollutionType.plastic,
    'cup': PollutionType.plastic,
    'toothbrush': PollutionType.plastic,

    // Debris/General waste (glass, ceramic, sports equipment, food, e-waste)
    'bowl': PollutionType.debris,
    'vase': PollutionType.debris,
    'wine glass': PollutionType.debris,
    'handbag': PollutionType.debris,
    'backpack': PollutionType.debris,
    'suitcase': PollutionType.debris,
    'umbrella': PollutionType.debris,

    // Sports equipment (common beach/outdoor litter)
    'sports ball': PollutionType.debris,
    'frisbee': PollutionType.debris,
    'kite': PollutionType.debris,
    'surfboard': PollutionType.debris,
    'skateboard': PollutionType.debris,
    'tennis racket': PollutionType.debris,
    'baseball bat': PollutionType.debris,
    'baseball glove': PollutionType.debris,

    // Food waste
    'banana': PollutionType.debris,
    'apple': PollutionType.debris,
    'orange': PollutionType.debris,
    'sandwich': PollutionType.debris,
    'hot dog': PollutionType.debris,
    'pizza': PollutionType.debris,
    'donut': PollutionType.debris,
    'cake': PollutionType.debris,
    'broccoli': PollutionType.debris,
    'carrot': PollutionType.debris,

    // E-waste & small items
    'cell phone': PollutionType.debris,
    'remote': PollutionType.debris,
    'book': PollutionType.debris,
    'tie': PollutionType.debris,
    'hair drier': PollutionType.debris,

    // Cutlery (common outdoor litter)
    'fork': PollutionType.plastic,
    'knife': PollutionType.plastic,
    'spoon': PollutionType.plastic,

    // Other common litter
    'scissors': PollutionType.debris,
    'teddy bear': PollutionType.debris,

    // Vehicles (dumped/abandoned)
    'bicycle': PollutionType.debris,
    'car': PollutionType.debris,
    'motorcycle': PollutionType.debris,

    // Furniture
    'bench': PollutionType.debris,

    // Marine equipment
    'boat': PollutionType.fishingGear,
  };

  /// Maps a detected item name to its PollutionType.
  /// Returns null if the item doesn't map to any pollution type.
  static PollutionType? mapItemToPollutionType(String item) {
    return objectToPollutionType[item.toLowerCase()];
  }
}
