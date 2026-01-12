import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_colors.dart';

/// A bottom sheet widget that displays a Mapbox map for adjusting GPS location.
/// User can drag the map to reposition the pin, then confirm to save.
class MapPickerBottomSheet extends StatefulWidget {
  final double initialLatitude;
  final double initialLongitude;
  final String? city;
  final String? country;

  const MapPickerBottomSheet({
    super.key,
    required this.initialLatitude,
    required this.initialLongitude,
    this.city,
    this.country,
  });

  /// Shows the bottom sheet and returns the selected coordinates, or null if cancelled.
  static Future<Point?> show(
    BuildContext context, {
    required double latitude,
    required double longitude,
    String? city,
    String? country,
  }) {
    return showModalBottomSheet<Point>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: false, // Disable bottom sheet drag to allow map panning
      builder: (context) => MapPickerBottomSheet(
        initialLatitude: latitude,
        initialLongitude: longitude,
        city: city,
        country: country,
      ),
    );
  }

  @override
  State<MapPickerBottomSheet> createState() => _MapPickerBottomSheetState();
}

class _MapPickerBottomSheetState extends State<MapPickerBottomSheet> {
  MapboxMap? _mapController;
  late double _selectedLat;
  late double _selectedLng;

  @override
  void initState() {
    super.initState();
    _selectedLat = widget.initialLatitude;
    _selectedLng = widget.initialLongitude;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.6,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(LucideIcons.mapPin,
                    color: AppColors.oceanBlue, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Adjust Location',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Drag the map to position the pin',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark ? Colors.white54 : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(LucideIcons.x,
                      color: isDark ? Colors.white54 : Colors.grey),
                ),
              ],
            ),
          ),

          // Map
          Expanded(
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                  child: MapWidget(
                    cameraOptions: CameraOptions(
                      center: Point(
                          coordinates: Position(_selectedLng, _selectedLat)),
                      zoom: 15,
                    ),
                    styleUri: isDark ? MapboxStyles.DARK : MapboxStyles.LIGHT,
                    onMapCreated: _onMapCreated,
                    onCameraChangeListener: _onCameraChanged,
                  ),
                ),
                // Center pin indicator (stays fixed)
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.oceanBlue,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.oceanBlue.withValues(alpha: 0.4),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      LucideIcons.mapPin,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Coordinates display
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: isDark ? Colors.black26 : Colors.grey[100],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(LucideIcons.navigation,
                    size: 14, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  '${_selectedLat.toStringAsFixed(6)}, ${_selectedLng.toStringAsFixed(6)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    color: isDark ? Colors.white70 : Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),

          // Confirm button
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(
                    context,
                    Point(coordinates: Position(_selectedLng, _selectedLat)),
                  );
                },
                icon: const Icon(LucideIcons.check),
                label: const Text('Confirm Location'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.oceanBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onMapCreated(MapboxMap controller) async {
    _mapController = controller;

    // Enable all gestures for dragging
    await controller.gestures.updateSettings(
      GesturesSettings(
        scrollEnabled: true,
        rotateEnabled: true,
        pinchToZoomEnabled: true,
        doubleTapToZoomInEnabled: true,
        doubleTouchToZoomOutEnabled: true,
        pitchEnabled: false, // Keep map flat
        scrollMode: ScrollMode.HORIZONTAL_AND_VERTICAL,
      ),
    );
  }

  void _onCameraChanged(CameraChangedEventData event) async {
    if (_mapController == null) return;

    final cameraState = await _mapController!.getCameraState();
    final center = cameraState.center;

    setState(() {
      _selectedLat = center.coordinates.lat.toDouble();
      _selectedLng = center.coordinates.lng.toDouble();
    });
  }
}
