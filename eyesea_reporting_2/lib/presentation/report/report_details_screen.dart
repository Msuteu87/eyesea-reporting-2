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
import '../../core/utils/logger.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/services/report_queue_service.dart';
import '../../core/services/ai_analysis_service.dart';
import '../../core/services/geocoding_service.dart';
import '../../core/utils/pollution_calculations.dart';
import '../../domain/entities/report.dart';
import 'widgets/pollution_type_selector.dart';
import 'widgets/location_scene_card.dart';
import 'widgets/map_picker_bottom_sheet.dart';
import 'widgets/severity_selector.dart';
import 'widgets/report_summary_card.dart';
import 'widgets/report_image_header.dart';
import 'widgets/report_submit_button.dart';

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
      AppLogger.error('Error getting location: $e');
    }
  }

  Future<void> _reverseGeocode(double lat, double lng) async {
    String? city;
    String? country;

    // First try native Android/iOS geocoder
    try {
      final placemarks = await geocoding.placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        city = place.locality ??
            place.subAdministrativeArea ??
            place.administrativeArea;
        country = place.country;
        AppLogger.info('Native geocoding: city=$city, country=$country');
      }
    } catch (e) {
      AppLogger.debug('Native geocoding failed: $e');
    }

    // Fallback to Mapbox geocoding if city is missing
    if (city == null || city.isEmpty) {
      AppLogger.info('City missing, trying Mapbox geocoding...');
      try {
        final result = await GeocodingService.reverseGeocode(lat, lng);
        if (result != null) {
          // Parse city and country from Mapbox result
          // fullPlaceName format: "City, Region, Country"
          final parts = result.fullPlaceName.split(', ');
          if (parts.isNotEmpty) {
            city = result.placeName;
            if (parts.length > 1) {
              country ??= parts.last;
            }
          }
          AppLogger.info('Mapbox geocoding: city=$city, country=$country');
        }
      } catch (e) {
        AppLogger.debug('Mapbox geocoding failed: $e');
      }
    }

    if (mounted) {
      setState(() {
        _city = city;
        _country = country;
      });
      AppLogger.info('Final location: $_city, $_country');
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
            final type = PollutionCalculations.mapItemToPollutionType(entry.key);
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
              AppLogger.debug('Unknown pollution type: ${entry.key}');
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
      AppLogger.error('AI Analysis UI Error: $e');
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

      // Re-run reverse geocoding for new location using the improved method
      await _reverseGeocode(
        newLocation.coordinates.lat.toDouble(),
        newLocation.coordinates.lng.toDouble(),
      );
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
      AppLogger.error('Submit error: $e');
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
          ReportImageHeader(
            imageFile: _imageFile,
            onRetake: () => Navigator.pop(context),
            isDark: isDark,
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
                  ReportSubmitButton(
                    isSubmitting: _isSubmitting,
                    hasPeopleDetected: _hasPeopleDetected,
                    totalXP: PollutionCalculations.calculateXP(
                      typeCounts: _typeCounts,
                      severity: _severity,
                      hasLocation: _currentLocation != null,
                      hasPhoto: true,
                      sceneLabels: _sceneLabels,
                    ),
                    onSubmit: _handleSubmitWithFraudCheck,
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleSubmitWithFraudCheck() {
    // Check for fraud before submitting
    final fraud = PollutionCalculations.detectFraud(
      userCounts: _typeCounts,
      aiBaseline: _aiBaselineCounts,
      severity: _severity,
    );

    AppLogger.debug('Fraud Check: User counts: $_typeCounts, AI baseline: $_aiBaselineCounts, Fraud score: ${fraud.fraudScore}, Is suspicious: ${fraud.isSuspicious}, Warnings: ${fraud.warnings}');

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
