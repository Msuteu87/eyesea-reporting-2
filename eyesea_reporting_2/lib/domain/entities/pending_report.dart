import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';

/// Sync status for pending reports
enum SyncStatus {
  pending, // Not yet synced
  syncing, // Currently uploading
  synced, // Successfully uploaded
  failed, // Upload failed, will retry
}

/// A report that's been captured but not yet synced to Supabase.
/// Stored in Hive for offline-first capability.
class PendingReport extends HiveObject {
  final String id;
  final String imagePath;
  final String pollutionType;
  final int severity;
  final String? notes;
  final double latitude;
  final double longitude;
  final DateTime createdAt;
  String syncStatusValue;
  int retryCount;
  String? errorMessage;
  final String? city;
  final String? country;

  // NEW: Gamification and fraud detection fields
  final String pollutionCountsJson; // JSON string: {"plastic": 5, "debris": 3}
  final double totalWeightKg;
  final int xpEarned;
  final bool isFlagged;
  final double fraudScore;
  final String fraudWarningsJson; // JSON array: ["warning1", "warning2"]
  final String sceneLabelsJson; // JSON array: ["Beach", "Outdoor"]
  final String aiBaselineCountsJson; // JSON string: {"plastic": 4, "debris": 2}
  final int peopleDetected;

  PendingReport({
    required this.id,
    required this.imagePath,
    required this.pollutionType,
    required this.severity,
    this.notes,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
    this.syncStatusValue = 'pending',
    this.retryCount = 0,
    this.errorMessage,
    this.city,
    this.country,
    // NEW fields with defaults for backward compatibility
    this.pollutionCountsJson = '{}',
    this.totalWeightKg = 0.0,
    this.xpEarned = 0,
    this.isFlagged = false,
    this.fraudScore = 0.0,
    this.fraudWarningsJson = '[]',
    this.sceneLabelsJson = '[]',
    this.aiBaselineCountsJson = '{}',
    this.peopleDetected = 0,
  });

  SyncStatus get syncStatus {
    switch (syncStatusValue) {
      case 'syncing':
        return SyncStatus.syncing;
      case 'synced':
        return SyncStatus.synced;
      case 'failed':
        return SyncStatus.failed;
      default:
        return SyncStatus.pending;
    }
  }

  set syncStatus(SyncStatus status) {
    syncStatusValue = status.name;
  }

  /// Decode pollution counts from JSON
  Map<String, int> get pollutionCounts {
    try {
      final decoded = jsonDecode(pollutionCountsJson) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, v as int));
    } catch (_) {
      return {};
    }
  }

  /// Decode AI baseline counts from JSON
  Map<String, int> get aiBaselineCounts {
    try {
      final decoded = jsonDecode(aiBaselineCountsJson) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, v as int));
    } catch (_) {
      return {};
    }
  }

  /// Decode fraud warnings from JSON
  List<String> get fraudWarnings {
    try {
      final decoded = jsonDecode(fraudWarningsJson) as List<dynamic>;
      return decoded.cast<String>();
    } catch (_) {
      return [];
    }
  }

  /// Decode scene labels from JSON
  List<String> get sceneLabels {
    try {
      final decoded = jsonDecode(sceneLabelsJson) as List<dynamic>;
      return decoded.cast<String>();
    } catch (_) {
      return [];
    }
  }

  /// Create a copy with updated fields
  PendingReport copyWith({
    String? syncStatusValue,
    int? retryCount,
    String? errorMessage,
  }) {
    return PendingReport(
      id: id,
      imagePath: imagePath,
      pollutionType: pollutionType,
      severity: severity,
      notes: notes,
      latitude: latitude,
      longitude: longitude,
      createdAt: createdAt,
      syncStatusValue: syncStatusValue ?? this.syncStatusValue,
      retryCount: retryCount ?? this.retryCount,
      errorMessage: errorMessage ?? this.errorMessage,
      city: city,
      country: country,
      pollutionCountsJson: pollutionCountsJson,
      totalWeightKg: totalWeightKg,
      xpEarned: xpEarned,
      isFlagged: isFlagged,
      fraudScore: fraudScore,
      fraudWarningsJson: fraudWarningsJson,
      sceneLabelsJson: sceneLabelsJson,
      aiBaselineCountsJson: aiBaselineCountsJson,
      peopleDetected: peopleDetected,
    );
  }
}

/// Hive TypeAdapter for PendingReport
/// Field indices 0-12 are existing, 13-21 are new gamification/fraud fields
class PendingReportAdapter extends TypeAdapter<PendingReport> {
  @override
  final int typeId = 0;

  @override
  PendingReport read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PendingReport(
      id: fields[0] as String,
      imagePath: fields[1] as String,
      pollutionType: fields[2] as String,
      severity: fields[3] as int,
      notes: fields[4] as String?,
      latitude: fields[5] as double,
      longitude: fields[6] as double,
      createdAt: fields[7] as DateTime,
      syncStatusValue: fields[8] as String? ?? 'pending',
      retryCount: fields[9] as int? ?? 0,
      errorMessage: fields[10] as String?,
      city: fields[11] as String?,
      country: fields[12] as String?,
      // NEW fields with defaults for backward compatibility
      pollutionCountsJson: fields[13] as String? ?? '{}',
      totalWeightKg: fields[14] as double? ?? 0.0,
      xpEarned: fields[15] as int? ?? 0,
      isFlagged: fields[16] as bool? ?? false,
      fraudScore: fields[17] as double? ?? 0.0,
      fraudWarningsJson: fields[18] as String? ?? '[]',
      sceneLabelsJson: fields[19] as String? ?? '[]',
      aiBaselineCountsJson: fields[20] as String? ?? '{}',
      peopleDetected: fields[21] as int? ?? 0,
    );
  }

  @override
  void write(BinaryWriter writer, PendingReport obj) {
    writer
      ..writeByte(22) // Total number of fields (was 13, now 22)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.imagePath)
      ..writeByte(2)
      ..write(obj.pollutionType)
      ..writeByte(3)
      ..write(obj.severity)
      ..writeByte(4)
      ..write(obj.notes)
      ..writeByte(5)
      ..write(obj.latitude)
      ..writeByte(6)
      ..write(obj.longitude)
      ..writeByte(7)
      ..write(obj.createdAt)
      ..writeByte(8)
      ..write(obj.syncStatusValue)
      ..writeByte(9)
      ..write(obj.retryCount)
      ..writeByte(10)
      ..write(obj.errorMessage)
      ..writeByte(11)
      ..write(obj.city)
      ..writeByte(12)
      ..write(obj.country)
      // NEW fields
      ..writeByte(13)
      ..write(obj.pollutionCountsJson)
      ..writeByte(14)
      ..write(obj.totalWeightKg)
      ..writeByte(15)
      ..write(obj.xpEarned)
      ..writeByte(16)
      ..write(obj.isFlagged)
      ..writeByte(17)
      ..write(obj.fraudScore)
      ..writeByte(18)
      ..write(obj.fraudWarningsJson)
      ..writeByte(19)
      ..write(obj.sceneLabelsJson)
      ..writeByte(20)
      ..write(obj.aiBaselineCountsJson)
      ..writeByte(21)
      ..write(obj.peopleDetected);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PendingReportAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
