import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide ImageSource;
import 'package:geolocator/geolocator.dart' as geo;
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/services/report_queue_service.dart';
import '../../core/services/ai_analysis_service.dart';
import '../../core/utils/pollution_calculations.dart';
import '../../domain/entities/report.dart';
import 'widgets/pollution_type_selector.dart';
import 'widgets/location_scene_card.dart';
import 'widgets/map_picker_bottom_sheet.dart';
import 'widgets/severity_selector.dart';
import 'widgets/report_summary_card.dart';

/// Report details screen - receives captured/selected image and allows user
/// to fill in pollution details before submitting.
class ReportDetailsScreen extends StatefulWidget {
  final String imagePath;

  const ReportDetailsScreen({
    super.key,
    required this.imagePath,
  });

  @override
  State<ReportDetailsScreen> createState() => _ReportDetailsScreenState();
}

class _ReportDetailsScreenState extends State<ReportDetailsScreen> {
  // Changed from single type to a Set of selected types for multi-selection
  Set<PollutionType> _selectedPollutionTypes = {PollutionType.plastic};
  int _severity = 3;
  bool _isSubmitting = false;
  Point? _currentLocation;
  String? _city;
  String? _country;
  bool _isAnalyzing = false;
  List<String> _sceneLabels = [];

  late final File _imageFile;

  @override
  void initState() {
    super.initState();
    _imageFile = File(widget.imagePath);
    _detectLocation();
    // Run analysis after build frame to access context providers safely
    WidgetsBinding.instance.addPostFrameCallback((_) => _analyzeImage());
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _detectLocation() async {
    try {
      final permission = await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.denied) {
        await geo.Geolocator.requestPermission();
      }

      final position = await geo.Geolocator.getCurrentPosition(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.high,
        ),
      );

      if (mounted) {
        setState(() {
          _currentLocation = Point(
            coordinates: Position(position.longitude, position.latitude),
          );
        });

        // Reverse geocode to get city/country
        _reverseGeocode(position.latitude, position.longitude);
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
  }

  Future<void> _reverseGeocode(double lat, double lng) async {
    try {
      final placemarks = await geocoding.placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty && mounted) {
        final place = placemarks.first;
        final city = place.locality ??
            place.subAdministrativeArea ??
            place.administrativeArea;
        final country = place.country;

        setState(() {
          _city = city;
          _country = country;
        });
        debugPrint('📍 Location: $_city, $_country');
      }
    } catch (e) {
      debugPrint('Reverse geocoding failed: $e');
      // Fallback variables are null, which is fine
    }
  }

  bool _hasPeopleDetected = false;
  Map<PollutionType, int> _typeCounts = {};
  Map<PollutionType, int> _aiBaselineCounts =
      {}; // Store AI detection baseline for fraud comparison

  Future<void> _analyzeImage() async {
    if (!mounted) return;

    setState(() => _isAnalyzing = true);

    try {
      final aiService = context.read<AIAnalysisService>();
      final result = await aiService.analyzeImage(widget.imagePath);

      if (mounted && result != null) {
        // Store scene labels and people detection status
        setState(() {
          _sceneLabels = result.sceneLabels;
          _hasPeopleDetected = result.peopleCount > 0;

          // Map detected items to PollutionType counts
          _typeCounts.clear();
          for (final entry in result.pollutionCounts.entries) {
            final type = _mapItemToType(entry.key);
            if (type != null) {
              _typeCounts[type] = (_typeCounts[type] ?? 0) + entry.value;
            }
          }

          // Auto-calculate severity based on AI detection
          _severity = PollutionCalculations.calculateSeverityHeuristic(
            typeCounts: _typeCounts,
            sceneLabels: _sceneLabels,
          );
        });

        // Show warning if AI detected issues (too many people, no pollution)
        if (result.userWarning != null || _hasPeopleDetected) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(LucideIcons.alertTriangle,
                      color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Text(_hasPeopleDetected
                          ? 'For privacy, reports with people cannot be submitted.'
                          : result.userWarning!)),
                ],
              ),
              backgroundColor: Colors.orange.shade700,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          );
        }

        // Auto-select pollution types if detected (multi-selection)
        if (result.detectedPollutionTypes.isNotEmpty) {
          final detectedTypes = <PollutionType>{};
          final detectedCounts = <PollutionType, int>{};

          for (final entry in result.detectedPollutionTypes.entries) {
            try {
              final type = PollutionType.values.firstWhere(
                (t) => t.name == entry.key,
              );
              detectedTypes.add(type);
              detectedCounts[type] = entry.value;
            } catch (e) {
              debugPrint('Unknown pollution type: ${entry.key}');
            }
          }

          if (detectedTypes.isNotEmpty) {
            setState(() {
              _selectedPollutionTypes = detectedTypes;
              _typeCounts = detectedCounts;
              _aiBaselineCounts = Map.from(
                  detectedCounts); // Store baseline for fraud detection
            });
          }

          final typeLabels =
              detectedTypes.map((t) => t.displayLabel).join(', ');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(LucideIcons.sparkles,
                      color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(color: Colors.white),
                        children: [
                          const TextSpan(text: 'AI Detected: '),
                          TextSpan(
                            text: typeLabels,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              backgroundColor: AppColors.oceanBlue,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('AI Analysis UI Error: $e');
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  Future<void> _showLocationPicker() async {
    if (_currentLocation == null) return;

    final newLocation = await MapPickerBottomSheet.show(
      context,
      latitude: _currentLocation!.coordinates.lat.toDouble(),
      longitude: _currentLocation!.coordinates.lng.toDouble(),
      city: _city,
      country: _country,
    );

    if (newLocation != null && mounted) {
      setState(() {
        _currentLocation = newLocation;
      });

      // Re-run reverse geocoding for new location
      try {
        final placemarks = await geocoding.placemarkFromCoordinates(
          newLocation.coordinates.lat.toDouble(),
          newLocation.coordinates.lng.toDouble(),
        );
        if (placemarks.isNotEmpty && mounted) {
          final place = placemarks.first;
          setState(() {
            _city = place.locality ?? place.subAdministrativeArea;
            _country = place.country;
          });
        }
      } catch (e) {
        debugPrint('Reverse geocoding after move failed: $e');
      }
    }
  }

  Future<void> _submitReport() async {
    if (_currentLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Waiting for location... please wait.')),
      );
      await _detectLocation();
      if (!mounted || _currentLocation == null) return;
    }

    setState(() => _isSubmitting = true);

    try {
      final queueService = context.read<ReportQueueService>();
      final connectivityService = context.read<ConnectivityService>();

      // Use the first selected type as primary (pollution_counts stores all types)
      final primaryType = _selectedPollutionTypes.isNotEmpty
          ? _selectedPollutionTypes.first
          : PollutionType.other;

      // Calculate all gamification and fraud data before submission
      final totalXP = PollutionCalculations.calculateXP(
        typeCounts: _typeCounts,
        severity: _severity,
        hasLocation: _currentLocation != null,
        hasPhoto: true,
        sceneLabels: _sceneLabels,
      );

      final totalWeight =
          PollutionCalculations.calculateTotalWeight(_typeCounts);

      final fraud = PollutionCalculations.detectFraud(
        userCounts: _typeCounts,
        aiBaseline: _aiBaselineCounts,
        severity: _severity,
      );

      // Save to queue with all gamification/fraud data (works offline)
      await queueService.addToQueue(
        imagePath: widget.imagePath,
        pollutionType: primaryType,
        severity: _severity,
        notes: null,
        latitude: _currentLocation!.coordinates.lat.toDouble(),
        longitude: _currentLocation!.coordinates.lng.toDouble(),
        city: _city,
        country: _country,
        // NEW: Gamification and fraud detection fields
        pollutionCounts: _typeCounts,
        totalWeightKg: totalWeight,
        xpEarned: totalXP,
        isFlagged: fraud.isSuspicious,
        fraudScore: fraud.fraudScore,
        fraudWarnings: fraud.warnings,
        sceneLabels: _sceneLabels,
        aiBaselineCounts: _aiBaselineCounts,
        peopleDetected: _hasPeopleDetected ? 1 : 0,
      );

      if (mounted) {
        final isOnline = connectivityService.isOnline;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  isOnline ? LucideIcons.check : LucideIcons.cloudOff,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isOnline
                        ? 'Report submitted successfully!'
                        : 'Saved offline. Will sync when connected.',
                  ),
                ),
              ],
            ),
            backgroundColor:
                isOnline ? AppColors.successGreen : AppColors.amberGlow,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );

        // Navigate back to home
        context.go('/');
      }
    } catch (e) {
      debugPrint('Submit error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save report: $e'),
            backgroundColor: AppColors.punchRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: isDark ? AppColors.deepNavy : Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          // Image Header with App Bar
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: isDark ? AppColors.deepNavy : Colors.white,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.arrowLeft, color: Colors.white),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(
                    _imageFile,
                    fit: BoxFit.cover,
                  ),
                  // Gradient overlay for readability
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.3),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.5),
                        ],
                      ),
                    ),
                  ),
                  // Retake Button
                  Positioned(
                    bottom: 16,
                    right: 16,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => Navigator.pop(context),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                LucideIcons.camera,
                                color: Colors.white,
                                size: 16,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Retake',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Form Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Location & Scene Card
                  LocationSceneCard(
                    city: _city,
                    country: _country,
                    latitude: _currentLocation?.coordinates.lat.toDouble(),
                    longitude: _currentLocation?.coordinates.lng.toDouble(),
                    sceneLabels: _sceneLabels,
                    isLoadingLocation: _currentLocation == null,
                    isLoadingScene: _isAnalyzing,
                    onEditLocation: () => _showLocationPicker(),
                  ),

                  const SizedBox(height: 24),

                  // Pollution Type
                  Text(
                    'What type of pollution?',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ).animate().fadeIn(delay: 100.ms),
                  if (_isAnalyzing)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: primaryColor)),
                    ),
                  const SizedBox(height: 12),
                  _buildPollutionTypeSelector(primaryColor, isDark),

                  const SizedBox(height: 32),

                  // Severity
                  Text(
                    'How severe is it?',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ).animate().fadeIn(delay: 200.ms),
                  const SizedBox(height: 16),
                  SeveritySelector(
                    severity: _severity,
                    onSeverityChanged: (val) => setState(() => _severity = val),
                    isDark: isDark,
                  ),

                  const SizedBox(height: 32),

                  // Report Summary Card (Environmental Impact)
                  ReportSummaryCard(
                    typeCounts: _typeCounts,
                    severity: _severity,
                    hasLocation: _currentLocation != null,
                    hasPhoto: true,
                    sceneLabels: _sceneLabels,
                    isDark: isDark,
                  ),

                  const SizedBox(height: 40),

                  // Submit Button
                  _buildSubmitButton(primaryColor),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton(Color primaryColor) {
    // Block submission if analyzing OR if people detected
    final isDisabled = _isSubmitting || _hasPeopleDetected;

    // Calculate XP for button text
    final totalXP = PollutionCalculations.calculateXP(
      typeCounts: _typeCounts,
      severity: _severity,
      hasLocation: _currentLocation != null,
      hasPhoto: true,
      sceneLabels: _sceneLabels,
    );

    return Column(
      children: [
        if (_hasPeopleDetected)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.punchRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.punchRed),
              ),
              child: const Row(
                children: [
                  Icon(LucideIcons.userX, color: AppColors.punchRed),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'For privacy reasons, you cannot submit reports containing people. Please retake the photo.',
                      style: TextStyle(
                        color: AppColors.punchRed,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: FilledButton(
            onPressed: isDisabled ? null : _handleSubmitWithFraudCheck,
            style: FilledButton.styleFrom(
              backgroundColor: primaryColor,
              disabledBackgroundColor: _hasPeopleDetected
                  ? Colors.grey[400]
                  : primaryColor.withValues(alpha: 0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(LucideIcons.send, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        _hasPeopleDetected
                            ? 'Cannot Submit (People Detected)'
                            : 'Submit Report (+$totalXP XP)',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  void _handleSubmitWithFraudCheck() {
    // Check for fraud before submitting
    final fraud = PollutionCalculations.detectFraud(
      userCounts: _typeCounts,
      aiBaseline: _aiBaselineCounts,
      severity: _severity,
    );

    debugPrint('🔍 Fraud Check:');
    debugPrint('   User counts: $_typeCounts');
    debugPrint('   AI baseline: $_aiBaselineCounts');
    debugPrint('   Fraud score: ${fraud.fraudScore}');
    debugPrint('   Is suspicious: ${fraud.isSuspicious}');
    debugPrint('   Warnings: ${fraud.warnings}');

    if (fraud.isSuspicious) {
      // Show warning popup
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Row(
                children: [
                  Icon(LucideIcons.alertTriangle,
                      color: Colors.white, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Suspicious Activity Detected',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...fraud.warnings.map((warning) => Padding(
                    padding: const EdgeInsets.only(left: 32, bottom: 4),
                    child: Text(
                      '• $warning',
                      style: const TextStyle(fontSize: 12),
                    ),
                  )),
              const SizedBox(height: 4),
              const Padding(
                padding: EdgeInsets.only(left: 32),
                child: Text(
                  'Your report will be flagged for review.',
                  style: TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          action: SnackBarAction(
            label: 'Submit Anyway',
            textColor: Colors.white,
            onPressed: _submitReport,
          ),
        ),
      );
    } else {
      // No fraud detected, submit directly
      _submitReport();
    }
  }

  /// Maps YOLO-detected object names to PollutionType
  /// Must stay in sync with AIAnalysisService._mapAllPollutionTypes()
  PollutionType? _mapItemToType(String item) {
    const Map<String, PollutionType> objectToType = {
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

      // Vehicles (dumped/abandoned)
      'bicycle': PollutionType.debris,
      'car': PollutionType.debris,
      'motorcycle': PollutionType.debris,

      // Furniture
      'bench': PollutionType.debris,

      // Marine equipment
      'boat': PollutionType.fishingGear,
    };

    return objectToType[item.toLowerCase()];
  }

  Widget _buildPollutionTypeSelector(Color primaryColor, bool isDark) {
    return PollutionTypeSelector(
      selectedTypes: _selectedPollutionTypes,
      typeCounts: _typeCounts,
      onCountChanged: (type, newCount) {
        setState(() {
          if (newCount > 0) {
            _typeCounts[type] = newCount;
            // Auto-select type if count is > 0
            _selectedPollutionTypes.add(type);
          } else {
            _typeCounts.remove(type);
            // Auto-deselect type if count becomes 0
            _selectedPollutionTypes.remove(type);
          }
          // Recalculate severity when counts change
          _severity = PollutionCalculations.calculateSeverityHeuristic(
            typeCounts: _typeCounts,
            sceneLabels: _sceneLabels,
          );
        });
      },
      onTypeToggled: (type) {
        setState(() {
          if (_selectedPollutionTypes.contains(type)) {
            _selectedPollutionTypes.remove(type);
            // Clear count when deselected
            _typeCounts.remove(type);
          } else {
            _selectedPollutionTypes.add(type);
            // Set default count of 1 when selected
            _typeCounts[type] = _typeCounts[type] ?? 1;
          }
          // Recalculate severity when types change
          _severity = PollutionCalculations.calculateSeverityHeuristic(
            typeCounts: _typeCounts,
            sceneLabels: _sceneLabels,
          );
        });
      },
      isDark: isDark,
      primaryColor: primaryColor,
      showSummary: true, // Enable summary footer with weight/items
    );
  }
}

extension StringExtension on String {
  String capitalize() {
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}
