import '../../domain/entities/report.dart';

/// Centralized configuration for pollution-related constants.
///
/// This file contains weights, mappings, and thresholds used across the app
/// for pollution calculations, AI analysis, and gamification.
///
/// ## Updating Values
///
/// These constants can be adjusted based on real-world data analysis.
/// Future enhancement: Load from Supabase config table for dynamic updates
/// without app releases.
class PollutionConfig {
  PollutionConfig._();

  // ---------------------------------------------------------------------------
  // Weight Estimation Constants
  // ---------------------------------------------------------------------------

  /// Average weight per item in kilograms, used for environmental impact
  /// calculations and gamification scoring.
  ///
  /// Values are estimates based on typical item sizes:
  /// - Plastic bottle: ~25g (0.025kg)
  /// - Fishing net fragment: ~2.5kg
  /// - Oil container unit: ~500g
  static const Map<PollutionType, double> averageWeights = {
    PollutionType.plastic: 0.025, // ~25g per plastic bottle/cup
    PollutionType.oil: 0.5, // Oil spill estimation per unit
    PollutionType.debris: 0.15, // ~150g per debris item
    PollutionType.sewage: 1.0, // Sewage incident estimation
    PollutionType.fishingGear: 2.5, // ~2.5kg per fishing gear item
    PollutionType.container: 0.5, // ~500g per container
    PollutionType.other: 0.1, // Generic weight
  };

  // ---------------------------------------------------------------------------
  // Maximum Reasonable Counts (Fraud Detection)
  // ---------------------------------------------------------------------------

  /// Maximum reasonable item counts per pollution type.
  /// Used by fraud detection to flag unrealistic reports.
  static const Map<PollutionType, int> maxReasonableCounts = {
    PollutionType.plastic: 500, // Beach cleanup could have hundreds
    PollutionType.oil: 50, // Oil spills - lower count
    PollutionType.debris: 1000, // General debris - highest variance
    PollutionType.sewage: 20, // Sewage incidents - typically low count
    PollutionType.fishingGear: 100, // Nets/ropes - moderate
    PollutionType.container: 200, // Containers/drums
    PollutionType.other: 500, // Generic
  };

  // ---------------------------------------------------------------------------
  // XP/Credits Calculation Constants
  // ---------------------------------------------------------------------------

  /// Base XP awarded for submitting a report
  static const int baseReportXP = 25;

  /// Bonus XP for including a photo
  static const int photoBonus = 5;

  /// Bonus XP for including location data
  static const int locationBonus = 10;

  /// Bonus XP for beach/water/ocean locations (environmental priority)
  static const int environmentBonus = 10;

  /// XP per severity level above 1 (severity 2 = +5, severity 3 = +10, etc.)
  static const int severityMultiplier = 5;

  /// Bonus XP per additional pollution type detected
  static const int varietyBonus = 5;

  /// Maximum XP from per-item bonus (prevents gaming)
  static const int maxItemBonus = 50;

  /// Maximum XP from weight bonus
  static const int maxWeightBonus = 30;

  /// XP multiplier per kg of pollution
  static const int weightXPPerKg = 3;

  /// Volume tier thresholds and bonuses
  static const Map<int, int> volumeTierBonuses = {
    20: 20, // 20+ items = +20 XP (major cleanup)
    10: 10, // 10+ items = +10 XP (significant cleanup)
    5: 5, // 5+ items = +5 XP (moderate cleanup)
  };

  // ---------------------------------------------------------------------------
  // Fraud Detection Thresholds
  // ---------------------------------------------------------------------------

  /// Score threshold above which a report is flagged as suspicious
  static const double fraudFlagThreshold = 0.5;

  /// Multiplier threshold for count inflation (user > AI × this = flagged)
  static const double inflationThreshold = 3.0;

  /// Per-type inflation threshold
  static const double perTypeInflationThreshold = 2.0;
}
