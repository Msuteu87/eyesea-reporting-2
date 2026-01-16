import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide ImageSource;
import 'package:geolocator/geolocator.dart' as geo;
import 'package:provider/provider.dart';

// TODO: [LIFECYCLE] Handle location permission changes while backgrounded
// Current: If user disables location in settings while app is backgrounded,
// _getCurrentLocation won't refresh and may provide stale coordinates
// Fix: Check permission status in didChangeAppLifecycleState resumed state

// TODO: [MEMORY] Verify MapboxMap cleanup in dispose
// Current: _mapboxMap reference may hold native resources
// Fix: Ensure all map listeners are removed and consider nullifying reference

import '../../core/utils/logger.dart';
import '../providers/auth_provider.dart';
import '../providers/reports_map_provider.dart';
import 'helpers/map_bounds_helper.dart';
import 'helpers/map_marker_renderer.dart';
import 'helpers/map_heatmap_renderer.dart';
import 'helpers/map_tap_handler.dart';
import 'helpers/viewport_bounds.dart';
import 'widgets/layer_filter_fab.dart';
import 'widgets/layer_filter_sheet.dart';
import 'widgets/home_filter_bar.dart';
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
  String? _currentMapStyle;
  MapMarkerRenderer? _markerRenderer;
  MapTapHandler? _tapHandler;

  // Use ValueNotifier for selected marker to avoid full widget rebuilds
  final _selectedMarkerNotifier = ValueNotifier<MapMarkerData?>(null);

  // Save reference to provider to safely remove listener in dispose
  ReportsMapProvider? _reportsProvider;

  // Debounce timers for performance
  Timer? _markerUpdateDebounce;
  Timer? _viewportDebounce;
  static const _viewportBufferPercent = 0.3; // 30% buffer around viewport

  // Track last viewport to avoid redundant fetches
  ViewportBounds? _lastViewportBounds;
  int _lastZoomLevel = 10;

  // "Search this area" button state
  bool _showSearchAreaButton = false;
  ViewportBounds? _lastFetchedBounds;

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
        // Reset pin images flag so they get re-added after style change
        _markerRenderer?.resetPinImages();
        // Re-apply custom layers after style change
        _renderMarkersWithClustering();
        _updateHeatmap(); // Re-apply heatmap layer
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

  MapHeatmapRenderer? _heatmapRenderer; // New

  // ...

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
        final isHeatmap = _reportsProvider?.isHeatmapEnabled ?? false;

        if (isHeatmap) {
          // In heatmap mode: Show heatmap, hide markers
          _updateHeatmap();
          _markerRenderer?.clearLayers(); // Ensure markers are gone
        } else {
          // In normal mode: Show markers, hide heatmap
          _renderMarkersWithClustering();
          _heatmapRenderer?.toggleHeatmap(false, []); // Ensure heatmap is gone
        }
      }
    });
  }

  // New method to handle heatmap updates
  Future<void> _updateHeatmap() async {
    if (_heatmapRenderer == null || !mounted || _reportsProvider == null) {
      return;
    }

    // Pass the actual enabled state. If this called, we are likely in heatmap mode,
    // but the renderer check handles the toggle logic.
    await _heatmapRenderer!.toggleHeatmap(
      _reportsProvider!.isHeatmapEnabled,
      _reportsProvider!.heatmapPoints,
    );
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

      // Initialize marker renderer and tap handler
      _markerRenderer = MapMarkerRenderer(mapboxMap);
      _heatmapRenderer = MapHeatmapRenderer(mapboxMap); // Initialize
      _tapHandler = MapTapHandler(mapboxMap);

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
      // Get bounds and zoom using helper
      final bounds = await MapBoundsHelper.getViewportBoundsWithBuffer(
        _mapboxMap!,
        buffer: _viewportBufferPercent,
      );
      final zoomLevel = await MapBoundsHelper.getZoomLevel(_mapboxMap!);

      // Skip if viewport hasn't changed significantly
      if (MapBoundsHelper.isViewportUnchanged(
        bounds,
        _lastViewportBounds,
        zoomLevel,
        _lastZoomLevel,
      )) {
        return;
      }

      // Store viewport for comparison
      _lastViewportBounds = bounds;
      _lastZoomLevel = zoomLevel;

      // Store fetched bounds for "Search this area" button logic
      _lastFetchedBounds = bounds;

      // Load markers for this viewport
      if (!mounted) return;
      final provider = context.read<ReportsMapProvider>();
      await provider.loadMarkers(
        minLat: bounds.minLat,
        maxLat: bounds.maxLat,
        minLng: bounds.minLng,
        maxLng: bounds.maxLng,
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

  /// Render markers using GeoJSON source with native Mapbox clustering
  Future<void> _renderMarkersWithClustering() async {
    if (_markerRenderer == null || !mounted || _reportsProvider == null) {
      AppLogger.debug(
          'Cannot render markers: renderer not ready or provider not set');
      return;
    }

    final markers = _reportsProvider!.filteredMarkers;
    final rendered = await _markerRenderer!.renderMarkers(markers);

    // Set tap listener after successful render
    if (rendered && _mapboxMap != null) {
      _mapboxMap!.setOnMapTapListener(_onMapTap);
    }
  }

  /// Handle map tap - if cluster is tapped, zoom in to expand it
  void _onMapTap(MapContentGestureContext context) async {
    if (_tapHandler == null) return;

    final screenPoint = context.touchPosition;

    // First, check if a cluster was tapped
    final clusterHandled = await _tapHandler!.handleClusterTap(screenPoint);
    if (clusterHandled) return;

    // Then, check if a marker was tapped
    final markerId = await _tapHandler!.queryMarkerAtPoint(screenPoint);
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
    } else if (_selectedMarkerNotifier.value != null) {
      // Tapped on empty space - deselect
      _selectedMarkerNotifier.value = null;
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

  /// Handle camera movement
  void _onCameraChanged(CameraChangedEventData data) {
    // Debounce camera changes
    _viewportDebounce?.cancel();
    _viewportDebounce = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted || _mapboxMap == null) return;

      try {
        final currentBounds =
            await MapBoundsHelper.getViewportBounds(_mapboxMap!);

        final provider = context.read<ReportsMapProvider>();

        if (provider.isHeatmapEnabled) {
          // Heatmap Mode: Automatically reload heatmap data for new viewport
          await provider.reloadHeatmapForViewport(
            minLat: currentBounds.minLat,
            maxLat: currentBounds.maxLat,
            minLng: currentBounds.minLng,
            maxLng: currentBounds.maxLng,
          );
          // Hide search button in heatmap mode
          if (_showSearchAreaButton) {
            setState(() {
              _showSearchAreaButton = false;
            });
          }
        } else {
          // Normal Mode: Check if we need to show "Search this area" button
          // Check if viewport moved significantly outside last fetched bounds
          final shouldShowButton = MapBoundsHelper.isOutsideFetchedBounds(
            currentBounds,
            _lastFetchedBounds,
          );

          if (shouldShowButton != _showSearchAreaButton) {
            setState(() {
              _showSearchAreaButton = shouldShowButton;
            });
          }
        }
      } catch (e) {
        AppLogger.debug('Error in camera changed handler: $e');
      }
    });
  }

  /// Search for reports in the current viewport area
  Future<void> _searchThisArea() async {
    if (_mapboxMap == null) return;

    try {
      // Get bounds and zoom using helper
      final bounds = await MapBoundsHelper.getViewportBoundsWithBuffer(
        _mapboxMap!,
        buffer: _viewportBufferPercent,
      );
      final zoomLevel = await MapBoundsHelper.getZoomLevel(_mapboxMap!);

      // Hide button and show loading state
      setState(() {
        _showSearchAreaButton = false;
      });

      // Update fetched bounds and viewport tracking
      _lastFetchedBounds = bounds;
      _lastViewportBounds = bounds;
      _lastZoomLevel = zoomLevel;

      // Fetch reports for this area
      if (!mounted) return;
      final provider = context.read<ReportsMapProvider>();
      await provider.loadMarkers(
        minLat: bounds.minLat,
        maxLat: bounds.maxLat,
        minLng: bounds.minLng,
        maxLng: bounds.maxLng,
        zoomLevel: zoomLevel,
      );

      AppLogger.info(
          'Searched area: ${bounds.minLat},${bounds.minLng} to ${bounds.maxLat},${bounds.maxLng}');
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

          // Filter Chips (below search bar)
          Positioned(
            top: MediaQuery.of(context).padding.top + 80,
            left: 0,
            right: 0,
            child: const HomeFilterBar(),
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
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .surface
                          .withValues(alpha: 0.95),
                      side: BorderSide(
                        color: Theme.of(context)
                            .colorScheme
                            .outline
                            .withValues(alpha: 0.3),
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
      isHeatmapEnabled: provider.isHeatmapEnabled,
    );
    if (result != null) {
      if (result.isHeatmapEnabled && !provider.isHeatmapEnabled) {
        // Heatmap was just enabled, zoom out to global view
        _mapboxMap?.flyTo(
          CameraOptions(
            center: Point(
                coordinates:
                    Position(0, 20)), // Centered roughly for global view
            zoom: 1.5,
            pitch: 0,
            bearing: 0,
          ),
          MapAnimationOptions(duration: 2000), // Smooth 2s animation
        );
      }

      provider.setVisibleStatuses(result.statuses);
      provider.setShowOnlyMyReports(result.showOnlyMyReports);
      provider.setHeatmapEnabled(result.isHeatmapEnabled);
    }
  }
}
