import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/logger.dart';
import '../../providers/reports_map_provider.dart';

/// Mixin that provides Mapbox clustering functionality for map screens.
/// Handles GeoJSON source creation, layer setup, and cluster tap interactions.
mixin MapClusteringMixin<T extends StatefulWidget> on State<T> {
  MapboxMap? mapboxMap;

  /// Set up clustering layers using GeoJSON source
  Future<void> setupClusteringLayers(List<MapMarkerData> markers) async {
    if (mapboxMap == null || !mounted) {
      AppLogger.debug('Cannot render markers: map not ready');
      return;
    }

    AppLogger.info('Setting up clustering for ${markers.length} markers');

    if (markers.isEmpty) {
      AppLogger.info('No markers to display');
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
              },
            })
        .toList();

    final geoJson = {
      'type': 'FeatureCollection',
      'features': features,
    };

    try {
      // Remove existing layers first (must remove before source)
      try {
        await mapboxMap!.style.removeStyleLayer('clusters');
      } catch (_) {}
      try {
        await mapboxMap!.style.removeStyleLayer('cluster-count');
      } catch (_) {}
      try {
        await mapboxMap!.style.removeStyleLayer('unclustered-point');
      } catch (_) {}
      // Then remove source
      try {
        await mapboxMap!.style.removeStyleSource('reports-source');
      } catch (_) {}

      // Add GeoJSON source with clustering enabled
      await mapboxMap!.style.addSource(
        GeoJsonSource(
          id: 'reports-source',
          data: jsonEncode(geoJson),
          cluster: true,
          clusterRadius: 50,
          clusterMaxZoom: 14,
        ),
      );

      // Cluster circles layer - size based on point count
      await mapboxMap!.style.addLayer(
        CircleLayer(
          id: 'clusters',
          sourceId: 'reports-source',
          filter: <Object>['has', 'point_count'],
          circleColor: AppColors.oceanBlue.toARGB32(),
          circleRadius: 25.0,
          circleStrokeWidth: 3.0,
          circleStrokeColor: Colors.white.toARGB32(),
        ),
      );

      // Cluster count text layer
      await mapboxMap!.style.addLayer(
        SymbolLayer(
          id: 'cluster-count',
          sourceId: 'reports-source',
          filter: <Object>['has', 'point_count'],
          textField: '{point_count_abbreviated}',
          textSize: 14.0,
          textColor: Colors.white.toARGB32(),
        ),
      );

      // Unclustered points layer (individual markers at high zoom)
      await mapboxMap!.style.addLayer(
        CircleLayer(
          id: 'unclustered-point',
          sourceId: 'reports-source',
          filter: <Object>[
            '!',
            <Object>['has', 'point_count']
          ],
          circleColor: AppColors.oceanBlue.toARGB32(),
          circleRadius: 10.0,
          circleStrokeWidth: 2.0,
          circleStrokeColor: Colors.white.toARGB32(),
        ),
      );

      AppLogger.info('Clustering layers set up successfully');
    } catch (e) {
      AppLogger.error('Error setting up clustering: $e');
    }
  }

  /// Handle cluster tap to zoom in and expand
  Future<void> handleClusterTap(ScreenCoordinate screenPoint) async {
    if (mapboxMap == null) return;

    try {
      final features = await mapboxMap!.queryRenderedFeatures(
        RenderedQueryGeometry.fromScreenCoordinate(screenPoint),
        RenderedQueryOptions(layerIds: ['clusters']),
      );

      if (features.isNotEmpty) {
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

        final cameraState = await mapboxMap!.getCameraState();
        final newZoom = (cameraState.zoom + 2).clamp(0.0, 20.0);

        await mapboxMap!.flyTo(
          CameraOptions(
            center: Point(coordinates: Position(lng, lat)),
            zoom: newZoom,
          ),
          MapAnimationOptions(duration: 500),
        );

        AppLogger.info('Zoomed into cluster at $lat, $lng (zoom: $newZoom)');
      }
    } catch (e) {
      AppLogger.warning('Error handling cluster tap: $e');
    }
  }

  /// Query marker at tap point and return marker ID if found
  Future<String?> queryMarkerAtPoint(ScreenCoordinate screenPoint) async {
    if (mapboxMap == null) return null;

    try {
      final markerFeatures = await mapboxMap!.queryRenderedFeatures(
        RenderedQueryGeometry.fromScreenCoordinate(screenPoint),
        RenderedQueryOptions(layerIds: ['unclustered-point']),
      );

      if (markerFeatures.isNotEmpty) {
        final marker = markerFeatures.first;
        final queriedFeature = marker?.queriedFeature;
        if (queriedFeature == null) return null;

        // Handle Mapbox's CastMap types by converting to standard Map
        final feature = Map<String, dynamic>.from(queriedFeature.feature);

        final propertiesObj = feature['properties'];
        if (propertiesObj == null) return null;
        final properties = Map<String, dynamic>.from(propertiesObj as Map);

        return properties['id']?.toString();
      }
    } catch (e) {
      AppLogger.warning('Error querying markers: $e');
    }

    return null;
  }
}
