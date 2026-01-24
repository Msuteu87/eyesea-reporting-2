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
import '../social_feed/widgets/offline_banner.dart';

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
  // Start with severity 1 (Minor) for 1 default item; AI analysis will recalculate
  int _severity = 1;
  bool _isSubmitting = false;
  Point? _currentLocation;
  String? _city;
  String? _country;
  bool _isAnalyzing = false;
  List<String> _sceneLabels = [];
  bool _imageFileValid = true;

  late final File _imageFile;

  @override
  void initState() {
    super.initState();
    _imageFile = File(widget.imagePath);

    // Validate image file exists before proceeding
    if (!_imageFile.existsSync()) {
      _imageFileValid = false;
      AppLogger.error('Image file not found: ${widget.imagePath}');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(LucideIcons.imageOff, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text('Image not found. Please retake the photo.'),
                ),
              ],
            ),
            backgroundColor: Colors.orange.shade700,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
        // Navigate back to camera after showing message
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.pop(context);
        });
      });
      return;
    }

    _detectLocation();
    // Run analysis after build frame to access context providers safely
    WidgetsBinding.instance.addPostFrameCallback((_) => _analyzeImage());
  }

  @override
  void dispose() {
    super.dispose();
  }

  bool _isLocationLoading = false;

  Future<void> _detectLocation() async {
    if (_isLocationLoading) return;

    setState(() {
      _isLocationLoading = true;
    });

    try {
      // Check and request permission
      var permission = await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
        if (permission == geo.LocationPermission.denied) {
          _handleLocationError('Location permission denied');
          return;
        }
      }

      if (permission == geo.LocationPermission.deniedForever) {
        _handleLocationError(
            'Location permission permanently denied. Please enable in Settings.');
        return;
      }

      // Step 1: Try last known location first (instant fallback)
      final lastKnown = await geo.Geolocator.getLastKnownPosition();
      if (lastKnown != null && mounted) {
        AppLogger.info('Using last known location as initial fallback');
        setState(() {
          _currentLocation = Point(
            coordinates: Position(lastKnown.longitude, lastKnown.latitude),
          );
        });
        // Start reverse geocoding in background (will skip if offline)
        _reverseGeocodeIfOnline(lastKnown.latitude, lastKnown.longitude);
      }

      // Step 2: Get fresh GPS position with extended timeout
      // Use medium accuracy for faster acquisition (50-200m)
      // Timeout at 90 seconds for cold start GPS without A-GPS
      final position = await geo.Geolocator.getCurrentPosition(
        locationSettings: geo.AndroidSettings(
          accuracy: geo.LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 90),
          forceLocationManager: false,
        ),
      ).timeout(
        const Duration(seconds: 90),
        onTimeout: () async {
          // If fresh GPS times out but we have last known, use that
          if (_currentLocation != null) {
            AppLogger.info('GPS timeout - using last known location');
            return geo.Position(
              latitude: _currentLocation!.coordinates.lat.toDouble(),
              longitude: _currentLocation!.coordinates.lng.toDouble(),
              timestamp: DateTime.now(),
              accuracy: 500, // Mark as approximate
              altitude: 0,
              altitudeAccuracy: 0,
              heading: 0,
              headingAccuracy: 0,
              speed: 0,
              speedAccuracy: 0,
            );
          }
          throw Exception('GPS timeout');
        },
      );

      if (mounted) {
        setState(() {
          _currentLocation = Point(
            coordinates: Position(position.longitude, position.latitude),
          );
          _isLocationLoading = false;
        });

        // Reverse geocode in background (will skip if offline)
        _reverseGeocodeIfOnline(position.latitude, position.longitude);
      }
    } catch (e) {
      AppLogger.error('Error getting location: $e');
      _handleLocationError(e.toString());
    }
  }

  void _handleLocationError(String error) {
    if (!mounted) return;

    setState(() {
      _isLocationLoading = false;
    });

    if (_currentLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(LucideIcons.mapPinOff, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text('Could not get location. Tap to set manually.'),
              ),
            ],
          ),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Set Location',
            textColor: Colors.white,
            onPressed: _showManualLocationPicker,
          ),
        ),
      );
    }
  }

  /// Show manual location picker when GPS fails
  Future<void> _showManualLocationPicker() async {
    // Default to a central location if no GPS available
    const defaultLat = 0.0;
    const defaultLng = 0.0;

    final newLocation = await MapPickerBottomSheet.show(
      context,
      latitude: _currentLocation?.coordinates.lat.toDouble() ?? defaultLat,
      longitude: _currentLocation?.coordinates.lng.toDouble() ?? defaultLng,
      city: _city,
      country: _country,
    );

    if (newLocation != null && mounted) {
      setState(() {
        _currentLocation = newLocation;
      });

      // Try reverse geocoding for the manually selected location
      _reverseGeocodeIfOnline(
        newLocation.coordinates.lat.toDouble(),
        newLocation.coordinates.lng.toDouble(),
      );
    }
  }

  /// Reverse geocode only if online, otherwise skip (coordinates are sufficient)
  Future<void> _reverseGeocodeIfOnline(double lat, double lng) async {
    final connectivityService = context.read<ConnectivityService>();
    if (!connectivityService.isOnline) {
      AppLogger.info('Offline - skipping reverse geocoding, coordinates saved');
      return;
    }
    await _reverseGeocode(lat, lng);
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
  // Initialize with default count of 1 for the default selected type (plastic)
  // This ensures the impact card shows correctly before AI analysis completes
  Map<PollutionType, int> _typeCounts = {PollutionType.plastic: 1};
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
            final type =
                PollutionCalculations.mapItemToPollutionType(entry.key);
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

  /// Validates that coordinates are reasonable (not at 0,0 null island)
  bool _isValidLocation(double lat, double lng) {
    // Check for null island (0,0) - common GPS failure default
    if (lat.abs() < 0.01 && lng.abs() < 0.01) {
      return false;
    }
    // Check for valid coordinate ranges
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
      return false;
    }
    return true;
  }

  Future<void> _submitReport() async {
    if (_currentLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(LucideIcons.mapPinOff, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Expanded(child: Text('Location required. Please set your location.')),
            ],
          ),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Set Location',
            textColor: Colors.white,
            onPressed: _showManualLocationPicker,
          ),
        ),
      );
      return;
    }

    // Validate coordinates are not at null island (0,0) or invalid
    final lat = _currentLocation!.coordinates.lat.toDouble();
    final lng = _currentLocation!.coordinates.lng.toDouble();
    if (!_isValidLocation(lat, lng)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(LucideIcons.alertTriangle, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text('Invalid location detected. Please set your location manually.'),
              ),
            ],
          ),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Set Location',
            textColor: Colors.white,
            onPressed: _showManualLocationPicker,
          ),
        ),
      );
      return;
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

    // Show loading state if image file is invalid (will auto-navigate back)
    if (!_imageFileValid) {
      return Scaffold(
        backgroundColor: isDark ? AppColors.deepNavy : Colors.grey[50],
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.imageOff,
                size: 64,
                color: isDark ? Colors.white54 : Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'Image not found',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: isDark ? Colors.white70 : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Returning to camera...',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark ? Colors.white54 : Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      );
    }

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

          // Offline Banner
          SliverToBoxAdapter(
            child: Consumer<ConnectivityService>(
              builder: (context, connectivity, _) {
                if (connectivity.isOnline) return const SizedBox.shrink();
                return const OfflineBanner();
              },
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

    AppLogger.debug(
        'Fraud Check: User counts: $_typeCounts, AI baseline: $_aiBaselineCounts, Fraud score: ${fraud.fraudScore}, Is suspicious: ${fraud.isSuspicious}, Warnings: ${fraud.warnings}');

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
