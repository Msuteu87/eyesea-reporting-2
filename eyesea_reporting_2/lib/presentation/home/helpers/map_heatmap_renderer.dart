import 'dart:convert';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../../../core/utils/logger.dart';
import '../../../domain/entities/heatmap_point.dart';

/// Handles heatmap rendering with native Mapbox Heatmap Layer.
class MapHeatmapRenderer {
  final MapboxMap _map;
  bool _isRendering = false;

  static const _sourceId = 'heatmap-source';
  static const _layerId = 'heatmap-layer';

  MapHeatmapRenderer(this._map);

  /// Toggle heatmap visibility
  Future<void> toggleHeatmap(bool visible, List<HeatmapPoint> points) async {
    if (_isRendering) return;
    _isRendering = true;

    try {
      if (visible) {
        await _showHeatmap(points);
      } else {
        await _hideHeatmap();
      }
    } catch (e) {
      AppLogger.error('Error toggling heatmap: $e');
    } finally {
      _isRendering = false;
    }
  }

  Future<void> _showHeatmap(List<HeatmapPoint> points) async {
    AppLogger.info('Showing global heatmap with ${points.length} points');

    if (points.isEmpty) {
      AppLogger.warning('No heatmap points to display');
      return;
    }

    // Log sample points for debugging
    final sample = points
        .take(3)
        .map((p) => '(${p.latitude.toStringAsFixed(2)}, '
            '${p.longitude.toStringAsFixed(2)}, w=${p.weight})')
        .join(', ');
    AppLogger.debug('Sample heatmap points: $sample');

    // 1. Prepare GeoJSON
    final features = points
        .map((p) => {
              'type': 'Feature',
              'geometry': {
                'type': 'Point',
                'coordinates': [p.longitude, p.latitude],
              },
              'properties': {
                'weight': p.weight, // 0.0 to 1.0 based on severity
              },
            })
        .toList();

    final geoJson = {
      'type': 'FeatureCollection',
      'features': features,
    };

    // 2. Add Source (remove existing first)
    try {
      if (await _map.style.styleSourceExists(_sourceId)) {
        await _map.style.removeStyleSource(_sourceId);
      }
      await _map.style.addSource(
        GeoJsonSource(
          id: _sourceId,
          data: jsonEncode(geoJson),
        ),
      );
      AppLogger.debug('Heatmap source added with ${features.length} features');
    } catch (e) {
      AppLogger.warning('Error adding heatmap source: $e');
      return;
    }

    // 3. Add Heatmap Layer with proper expressions
    try {
      if (await _map.style.styleLayerExists(_layerId)) {
        await _map.style.removeStyleLayer(_layerId);
      }

      // Heatmap color expression: interpolate based on heatmap-density
      // Transparent at 0 for smooth edges, red at max density
      final heatmapColorExpr = <Object>[
        'interpolate',
        ['linear'],
        ['heatmap-density'],
        0,
        'rgba(33, 102, 172, 0)', // Transparent blue at 0
        0.2,
        'rgb(103, 169, 207)', // Light blue
        0.4,
        'rgb(209, 229, 240)', // Very light blue
        0.6,
        'rgb(253, 219, 199)', // Light orange
        0.8,
        'rgb(239, 138, 98)', // Orange
        1,
        'rgb(178, 24, 43)', // Red at max density
      ];

      // Radius expression: larger at low zoom for visibility at global view
      final heatmapRadiusExpr = <Object>[
        'interpolate',
        ['linear'],
        ['zoom'],
        0,
        2, // 2px at zoom 0
        1,
        4, // 4px at zoom 1
        3,
        10, // 10px at zoom 3
        6,
        20, // 20px at zoom 6
        10,
        30, // 30px at zoom 10
        15,
        40, // 40px at zoom 15
      ];

      // Intensity expression: higher at low zoom to show sparse points
      final heatmapIntensityExpr = <Object>[
        'interpolate',
        ['linear'],
        ['zoom'],
        0,
        3, // High intensity at global view
        3,
        2,
        6,
        1.5,
        10,
        1, // Normal intensity at street level
      ];

      // Weight expression: use the weight property from features
      final heatmapWeightExpr = <Object>[
        'get',
        'weight',
      ];

      await _map.style.addLayer(
        HeatmapLayer(
          id: _layerId,
          sourceId: _sourceId,
          maxZoom: 15, // Fade out heatmap at high zoom
          heatmapColorExpression: heatmapColorExpr,
          heatmapRadiusExpression: heatmapRadiusExpr,
          heatmapIntensityExpression: heatmapIntensityExpr,
          heatmapWeightExpression: heatmapWeightExpr,
          heatmapOpacity: 0.8,
        ),
      );
      AppLogger.info('Heatmap layer added successfully');
    } catch (e) {
      AppLogger.error('Error adding heatmap layer: $e');
    }
  }

  Future<void> _hideHeatmap() async {
    AppLogger.info('Hiding global heatmap');
    try {
      if (await _map.style.styleLayerExists(_layerId)) {
        await _map.style.removeStyleLayer(_layerId);
      }
      if (await _map.style.styleSourceExists(_sourceId)) {
        await _map.style.removeStyleSource(_sourceId);
      }
    } catch (e) {
      AppLogger.warning('Error removing heatmap: $e');
    }
  }
}
