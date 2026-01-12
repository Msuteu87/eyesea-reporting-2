import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// Floating action button for centering map on user location.
class MyLocationFab extends StatelessWidget {
  final VoidCallback onPressed;

  const MyLocationFab({
    super.key,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.small(
      heroTag: 'myLocationFab',
      onPressed: onPressed,
      backgroundColor: Colors.white,
      foregroundColor: AppColors.oceanBlue,
      child: const Icon(Icons.my_location),
    );
  }
}
