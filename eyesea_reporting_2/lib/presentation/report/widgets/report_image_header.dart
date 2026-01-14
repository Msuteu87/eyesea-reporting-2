import 'dart:io';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_colors.dart';

/// A SliverAppBar that displays the captured report image with a retake button.
class ReportImageHeader extends StatelessWidget {
  final File imageFile;
  final VoidCallback onRetake;
  final bool isDark;

  const ReportImageHeader({
    super.key,
    required this.imageFile,
    required this.onRetake,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 300,
      pinned: true,
      backgroundColor: isDark ? AppColors.deepNavy : Colors.white,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            shape: BoxShape.circle,
          ),
          child: const Icon(LucideIcons.arrowLeft, color: Colors.white),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(
              imageFile,
              fit: BoxFit.cover,
            ),
            // Gradient overlay for readability
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.3),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.5),
                  ],
                ),
              ),
            ),
            // Retake Button
            Positioned(
              bottom: 16,
              right: 16,
              child: _RetakeButton(onRetake: onRetake),
            ),
          ],
        ),
      ),
    );
  }
}

class _RetakeButton extends StatelessWidget {
  final VoidCallback onRetake;

  const _RetakeButton({required this.onRetake});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onRetake,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.camera,
                color: Colors.white,
                size: 16,
              ),
              SizedBox(width: 6),
              Text(
                'Retake',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
