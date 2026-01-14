import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide ImageSource;
import 'package:geolocator/geolocator.dart' as geo;
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/logger.dart';
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

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  geo.Position? _currentPosition;
  bool _isLoadingLocation = true;
  MapboxMap? _mapboxMap;
  bool _mapReady = false;
  bool _initialLoadDone = false;
  bool _pinImagesAdded = false;
  String? _currentMapStyle;

  // Use ValueNotifier for selected marker to avoid full widget rebuilds
  final _selectedMarkerNotifier = ValueNotifier<MapMarkerData?>(null);

  // Save reference to provider to safely remove listener in dispose
  ReportsMapProvider? _reportsProvider;

  // Debounce timers for performance
  Timer? _markerUpdateDebounce;
  Timer? _viewportDebounce;
  static const _viewportBufferPercent = 0.3; // 30% buffer around viewport

  // Track last viewport to avoid redundant fetches
  double? _lastMinLat, _lastMaxLat, _lastMinLng, _lastMaxLng;
  int _lastZoomLevel = 10;

  // Cached pin images (generated once at startup)
  Map<String, Uint8List>? _cachedPinImages;

  // Mutex to prevent concurrent _renderMarkersWithClustering calls
  bool _isRenderingMarkers = false;

  // "Search this area" button state
  bool _showSearchAreaButton = false;
  Map<String, double>? _lastFetchedBounds;

  // Mapbox style: dynamic based on theme
  String get _mapStyle {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? MapboxStyles.DARK : MapboxStyles.LIGHT;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _getCurrentLocation();
    // Listen for provider updates to re-render markers
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _reportsProvider = context.read<ReportsMapProvider>();
      _reportsProvider!.addListener(_onMarkersUpdated);

      // Set current user ID for "My Reports" filtering
      final authProvider = context.read<AuthProvider>();
      _reportsProvider!.setCurrentUserId(authProvider.currentUser?.id);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      AppLogger.info('HomeScreen: App resumed, checking location...');
      // Re-get location if we don't have it (e.g., after returning from Settings)
      if (_currentPosition == null) {
        _getCurrentLocation();
      }
    }
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
      AppLogger.info('Updating map style to: $newStyle');
      _mapboxMap!.style.setStyleURI(newStyle).then((_) {
        if (!mounted) return;
        AppLogger.info('Style updated successfully');
        // Re-apply custom layers after style change
        _renderMarkersWithClustering();
        _updateWaterColor(isDark);
      }).catchError((e) {
        AppLogger.error('Error updating map style: $e');
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
      AppLogger.debug('Could not customize water color: $e');
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
      AppLogger.info('Pin marker images added to style');
    } catch (e) {
      AppLogger.error('Error adding pin images: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Use saved reference to avoid accessing deactivated context
    _reportsProvider?.removeListener(_onMarkersUpdated);
    _markerUpdateDebounce?.cancel();
    _viewportDebounce?.cancel();
    _selectedMarkerNotifier.dispose();
    super.dispose();
  }

  /// Debounced marker update handler for better performance
  void _onMarkersUpdated() {
    _markerUpdateDebounce?.cancel();
    _markerUpdateDebounce = Timer(const Duration(milliseconds: 100), () {
      if (_mapReady && mounted) {
        _renderMarkersWithClustering();
      }
    });
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
      AppLogger.error('Error getting location: $e');
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
        });
      }
    }
  }

  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;

    try {
      // Track initial style
      final isDark = Theme.of(context).brightness == Brightness.dark;
      _currentMapStyle = isDark ? MapboxStyles.DARK : MapboxStyles.LIGHT;

      AppLogger.info('Map created, initializing with style: $_currentMapStyle');

      // Disable scale bar ornament for cleaner UI
      await mapboxMap.scaleBar.updateSettings(ScaleBarSettings(enabled: false));

      // Enable user location puck (disable pulsing for performance on low-end devices)
      await mapboxMap.location.updateSettings(
        LocationComponentSettings(
          enabled: true,
          pulsingEnabled: false, // Disabled for performance
          puckBearingEnabled: true,
        ),
      );

      // Customize water color based on theme
      _updateWaterColor(isDark);

      // Pre-generate and cache pin images once
      _cachedPinImages ??= await MapPinGenerator.generateAllPins();

      // Add pin images to style
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

      _mapReady = true;
      AppLogger.info('Map ready, loading markers...');

      // Load initial viewport markers
      await _loadViewportMarkers();
    } catch (e, stackTrace) {
      AppLogger.error('Error initializing map: $e', e, stackTrace);
      // Still mark as ready so user can see something
      _mapReady = true;
    }
  }

  /// Load markers for the current viewport with buffer
  Future<void> _loadViewportMarkers() async {
    if (_mapboxMap == null || !_mapReady) {
      return;
    }

    try {
      // Get current camera state
      final cameraState = await _mapboxMap!.getCameraState();
      final zoomLevel = cameraState.zoom.toInt();

      // Get visible bounds
      final bounds = await _mapboxMap!.coordinateBoundsForCamera(
        CameraOptions(
          center: cameraState.center,
          zoom: cameraState.zoom,
          bearing: cameraState.bearing,
          pitch: cameraState.pitch,
        ),
      );

      // Calculate bounds with buffer for smoother panning
      final swLat = bounds.southwest.coordinates.lat.toDouble();
      final swLng = bounds.southwest.coordinates.lng.toDouble();
      final neLat = bounds.northeast.coordinates.lat.toDouble();
      final neLng = bounds.northeast.coordinates.lng.toDouble();

      final latRange = neLat - swLat;
      final lngRange = neLng - swLng;
      final latBuffer = latRange * _viewportBufferPercent;
      final lngBuffer = lngRange * _viewportBufferPercent;

      final minLat = swLat - latBuffer;
      final maxLat = neLat + latBuffer;
      final minLng = swLng - lngBuffer;
      final maxLng = neLng + lngBuffer;

      // Skip if viewport hasn't changed significantly
      if (_isViewportUnchanged(minLat, maxLat, minLng, maxLng, zoomLevel)) {
        return;
      }

      // Store viewport for comparison
      _lastMinLat = minLat;
      _lastMaxLat = maxLat;
      _lastMinLng = minLng;
      _lastMaxLng = maxLng;
      _lastZoomLevel = zoomLevel;

      // Store fetched bounds for "Search this area" button logic
      _lastFetchedBounds = {
        'minLat': minLat,
        'maxLat': maxLat,
        'minLng': minLng,
        'maxLng': maxLng,
      };

      // Load markers for this viewport
      if (!mounted) return;
      final provider = context.read<ReportsMapProvider>();
      await provider.loadMarkers(
        minLat: minLat,
        maxLat: maxLat,
        minLng: minLng,
        maxLng: maxLng,
        zoomLevel: zoomLevel,
      );

      // Render markers if this is the first load
      if (!_initialLoadDone) {
        _initialLoadDone = true;
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
    } catch (e) {
      AppLogger.warning('Error loading viewport markers: $e');
    }
  }

  /// Check if viewport has changed significantly enough to warrant a reload
  bool _isViewportUnchanged(
      double minLat, double maxLat, double minLng, double maxLng, int zoom) {
    if (_lastMinLat == null) return false;
    const threshold = 0.001; // ~100m at equator
    return (minLat - _lastMinLat!).abs() < threshold &&
        (maxLat - _lastMaxLat!).abs() < threshold &&
        (minLng - _lastMinLng!).abs() < threshold &&
        (maxLng - _lastMaxLng!).abs() < threshold &&
        zoom == _lastZoomLevel;
  }

  /// Render markers using GeoJSON source with native Mapbox clustering
  Future<void> _renderMarkersWithClustering() async {
    if (_mapboxMap == null || !mounted || _reportsProvider == null) {
      AppLogger.debug(
          'Cannot render markers: map not ready or provider not set');
      return;
    }

    // Prevent concurrent calls (race condition fix)
    if (_isRenderingMarkers) {
      AppLogger.debug('Already rendering markers, skipping');
      return;
    }
    _isRenderingMarkers = true;

    try {
      final markers = _reportsProvider!.filteredMarkers; // Use filtered markers

      AppLogger.info(
          'Setting up clustering for ${markers.length} markers (filtered)');

      // Remove layers in correct order (layers first, then source)
      // Use sequential removal to avoid race conditions
      final layersToRemove = [
        'unclustered-point',
        'cluster-count',
        'clusters',
        'cluster-glow',
      ];
      for (final layerId in layersToRemove) {
        try {
          await _mapboxMap!.style.removeStyleLayer(layerId);
        } catch (_) {
          // Layer doesn't exist, that's fine
        }
      }
      try {
        await _mapboxMap!.style.removeStyleSource('reports-source');
      } catch (_) {
        // Source doesn't exist, that's fine
      }

      if (markers.isEmpty) {
        AppLogger.info('No markers to display - cleared map');
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

      AppLogger.info('Clustering layers set up successfully');
    } catch (e) {
      AppLogger.error('Error setting up clustering: $e');
    } finally {
      _isRenderingMarkers = false;
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

        // Handle Mapbox's CastMap types by converting to standard Map
        final feature = Map<String, dynamic>.from(queriedFeature.feature);

        final geometryObj = feature['geometry'];
        if (geometryObj == null) return;
        final geometry = Map<String, dynamic>.from(geometryObj as Map);

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

        AppLogger.info('Zoomed into cluster at $lat, $lng (zoom: $newZoom)');
      }
    } catch (e) {
      AppLogger.warning('Error handling map tap: $e');
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

        // Handle Mapbox's CastMap types by converting to standard Map
        final feature = Map<String, dynamic>.from(queriedFeature.feature);

        final propertiesObj = feature['properties'];
        if (propertiesObj == null) return;
        final properties = Map<String, dynamic>.from(propertiesObj as Map);

        final markerId = properties['id']?.toString();
        if (markerId != null && mounted) {
          // Find matching marker in provider
          final provider = this.context.read<ReportsMapProvider>();
          final matchingMarker = provider.markers.firstWhere(
            (m) => m.id == markerId,
            orElse: () => provider.markers.first,
          );

          // Use ValueNotifier to avoid full widget rebuild
          _selectedMarkerNotifier.value = matchingMarker;
          AppLogger.info('Selected marker: ${matchingMarker.id}');
        }
      } else if (_selectedMarkerNotifier.value != null) {
        // Tapped on empty space - deselect
        _selectedMarkerNotifier.value = null;
      }
    } catch (e) {
      AppLogger.warning('Error querying markers: $e');
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

  /// Handle camera movement to show/hide "Search this area" button
  void _onCameraChanged(CameraChangedEventData data) {
    // Debounce camera changes
    _viewportDebounce?.cancel();
    _viewportDebounce = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted || _mapboxMap == null) return;

      try {
        final cameraState = await _mapboxMap!.getCameraState();
        final bounds = await _mapboxMap!.coordinateBoundsForCamera(
          CameraOptions(
            center: cameraState.center,
            zoom: cameraState.zoom,
            bearing: cameraState.bearing,
            pitch: cameraState.pitch,
          ),
        );

        final currentBounds = {
          'minLat': bounds.southwest.coordinates.lat.toDouble(),
          'maxLat': bounds.northeast.coordinates.lat.toDouble(),
          'minLng': bounds.southwest.coordinates.lng.toDouble(),
          'maxLng': bounds.northeast.coordinates.lng.toDouble(),
        };

        // Check if viewport moved significantly outside last fetched bounds
        final shouldShowButton = _isOutsideFetchedBounds(currentBounds);

        if (shouldShowButton != _showSearchAreaButton) {
          setState(() {
            _showSearchAreaButton = shouldShowButton;
          });
        }
      } catch (e) {
        AppLogger.debug('Error in camera changed handler: $e');
      }
    });
  }

  /// Check if >20% of current viewport is outside last fetched bounds
  bool _isOutsideFetchedBounds(Map<String, double> currentBounds) {
    if (_lastFetchedBounds == null) return false;

    final fetched = _lastFetchedBounds!;
    final current = currentBounds;

    // Calculate overlap percentage
    final overlapMinLat =
        current['minLat']!.clamp(fetched['minLat']!, fetched['maxLat']!);
    final overlapMaxLat =
        current['maxLat']!.clamp(fetched['minLat']!, fetched['maxLat']!);
    final overlapMinLng =
        current['minLng']!.clamp(fetched['minLng']!, fetched['maxLng']!);
    final overlapMaxLng =
        current['maxLng']!.clamp(fetched['minLng']!, fetched['maxLng']!);

    final currentArea = (current['maxLat']! - current['minLat']!) *
        (current['maxLng']! - current['minLng']!);
    final overlapArea = (overlapMaxLat - overlapMinLat).clamp(0.0, double.infinity) *
        (overlapMaxLng - overlapMinLng).clamp(0.0, double.infinity);

    if (currentArea <= 0) return false;

    final overlapPercentage = overlapArea / currentArea;

    // Show button if less than 80% of current viewport is covered by fetched area
    return overlapPercentage < 0.8;
  }

  /// Search for reports in the current viewport area
  Future<void> _searchThisArea() async {
    if (_mapboxMap == null) return;

    try {
      final cameraState = await _mapboxMap!.getCameraState();
      final zoomLevel = cameraState.zoom.toInt();

      final bounds = await _mapboxMap!.coordinateBoundsForCamera(
        CameraOptions(
          center: cameraState.center,
          zoom: cameraState.zoom,
          bearing: cameraState.bearing,
          pitch: cameraState.pitch,
        ),
      );

      // Calculate bounds with buffer
      final swLat = bounds.southwest.coordinates.lat.toDouble();
      final swLng = bounds.southwest.coordinates.lng.toDouble();
      final neLat = bounds.northeast.coordinates.lat.toDouble();
      final neLng = bounds.northeast.coordinates.lng.toDouble();

      final latRange = neLat - swLat;
      final lngRange = neLng - swLng;
      final latBuffer = latRange * _viewportBufferPercent;
      final lngBuffer = lngRange * _viewportBufferPercent;

      final minLat = swLat - latBuffer;
      final maxLat = neLat + latBuffer;
      final minLng = swLng - lngBuffer;
      final maxLng = neLng + lngBuffer;

      // Hide button and show loading state
      setState(() {
        _showSearchAreaButton = false;
      });

      // Update fetched bounds
      _lastFetchedBounds = {
        'minLat': minLat,
        'maxLat': maxLat,
        'minLng': minLng,
        'maxLng': maxLng,
      };

      // Also update viewport tracking
      _lastMinLat = minLat;
      _lastMaxLat = maxLat;
      _lastMinLng = minLng;
      _lastMaxLng = maxLng;
      _lastZoomLevel = zoomLevel;

      // Fetch reports for this area
      if (!mounted) return;
      final provider = context.read<ReportsMapProvider>();
      await provider.loadMarkers(
        minLat: minLat,
        maxLat: maxLat,
        minLng: minLng,
        maxLng: maxLng,
        zoomLevel: zoomLevel,
      );

      AppLogger.info('Searched area: $minLat,$minLng to $maxLat,$maxLng');
    } catch (e) {
      AppLogger.error('Error searching area: $e');
      // Show button again if search failed
      setState(() {
        _showSearchAreaButton = true;
      });
    }
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
                  onCameraChangeListener: _onCameraChanged,
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

          // "Search this area" button (appears when user pans to new area)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            top: _showSearchAreaButton
                ? MediaQuery.of(context).padding.top + 72
                : MediaQuery.of(context).padding.top + 40,
            left: 0,
            right: 0,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _showSearchAreaButton ? 1.0 : 0.0,
              child: IgnorePointer(
                ignoring: !_showSearchAreaButton,
                child: Center(
                  child: Material(
                    color: Colors.transparent,
                    child: ActionChip(
                      avatar: const Icon(
                        LucideIcons.refreshCw,
                        size: 16,
                      ),
                      label: const Text('Search this area'),
                      onPressed: _searchThisArea,
                      backgroundColor:
                          Theme.of(context).colorScheme.surface.withValues(alpha: 0.95),
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                      ),
                      elevation: 4,
                      shadowColor: Colors.black26,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Report Detail Card (bottom, above nav bar) - isolated rebuild
          ValueListenableBuilder<MapMarkerData?>(
            valueListenable: _selectedMarkerNotifier,
            builder: (context, selectedMarker, _) {
              if (selectedMarker == null) return const SizedBox.shrink();
              return Positioned(
                left: 0,
                right: 0,
                bottom: 105,
                child: ReportDetailCard(
                  marker: selectedMarker,
                  onClose: () {
                    _selectedMarkerNotifier.value = null;
                  },
                  onMarkRecovered: (reportId) async {
                    final provider = context.read<ReportsMapProvider>();
                    await provider.markAsRecovered(reportId);
                    // Update selected marker to reflect new status
                    final updated = provider.markers.firstWhere(
                      (m) => m.id == reportId,
                      orElse: () => selectedMarker,
                    );
                    _selectedMarkerNotifier.value = updated;
                  },
                ),
              );
            },
          ),

          // FAB Stack (bottom right, animates up when card appears)
          ValueListenableBuilder<MapMarkerData?>(
            valueListenable: _selectedMarkerNotifier,
            builder: (context, selectedMarker, child) {
              return AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                bottom: selectedMarker != null ? 600 : 131,
                right: 16,
                child: child!,
              );
            },
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
