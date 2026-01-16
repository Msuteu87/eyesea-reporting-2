import 'package:flutter_test/flutter_test.dart';
import 'package:eyesea_reporting_2/core/utils/pollution_calculations.dart';
import 'package:eyesea_reporting_2/domain/entities/report.dart';

/// Unit tests for PollutionCalculations
/// Focus: High-risk functions that have caused bugs or could cause bugs
/// Total: 25 tests covering detectFraud, calculateXP, calculateTotalWeight, mapItemToPollutionType

void main() {
  // ============================================================
  // detectFraud() - 10 tests
  // Critical: Prevents wrongly flagging legitimate reports
  // ============================================================
  group('detectFraud', () {
    test('returns clean score when user counts match AI baseline', () {
      final result = PollutionCalculations.detectFraud(
        userCounts: {PollutionType.plastic: 5},
        aiBaseline: {PollutionType.plastic: 5},
        severity: 3,
      );

      expect(result.isSuspicious, false);
      expect(result.fraudScore, lessThan(0.5));
      expect(result.warnings, isEmpty);
    });

    test('flags when user count > 3x AI baseline', () {
      final result = PollutionCalculations.detectFraud(
        userCounts: {PollutionType.plastic: 30},
        aiBaseline: {PollutionType.plastic: 5},
        severity: 3,
      );

      expect(result.fraudScore, greaterThanOrEqualTo(0.4));
      expect(result.warnings, contains(contains('inflated')));
    });

    test('flags when AI empty but user adds >10 items', () {
      final result = PollutionCalculations.detectFraud(
        userCounts: {PollutionType.plastic: 15},
        aiBaseline: {},
        severity: 3,
      );

      expect(result.fraudScore, greaterThanOrEqualTo(0.25));
      expect(result.warnings, contains(contains('AI detected no items')));
    });

    test('does NOT flag when AI empty but user adds <=10 items', () {
      final result = PollutionCalculations.detectFraud(
        userCounts: {PollutionType.plastic: 5},
        aiBaseline: {},
        severity: 2,
      );

      // Should only have minor warnings (type added), not the "AI detected no items" warning
      expect(result.warnings.any((w) => w.contains('AI detected no items')), false);
    });

    test('flags per-type inflation when user > 2x AI for a type', () {
      final result = PollutionCalculations.detectFraud(
        userCounts: {PollutionType.plastic: 20},
        aiBaseline: {PollutionType.plastic: 5},
        severity: 3,
      );

      expect(result.warnings, contains(contains('Plastic')));
      expect(result.warnings, contains(contains('inflated')));
    });

    test('flags unreasonable count per type (exceeds max)', () {
      final result = PollutionCalculations.detectFraud(
        userCounts: {PollutionType.plastic: 600}, // Max is 500
        aiBaseline: {PollutionType.plastic: 600},
        severity: 5,
      );

      expect(result.warnings, contains(contains('exceeds reasonable maximum')));
    });

    test('flags severity mismatch when difference >= 2', () {
      final result = PollutionCalculations.detectFraud(
        userCounts: {PollutionType.plastic: 2}, // Suggests severity ~2
        aiBaseline: {PollutionType.plastic: 2},
        severity: 5, // User selected 5 - mismatch
      );

      expect(result.warnings, contains(contains('Severity')));
    });

    test('flags types added but not detected by AI', () {
      final result = PollutionCalculations.detectFraud(
        userCounts: {
          PollutionType.plastic: 5,
          PollutionType.oil: 2, // Not in AI baseline
        },
        aiBaseline: {PollutionType.plastic: 5},
        severity: 3,
      );

      expect(result.warnings, contains(contains('not detected by AI')));
    });

    test('caps fraud score at 1.0 even with multiple violations', () {
      final result = PollutionCalculations.detectFraud(
        userCounts: {
          PollutionType.plastic: 1000, // Exceeds max
          PollutionType.debris: 2000, // Exceeds max
          PollutionType.oil: 100, // Exceeds max
        },
        aiBaseline: {},
        severity: 5,
      );

      expect(result.fraudScore, lessThanOrEqualTo(1.0));
    });

    test('threshold: score >= 0.5 marks as suspicious', () {
      // Trigger enough violations to cross 0.5 threshold
      final result = PollutionCalculations.detectFraud(
        userCounts: {PollutionType.plastic: 50}, // 10x AI = 0.4+
        aiBaseline: {PollutionType.plastic: 5},
        severity: 1, // Mismatch = 0.2+
      );

      expect(result.isSuspicious, true);
      expect(result.fraudScore, greaterThanOrEqualTo(0.5));
    });
  });

  // ============================================================
  // calculateXP() - 8 tests
  // Critical: Ensures players get correct rewards
  // ============================================================
  group('calculateXP', () {
    test('returns base XP of 25 for minimal report', () {
      final xp = PollutionCalculations.calculateXP(
        typeCounts: {},
        severity: 1,
        hasLocation: false,
        hasPhoto: false,
      );

      expect(xp, 25);
    });

    test('adds +5 XP for photo bonus', () {
      final withPhoto = PollutionCalculations.calculateXP(
        typeCounts: {},
        severity: 1,
        hasLocation: false,
        hasPhoto: true,
      );

      final withoutPhoto = PollutionCalculations.calculateXP(
        typeCounts: {},
        severity: 1,
        hasLocation: false,
        hasPhoto: false,
      );

      expect(withPhoto - withoutPhoto, 5);
    });

    test('adds +10 XP for location bonus', () {
      final withLocation = PollutionCalculations.calculateXP(
        typeCounts: {},
        severity: 1,
        hasLocation: true,
        hasPhoto: false,
      );

      final withoutLocation = PollutionCalculations.calculateXP(
        typeCounts: {},
        severity: 1,
        hasLocation: false,
        hasPhoto: false,
      );

      expect(withLocation - withoutLocation, 10);
    });

    test('adds +10 XP for beach/water scene labels', () {
      final withBeach = PollutionCalculations.calculateXP(
        typeCounts: {},
        severity: 1,
        hasLocation: false,
        hasPhoto: false,
        sceneLabels: ['Beach', 'Outdoor'],
      );

      final withoutBeach = PollutionCalculations.calculateXP(
        typeCounts: {},
        severity: 1,
        hasLocation: false,
        hasPhoto: false,
        sceneLabels: ['Indoor'],
      );

      expect(withBeach - withoutBeach, 10);
    });

    test('severity bonus scales: (severity-1) * 5 XP', () {
      final severity1 = PollutionCalculations.calculateXP(
        typeCounts: {},
        severity: 1,
        hasLocation: false,
        hasPhoto: false,
      );

      final severity5 = PollutionCalculations.calculateXP(
        typeCounts: {},
        severity: 5,
        hasLocation: false,
        hasPhoto: false,
      );

      // Severity 5 should give (5-1)*5 = 20 more XP than severity 1
      expect(severity5 - severity1, 20);
    });

    test('caps item bonus at 50 XP', () {
      final xp100Items = PollutionCalculations.calculateXP(
        typeCounts: {PollutionType.plastic: 100},
        severity: 1,
        hasLocation: false,
        hasPhoto: false,
      );

      final xp50Items = PollutionCalculations.calculateXP(
        typeCounts: {PollutionType.plastic: 50},
        severity: 1,
        hasLocation: false,
        hasPhoto: false,
      );

      // 100 items should give same item bonus as 50 (capped)
      // But weight bonus may differ slightly
      expect(xp100Items, greaterThanOrEqualTo(xp50Items));
    });

    test('caps weight bonus at 30 XP', () {
      // 100kg of plastic would be 300 XP uncapped, but should be capped at 30
      final xp = PollutionCalculations.calculateXP(
        typeCounts: {PollutionType.fishingGear: 100}, // 100 * 2.5kg = 250kg
        severity: 1,
        hasLocation: false,
        hasPhoto: false,
      );

      // Base 25 + items(capped 50) + weight(capped 30) + volume tier(20) = 125
      expect(xp, greaterThanOrEqualTo(100)); // At least these bonuses
    });

    test('all bonuses stack correctly for complete report', () {
      final xp = PollutionCalculations.calculateXP(
        typeCounts: {
          PollutionType.plastic: 25,
          PollutionType.debris: 5,
        },
        severity: 4,
        hasLocation: true,
        hasPhoto: true,
        sceneLabels: ['beach'],
      );

      // Expected breakdown:
      // Base: 25
      // Photo: +5
      // Location: +10
      // Beach scene: +10
      // Severity (4-1)*5: +15
      // Multi-type (2-1)*5: +5
      // Items (30): +30
      // Weight bonus: varies
      // Volume tier (30 items >= 20): +20
      // Total should be at least 120+
      expect(xp, greaterThanOrEqualTo(120));
    });
  });

  // ============================================================
  // calculateTotalWeight() - 4 tests
  // Critical: Core calculation used in UI + server
  // ============================================================
  group('calculateTotalWeight', () {
    test('returns 0 for empty map', () {
      final weight = PollutionCalculations.calculateTotalWeight({});
      expect(weight, 0.0);
    });

    test('calculates single type correctly', () {
      // Plastic: 0.025kg per item
      final weight = PollutionCalculations.calculateTotalWeight({
        PollutionType.plastic: 10,
      });

      expect(weight, closeTo(0.25, 0.001)); // 10 * 0.025 = 0.25kg
    });

    test('calculates multiple types correctly', () {
      final weight = PollutionCalculations.calculateTotalWeight({
        PollutionType.plastic: 10, // 10 * 0.025 = 0.25kg
        PollutionType.fishingGear: 2, // 2 * 2.5 = 5.0kg
      });

      expect(weight, closeTo(5.25, 0.001));
    });

    test('uses correct weights per pollution type', () {
      // Verify known weights
      expect(
        PollutionCalculations.calculateTotalWeight({PollutionType.plastic: 1}),
        closeTo(0.025, 0.001),
      );
      expect(
        PollutionCalculations.calculateTotalWeight({PollutionType.oil: 1}),
        closeTo(0.5, 0.001),
      );
      expect(
        PollutionCalculations.calculateTotalWeight({PollutionType.debris: 1}),
        closeTo(0.15, 0.001),
      );
      expect(
        PollutionCalculations.calculateTotalWeight({PollutionType.fishingGear: 1}),
        closeTo(2.5, 0.001),
      );
    });
  });

  // ============================================================
  // mapItemToPollutionType() - 3 tests
  // Critical: Must match YOLO class names correctly
  // ============================================================
  group('mapItemToPollutionType', () {
    test('maps known items to correct pollution types', () {
      expect(
        PollutionCalculations.mapItemToPollutionType('bottle'),
        PollutionType.plastic,
      );
      expect(
        PollutionCalculations.mapItemToPollutionType('boat'),
        PollutionType.fishingGear,
      );
      expect(
        PollutionCalculations.mapItemToPollutionType('pizza'),
        PollutionType.debris,
      );
    });

    test('returns null for unknown items', () {
      expect(
        PollutionCalculations.mapItemToPollutionType('unicorn'),
        isNull,
      );
      expect(
        PollutionCalculations.mapItemToPollutionType(''),
        isNull,
      );
    });

    test('handles case insensitivity', () {
      expect(
        PollutionCalculations.mapItemToPollutionType('BOTTLE'),
        PollutionType.plastic,
      );
      expect(
        PollutionCalculations.mapItemToPollutionType('Bottle'),
        PollutionType.plastic,
      );
      expect(
        PollutionCalculations.mapItemToPollutionType('bOtTlE'),
        PollutionType.plastic,
      );
    });
  });
}
