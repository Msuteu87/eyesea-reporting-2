import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/logger.dart';
import '../../../core/utils/map_pin_generator.dart';
import '../../../domain/entities/report.dart';
import '../../providers/reports_map_provider.dart';

/// Handles marker rendering with native Mapbox clustering.
///
/// Extracts the 160+ line rendering logic from HomeScreen into a focused class.
class MapMarkerRenderer {
  final MapboxMap _map;

  /// Mutex to prevent concurrent render calls
  bool _isRendering = false;

  /// Track if pin images have been added to style
  bool _pinImagesAdded = false;

  /// Layer IDs used by the renderer
  static const _layerIds = [
    'unclustered-point',
    'cluster-count',
    'clusters',
    'cluster-glow',
  ];

  /// Source ID for marker data
  static const _sourceId = 'reports-source';

  MapMarkerRenderer(this._map);

  /// Render markers with native Mapbox clustering.
  ///
  /// Returns true if rendering completed, false if skipped (already rendering).
  Future<bool> renderMarkers(List<MapMarkerData> markers) async {
    // Prevent concurrent calls (race condition fix)
    if (_isRendering) {
      AppLogger.debug('Already rendering markers, skipping');
      return false;
    }
    _isRendering = true;

    try {
      AppLogger.info(
          'Setting up clustering for ${markers.length} markers (filtered)');

      // Remove existing layers and source
      await clearLayers();

      if (markers.isEmpty) {
        AppLogger.info('No markers to display - cleared map');
        return true;
      }

      // Build and add GeoJSON source with clustering
      final geoJson = _buildGeoJson(markers);
      await _map.style.addSource(
        GeoJsonSource(
          id: _sourceId,
          data: jsonEncode(geoJson),
          cluster: true,
          clusterRadius: 50,
          clusterMaxZoom: 14,
        ),
      );

      // Add cluster layers
      await _addClusterLayers();

      // Add individual marker layers
      await _addMarkerSymbolLayer();

      AppLogger.info('Clustering layers set up successfully');
      return true;
    } catch (e) {
      AppLogger.error('Error setting up clustering: $e');
      return false;
    } finally {
      _isRendering = false;
    }
  }

  /// Remove all marker layers and source from the map.
  Future<void> clearLayers() async {
    // Remove layers in correct order (layers first, then source)
    for (final layerId in _layerIds) {
      try {
        await _map.style.removeStyleLayer(layerId);
      } catch (_) {
        // Layer doesn't exist, that's fine
      }
    }
    try {
      await _map.style.removeStyleSource(_sourceId);
    } catch (_) {
      // Source doesn't exist, that's fine
    }
  }

  /// Build GeoJSON FeatureCollection from markers.
  Map<String, dynamic> _buildGeoJson(List<MapMarkerData> markers) {
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

    return {
      'type': 'FeatureCollection',
      'features': features,
    };
  }

  /// Add cluster circle layers (glow, main, count text).
  Future<void> _addClusterLayers() async {
    // Cluster outer glow (shadow effect)
    await _map.style.addLayer(
      CircleLayer(
        id: 'cluster-glow',
        sourceId: _sourceId,
        filter: <Object>['has', 'point_count'],
        circleColor: AppColors.electricNavy.withValues(alpha: 0.3).toARGB32(),
        circleRadius: 32.0,
        circleBlur: 1.0,
      ),
    );

    // Cluster main circle
    await _map.style.addLayer(
      CircleLayer(
        id: 'clusters',
        sourceId: _sourceId,
        filter: <Object>['has', 'point_count'],
        circleColor: AppColors.electricNavy.toARGB32(),
        circleRadius: 24.0,
        circleStrokeWidth: 3.0,
        circleStrokeColor: Colors.white.toARGB32(),
      ),
    );

    // Cluster count text
    await _map.style.addLayer(
      SymbolLayer(
        id: 'cluster-count',
        sourceId: _sourceId,
        filter: <Object>['has', 'point_count'],
        textField: '{point_count_abbreviated}',
        textSize: 13.0,
        textColor: Colors.white.toARGB32(),
      ),
    );
  }

  /// Add individual marker symbol layer with pin icons.
  Future<void> _addMarkerSymbolLayer() async {
    // Ensure pin images are added to style
    await _ensurePinImagesAdded();

    // Pin marker symbol layer
    await _map.style.addLayer(
      SymbolLayer(
        id: 'unclustered-point',
        sourceId: _sourceId,
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
    await _map.style.setStyleLayerProperty(
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
  }

  /// Generate and add pin marker images to the map style.
  Future<void> _ensurePinImagesAdded() async {
    if (_pinImagesAdded) return;

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
        await _map.style.addStyleImage(
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

  /// Reset pin images flag (call after style change)
  void resetPinImages() {
    _pinImagesAdded = false;
  }
}
