import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide ImageSource;
import 'package:geolocator/geolocator.dart' as geo;
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/map_pin_generator.dart';
import '../../domain/entities/report.dart';
import '../providers/auth_provider.dart';
import '../providers/reports_map_provider.dart';
import 'widgets/layer_filter_fab.dart';
import 'widgets/layer_filter_sheet.dart';
import 'widgets/map_search_bar.dart';
import 'widgets/my_location_fab.dart';
import 'widgets/report_detail_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  geo.Position? _currentPosition;
  bool _isLoadingLocation = true;
  MapboxMap? _mapboxMap;
  bool _mapReady = false;
  bool _initialLoadDone = false;
  bool _pinImagesAdded = false;
  MapMarkerData? _selectedMarker;
  String? _currentMapStyle;

  // Mapbox style: dynamic based on theme
  String get _mapStyle {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? MapboxStyles.DARK : MapboxStyles.LIGHT;
  }

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    // Listen for provider updates to re-render markers
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final reportsProvider = context.read<ReportsMapProvider>();
      reportsProvider.addListener(_onMarkersUpdated);

      // Set current user ID for "My Reports" filtering
      final authProvider = context.read<AuthProvider>();
      reportsProvider.setCurrentUserId(authProvider.currentUser?.id);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Delay style update to after the current frame to avoid conflicts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateMapStyleIfNeeded();
    });
  }

  /// Update map style when theme changes
  void _updateMapStyleIfNeeded() {
    if (!mounted || _mapboxMap == null || !_mapReady) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final newStyle = isDark ? MapboxStyles.DARK : MapboxStyles.LIGHT;

    if (_currentMapStyle != newStyle) {
      _currentMapStyle = newStyle;
      _mapboxMap!.style.setStyleURI(newStyle).then((_) {
        if (!mounted) return;
        // Re-apply custom layers after style change
        _renderMarkersWithClustering();
        _updateWaterColor(isDark);
      });
    }
  }

  /// Update water color based on theme
  void _updateWaterColor(bool isDark) {
    try {
      final waterColor = isDark ? '#1a3a4a' : '#9fb8c8';
      _mapboxMap?.style
          .setStyleLayerProperty('water', 'fill-color', waterColor);
    } catch (e) {
      debugPrint('Could not customize water color: $e');
    }
  }

  /// Generate and add pin marker images to the map style
  Future<void> _addPinImagesToStyle() async {
    if (_mapboxMap == null || _pinImagesAdded) return;

    try {
      // Generate all pin variants
      final pins = await MapPinGenerator.generateAllPins();

      // Add each pin image to the map style
      for (final entry in pins.entries) {
        final imageData = MbxImage(
          width: MapPinGenerator.pinWidth.toInt(),
          height: MapPinGenerator.pinHeight.toInt(),
          data: entry.value,
        );
        await _mapboxMap!.style.addStyleImage(
          entry.key,
          1.0, // scale
          imageData,
          false, // sdf
          [], // stretch X
          [], // stretch Y
          null, // content
        );
      }

      _pinImagesAdded = true;
      debugPrint('📍 Pin marker images added to style');
    } catch (e) {
      debugPrint('❌ Error adding pin images: $e');
    }
  }

  @override
  void dispose() {
    context.read<ReportsMapProvider>().removeListener(_onMarkersUpdated);
    super.dispose();
  }

  void _onMarkersUpdated() {
    if (_mapReady && mounted) {
      _renderMarkersWithClustering();
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await geo.Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _currentPosition = position;
          _isLoadingLocation = false;
        });
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
        });
      }
    }
  }

  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;

    // Track initial style
    final isDark = Theme.of(context).brightness == Brightness.dark;
    _currentMapStyle = isDark ? MapboxStyles.DARK : MapboxStyles.LIGHT;

    // Disable scale bar ornament for cleaner UI
    await mapboxMap.scaleBar.updateSettings(ScaleBarSettings(enabled: false));

    // Enable user location puck
    await mapboxMap.location.updateSettings(
      LocationComponentSettings(
        enabled: true,
        pulsingEnabled: true,
        puckBearingEnabled: true,
      ),
    );

    // Customize water color based on theme
    _updateWaterColor(isDark);

    // Generate and add pin marker images
    await _addPinImagesToStyle();

    // If we have location, fly to it
    if (_currentPosition != null) {
      await mapboxMap.flyTo(
        CameraOptions(
          center: Point(
            coordinates: Position(
              _currentPosition!.longitude,
              _currentPosition!.latitude,
            ),
          ),
          zoom: 15.0,
        ),
        MapAnimationOptions(duration: 1000),
      );
    }

    // No longer using CircleAnnotationManager for clustering
    // GeoJSON source + layers will be added in _setupClusterLayers

    _mapReady = true;

    // Load and display all markers
    await _loadAllMarkers();
  }

  /// Load all markers (no viewport filtering for now - simplify)
  Future<void> _loadAllMarkers() async {
    if (_initialLoadDone) return; // Only load once on init
    _initialLoadDone = true;

    final provider = context.read<ReportsMapProvider>();
    await provider.loadMarkers(); // Load all, no bounds
    await _renderMarkersWithClustering();

    // If we have markers but no GPS, fly to first marker
    if (_currentPosition == null && provider.markers.isNotEmpty) {
      final first = provider.markers.first;
      await _mapboxMap?.flyTo(
        CameraOptions(
          center: Point(
            coordinates: Position(first.longitude, first.latitude),
          ),
          zoom: 12.0,
        ),
        MapAnimationOptions(duration: 1500),
      );
    }
  }

  /// Render markers using GeoJSON source with native Mapbox clustering
  Future<void> _renderMarkersWithClustering() async {
    if (_mapboxMap == null || !mounted) {
      debugPrint('📍 Cannot render markers: map not ready');
      return;
    }

    final provider = context.read<ReportsMapProvider>();
    final markers = provider.filteredMarkers; // Use filtered markers

    debugPrint(
        '📍 Setting up clustering for ${markers.length} markers (filtered)');

    // Always remove existing layers first (even if no markers to display)
    try {
      await _mapboxMap!.style.removeStyleLayer('unclustered-point');
    } catch (_) {}
    try {
      await _mapboxMap!.style.removeStyleLayer('cluster-count');
    } catch (_) {}
    try {
      await _mapboxMap!.style.removeStyleLayer('clusters');
    } catch (_) {}
    try {
      await _mapboxMap!.style.removeStyleLayer('cluster-glow');
    } catch (_) {}
    try {
      await _mapboxMap!.style.removeStyleSource('reports-source');
    } catch (_) {}

    if (markers.isEmpty) {
      debugPrint('📍 No markers to display - cleared map');
      return;
    }

    // Build GeoJSON FeatureCollection
    final features = markers
        .map((m) => {
              'type': 'Feature',
              'geometry': {
                'type': 'Point',
                'coordinates': [m.longitude, m.latitude],
              },
              'properties': {
                'id': m.id,
                'severity': m.severity,
                'isPending': m.isPending,
                'isResolved': m.status == ReportStatus.resolved,
              },
            })
        .toList();

    final geoJson = {
      'type': 'FeatureCollection',
      'features': features,
    };

    try {
      // Add GeoJSON source with clustering enabled
      await _mapboxMap!.style.addSource(
        GeoJsonSource(
          id: 'reports-source',
          data: jsonEncode(geoJson),
          cluster: true,
          clusterRadius: 50,
          clusterMaxZoom: 14,
        ),
      );

      // === CLUSTER LAYERS ===

      // Cluster outer glow (shadow effect)
      await _mapboxMap!.style.addLayer(
        CircleLayer(
          id: 'cluster-glow',
          sourceId: 'reports-source',
          filter: <Object>['has', 'point_count'],
          circleColor: AppColors.electricNavy.withValues(alpha: 0.3).toARGB32(),
          circleRadius: 32.0,
          circleBlur: 1.0,
        ),
      );

      // Cluster main circle
      await _mapboxMap!.style.addLayer(
        CircleLayer(
          id: 'clusters',
          sourceId: 'reports-source',
          filter: <Object>['has', 'point_count'],
          circleColor: AppColors.electricNavy.toARGB32(),
          circleRadius: 24.0,
          circleStrokeWidth: 3.0,
          circleStrokeColor: Colors.white.toARGB32(),
        ),
      );

      // Cluster count text
      await _mapboxMap!.style.addLayer(
        SymbolLayer(
          id: 'cluster-count',
          sourceId: 'reports-source',
          filter: <Object>['has', 'point_count'],
          textField: '{point_count_abbreviated}',
          textSize: 13.0,
          textColor: Colors.white.toARGB32(),
        ),
      );

      // === INDIVIDUAL MARKER LAYERS (Pin Style) ===

      // Ensure pin images are added to style
      await _addPinImagesToStyle();

      // Pin marker symbol layer
      await _mapboxMap!.style.addLayer(
        SymbolLayer(
          id: 'unclustered-point',
          sourceId: 'reports-source',
          filter: <Object>[
            '!',
            <Object>['has', 'point_count']
          ],
          iconAllowOverlap: true,
          iconIgnorePlacement: true,
          iconSize: 0.8,
          iconAnchor: IconAnchor.BOTTOM,
        ),
      );

      // Set icon-image based on status (red for reported, green for recovered)
      await _mapboxMap!.style.setStyleLayerProperty(
        'unclustered-point',
        'icon-image',
        [
          'case',
          ['get', 'isResolved'],
          'pin-recovered', // Green pin for recovered
          ['get', 'isPending'],
          'pin-pending', // Amber pin for pending
          'pin-reported', // Red pin for active/reported
        ],
      );

      // Add tap listener for cluster expansion (spiderfying)
      _mapboxMap!.setOnMapTapListener(_onMapTap);

      debugPrint('📍 Clustering layers set up successfully');
    } catch (e) {
      debugPrint('❌ Error setting up clustering: $e');
    }
  }

  /// Handle map tap - if cluster is tapped, zoom in to expand it
  void _onMapTap(MapContentGestureContext context) async {
    final screenPoint = context.touchPosition;

    if (_mapboxMap == null) return;

    try {
      // Query rendered features at tap point
      final features = await _mapboxMap!.queryRenderedFeatures(
        RenderedQueryGeometry.fromScreenCoordinate(screenPoint),
        RenderedQueryOptions(layerIds: ['clusters']),
      );

      if (features.isNotEmpty) {
        // Tapped on a cluster - zoom in to expand
        final cluster = features.first;
        final queriedFeature = cluster?.queriedFeature;
        if (queriedFeature == null) return;
        final feature = queriedFeature.feature as Map<String, dynamic>;

        final geometry = feature['geometry'] as Map<String, dynamic>?;
        if (geometry == null) return;

        final coords = geometry['coordinates'] as List?;
        if (coords == null || coords.length < 2) return;

        final lng = (coords[0] as num).toDouble();
        final lat = (coords[1] as num).toDouble();

        // Get current zoom and increase by 2
        final cameraState = await _mapboxMap!.getCameraState();
        final newZoom = (cameraState.zoom + 2).clamp(0.0, 20.0);

        await _mapboxMap!.flyTo(
          CameraOptions(
            center: Point(coordinates: Position(lng, lat)),
            zoom: newZoom,
          ),
          MapAnimationOptions(duration: 500),
        );

        debugPrint('📍 Zoomed into cluster at $lat, $lng (zoom: $newZoom)');
      }
    } catch (e) {
      debugPrint('⚠️ Error handling map tap: $e');
    }

    // Also query individual markers (unclustered-point layer)
    try {
      final markerFeatures = await _mapboxMap!.queryRenderedFeatures(
        RenderedQueryGeometry.fromScreenCoordinate(screenPoint),
        RenderedQueryOptions(layerIds: ['unclustered-point']),
      );

      if (markerFeatures.isNotEmpty) {
        final marker = markerFeatures.first;
        final queriedFeature = marker?.queriedFeature;
        if (queriedFeature == null) return;

        // Handle Mapbox's CastMap types by checking type first
        final featureObj = queriedFeature.feature;

        final propertiesObj = featureObj['properties'];
        if (propertiesObj is! Map) return;

        final markerId = propertiesObj['id']?.toString();
        if (markerId != null) {
          // Find matching marker in provider
          final provider = this.context.read<ReportsMapProvider>();
          final matchingMarker = provider.markers.firstWhere(
            (m) => m.id == markerId,
            orElse: () => provider.markers.first,
          );

          if (mounted) {
            setState(() {
              _selectedMarker = matchingMarker;
            });
          }
          debugPrint('📍 Selected marker: ${matchingMarker.id}');
        }
      } else if (_selectedMarker != null && mounted) {
        // Tapped on empty space - deselect
        setState(() {
          _selectedMarker = null;
        });
      }
    } catch (e) {
      debugPrint('⚠️ Error querying markers: $e');
    }
  }

  /// Fly camera to user's current location
  Future<void> _flyToUserLocation() async {
    if (_mapboxMap == null || _currentPosition == null) return;

    await _mapboxMap!.flyTo(
      CameraOptions(
        center: Point(
          coordinates: Position(
            _currentPosition!.longitude,
            _currentPosition!.latitude,
          ),
        ),
        zoom: 15.0,
      ),
      MapAnimationOptions(duration: 1000),
    );
  }

  /// Fly to a specific location (from search)
  Future<void> _flyToLocation(double latitude, double longitude) async {
    if (_mapboxMap == null) return;

    await _mapboxMap!.flyTo(
      CameraOptions(
        center: Point(
          coordinates: Position(longitude, latitude),
        ),
        zoom: 12.0,
      ),
      MapAnimationOptions(duration: 1000),
    );
  }

  @override
  Widget build(BuildContext context) {
    final initialCamera = CameraOptions(
      center: Point(
        coordinates: Position(
          _currentPosition?.longitude ?? 0.0,
          _currentPosition?.latitude ?? 0.0,
        ),
      ),
      zoom: _currentPosition != null ? 15.0 : 2.0,
    );

    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Map Layer
          _isLoadingLocation
              ? const Center(child: CircularProgressIndicator())
              : MapWidget(
                  key: const ValueKey('mapWidget'),
                  cameraOptions: initialCamera,
                  styleUri: _mapStyle,
                  onMapCreated: _onMapCreated,
                ),

          // Floating search bar with user avatar (top)
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            right: 16,
            child: MapSearchBar(
              onLocationSelected: _flyToLocation,
            ),
          ),

          // Report Detail Card (bottom, above nav bar)
          if (_selectedMarker != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 105,
              child: ReportDetailCard(
                marker: _selectedMarker!,
                imageUrl: _selectedMarker!.imageUrl,
                onClose: () {
                  if (mounted) {
                    setState(() {
                      _selectedMarker = null;
                    });
                  }
                },
                onMarkRecovered: (reportId) async {
                  final provider = context.read<ReportsMapProvider>();
                  await provider.markAsRecovered(reportId);
                  // Update selected marker to reflect new status
                  if (mounted) {
                    final updated = provider.markers.firstWhere(
                      (m) => m.id == reportId,
                      orElse: () => _selectedMarker!,
                    );
                    setState(() {
                      _selectedMarker = updated;
                    });
                  }
                },
              ),
            ),

          // FAB Stack (bottom right, animates up when card appears)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            bottom: _selectedMarker != null ? 266 : 131,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Layer Filter FAB
                LayerFilterFab(
                  onPressed: () => _showLayerFilterSheet(context),
                ),
                const SizedBox(height: 12),
                // My Location FAB
                MyLocationFab(onPressed: _flyToUserLocation),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Show layer filter bottom sheet
  Future<void> _showLayerFilterSheet(BuildContext context) async {
    final provider = context.read<ReportsMapProvider>();
    final result = await LayerFilterSheet.show(
      context,
      currentStatuses: provider.visibleStatuses,
      showOnlyMyReports: provider.showOnlyMyReports,
    );
    if (result != null) {
      provider.setVisibleStatuses(result.statuses);
      provider.setShowOnlyMyReports(result.showOnlyMyReports);
    }
  }
}
