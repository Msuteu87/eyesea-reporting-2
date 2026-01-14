import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../../core/utils/logger.dart';

/// Handles map tap interactions for clusters and markers.
///
/// Extracts the tap handling logic from HomeScreen into a focused class.
class MapTapHandler {
  final MapboxMap _map;

  /// Layer ID for cluster circles
  static const _clusterLayerId = 'clusters';

  /// Layer ID for individual markers
  static const _markerLayerId = 'unclustered-point';

  MapTapHandler(this._map);

  /// Handle cluster tap - zooms into the cluster if one was tapped.
  ///
  /// Returns true if a cluster was tapped and handled, false otherwise.
  Future<bool> handleClusterTap(ScreenCoordinate screenPoint) async {
    try {
      final features = await _map.queryRenderedFeatures(
        RenderedQueryGeometry.fromScreenCoordinate(screenPoint),
        RenderedQueryOptions(layerIds: [_clusterLayerId]),
      );

      if (features.isEmpty) return false;

      // Tapped on a cluster - zoom in to expand
      final cluster = features.first;
      final queriedFeature = cluster?.queriedFeature;
      if (queriedFeature == null) return false;

      // Extract coordinates from feature
      final coords = _extractCoordinates(queriedFeature);
      if (coords == null) return false;

      final lng = coords.$1;
      final lat = coords.$2;

      // Get current zoom and increase by 2
      final cameraState = await _map.getCameraState();
      final newZoom = (cameraState.zoom + 2).clamp(0.0, 20.0);

      await _map.flyTo(
        CameraOptions(
          center: Point(coordinates: Position(lng, lat)),
          zoom: newZoom,
        ),
        MapAnimationOptions(duration: 500),
      );

      AppLogger.info('Zoomed into cluster at $lat, $lng (zoom: $newZoom)');
      return true;
    } catch (e) {
      AppLogger.warning('Error handling cluster tap: $e');
      return false;
    }
  }

  /// Query for marker at tap point.
  ///
  /// Returns the marker ID if a marker was tapped, null otherwise.
  Future<String?> queryMarkerAtPoint(ScreenCoordinate screenPoint) async {
    try {
      final markerFeatures = await _map.queryRenderedFeatures(
        RenderedQueryGeometry.fromScreenCoordinate(screenPoint),
        RenderedQueryOptions(layerIds: [_markerLayerId]),
      );

      if (markerFeatures.isEmpty) return null;

      final marker = markerFeatures.first;
      final queriedFeature = marker?.queriedFeature;
      if (queriedFeature == null) return null;

      // Extract marker ID from properties
      final properties = _extractProperties(queriedFeature);
      if (properties == null) return null;

      return properties['id']?.toString();
    } catch (e) {
      AppLogger.warning('Error querying marker: $e');
      return null;
    }
  }

  /// Extract coordinates from a queried feature.
  (double lng, double lat)? _extractCoordinates(QueriedFeature queriedFeature) {
    try {
      // Handle Mapbox's CastMap types by converting to standard Map
      final feature = Map<String, dynamic>.from(queriedFeature.feature);

      final geometryObj = feature['geometry'];
      if (geometryObj == null) return null;
      final geometry = Map<String, dynamic>.from(geometryObj as Map);

      final coords = geometry['coordinates'] as List?;
      if (coords == null || coords.length < 2) return null;

      final lng = (coords[0] as num).toDouble();
      final lat = (coords[1] as num).toDouble();

      return (lng, lat);
    } catch (e) {
      AppLogger.debug('Error extracting coordinates: $e');
      return null;
    }
  }

  /// Extract properties from a queried feature.
  Map<String, dynamic>? _extractProperties(QueriedFeature queriedFeature) {
    try {
      // Handle Mapbox's CastMap types by converting to standard Map
      final feature = Map<String, dynamic>.from(queriedFeature.feature);

      final propertiesObj = feature['properties'];
      if (propertiesObj == null) return null;

      return Map<String, dynamic>.from(propertiesObj as Map);
    } catch (e) {
      AppLogger.debug('Error extracting properties: $e');
      return null;
    }
  }
}
