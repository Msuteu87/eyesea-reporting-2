import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'viewport_bounds.dart';

/// Helper for calculating and comparing map viewport bounds.
///
/// Extracts duplicated bounds logic from HomeScreen into a reusable utility.
class MapBoundsHelper {
  /// Default buffer percentage around viewport (30%)
  static const double defaultBuffer = 0.3;

  /// Threshold for "unchanged" viewport detection (~100m at equator)
  static const double unchangedThreshold = 0.001;

  /// Minimum overlap percentage before showing "search this area" button
  static const double overlapThreshold = 0.8;

  /// Get current viewport bounds from map camera state.
  ///
  /// Returns raw bounds without buffer applied.
  static Future<ViewportBounds> getViewportBounds(MapboxMap map) async {
    final cameraState = await map.getCameraState();
    final bounds = await map.coordinateBoundsForCamera(
      CameraOptions(
        center: cameraState.center,
        zoom: cameraState.zoom,
        bearing: cameraState.bearing,
        pitch: cameraState.pitch,
      ),
    );

    return ViewportBounds(
      minLat: bounds.southwest.coordinates.lat.toDouble(),
      maxLat: bounds.northeast.coordinates.lat.toDouble(),
      minLng: bounds.southwest.coordinates.lng.toDouble(),
      maxLng: bounds.northeast.coordinates.lng.toDouble(),
    );
  }

  /// Get current viewport bounds with buffer applied.
  ///
  /// Buffer is applied as percentage of viewport size (default 30%).
  static Future<ViewportBounds> getViewportBoundsWithBuffer(
    MapboxMap map, {
    double buffer = defaultBuffer,
  }) async {
    final rawBounds = await getViewportBounds(map);
    return rawBounds.withBuffer(buffer);
  }

  /// Get current zoom level from map.
  static Future<int> getZoomLevel(MapboxMap map) async {
    final cameraState = await map.getCameraState();
    return cameraState.zoom.toInt();
  }

  /// Check if viewport has changed significantly enough to warrant a reload.
  ///
  /// Returns true if viewport is effectively unchanged (skip reload).
  static bool isViewportUnchanged(
    ViewportBounds current,
    ViewportBounds? last,
    int currentZoom,
    int lastZoom, {
    double threshold = unchangedThreshold,
  }) {
    if (last == null) return false;

    return (current.minLat - last.minLat).abs() < threshold &&
        (current.maxLat - last.maxLat).abs() < threshold &&
        (current.minLng - last.minLng).abs() < threshold &&
        (current.maxLng - last.maxLng).abs() < threshold &&
        currentZoom == lastZoom;
  }

  /// Threshold for considering bounds as "near-global" (covers most of Earth).
  /// When fetched bounds cover more than this percentage of Earth's surface,
  /// zoomed-in viewports should trigger "search this area".
  static const double nearGlobalThreshold = 0.7;

  /// Check if current viewport is significantly outside previously fetched bounds.
  ///
  /// Returns true if less than [overlapThreshold] (default 80%) of current
  /// viewport overlaps with fetched bounds, indicating "search this area"
  /// button should appear.
  ///
  /// Also handles the edge case where fetched bounds cover most of the world
  /// (from max zoom-out search) - in that case, zoomed-in viewports should
  /// still trigger the search button.
  static bool isOutsideFetchedBounds(
    ViewportBounds current,
    ViewportBounds? fetched, {
    double threshold = overlapThreshold,
  }) {
    if (fetched == null) return false;

    // Calculate areas
    final currentArea = current.latRange * current.lngRange;
    if (currentArea <= 0) return false;

    final fetchedArea = fetched.latRange * fetched.lngRange;

    // Max possible area: 180 (lat) * 360 (lng) = 64800
    const maxWorldArea = 180.0 * 360.0;

    // If fetched bounds cover most of the world (from max zoom-out search)
    // and current viewport is significantly smaller, show the search button.
    // This fixes the bug where zooming out to max, searching, then zooming in
    // would never show the search button again.
    if (fetchedArea > maxWorldArea * nearGlobalThreshold &&
        currentArea < fetchedArea * 0.5) {
      return true;
    }

    // Calculate overlap area
    final overlapMinLat = current.minLat.clamp(fetched.minLat, fetched.maxLat);
    final overlapMaxLat = current.maxLat.clamp(fetched.minLat, fetched.maxLat);
    final overlapMinLng = current.minLng.clamp(fetched.minLng, fetched.maxLng);
    final overlapMaxLng = current.maxLng.clamp(fetched.minLng, fetched.maxLng);

    final overlapHeight = (overlapMaxLat - overlapMinLat).clamp(0.0, double.infinity);
    final overlapWidth = (overlapMaxLng - overlapMinLng).clamp(0.0, double.infinity);
    final overlapArea = overlapHeight * overlapWidth;

    final overlapPercentage = overlapArea / currentArea;

    // Show button if less than threshold of current viewport is covered
    return overlapPercentage < threshold;
  }
}
