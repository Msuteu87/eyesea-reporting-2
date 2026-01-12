import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/theme/app_colors.dart';

class MainShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainShell({super.key, required this.navigationShell});

  void _onTap(BuildContext context, int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Current Index
    final int currentIndex = navigationShell.currentIndex;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      // Make body extend behind nav bar for glass effect
      extendBody: true,
      // The body contains the page content
      body: navigationShell,
      bottomNavigationBar: SizedBox(
        // Height for nav bar with embedded center button
        height: 56 + bottomPadding + 16,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            // Glass bar background
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    padding: EdgeInsets.only(bottom: bottomPadding),
                    decoration: BoxDecoration(
                      // More transparent for better glass effect
                      color: isDark
                          ? AppColors.inkBlack.withValues(alpha: 0.6)
                          : Colors.white.withValues(alpha: 0.7),
                      // Subtle top border for definition
                      border: Border(
                        top: BorderSide(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.15)
                              : Colors.black.withValues(alpha: 0.08),
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8.0, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildNavItem(
                            context,
                            index: 0,
                            icon: LucideIcons.map,
                            activeIcon: LucideIcons.mapPin,
                            label: 'Home',
                            isSelected: currentIndex == 0,
                          ),
                          _buildNavItem(
                            context,
                            index: 1,
                            icon: LucideIcons.calendarDays,
                            activeIcon: LucideIcons.calendarCheck,
                            label: 'Cleanups',
                            isSelected: currentIndex == 1,
                          ),
                          // Spacer for FAB
                          const SizedBox(width: 64),
                          _buildNavItem(
                            context,
                            index: 3,
                            icon: LucideIcons.barChart3,
                            activeIcon: LucideIcons.barChart4,
                            label: 'Impact',
                            isSelected: currentIndex == 3,
                          ),
                          _buildNavItem(
                            context,
                            index: 4,
                            icon: LucideIcons.user,
                            activeIcon: LucideIcons.userCheck,
                            label: 'Profile',
                            isSelected: currentIndex == 4,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Center button (embedded in the bar)
            Positioned(
              bottom: bottomPadding + 6,
              child: _buildCenterButton(context, currentIndex == 2),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterButton(BuildContext context, bool isSelected) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return GestureDetector(
      onTap: () => context.push('/camera-capture'),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: primaryColor,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white,
            width: 3,
          ),
          // No shadow for cleaner embedded look
        ),
        child: const Icon(
          LucideIcons.camera,
          color: Colors.white,
          size: 26,
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context,
      {required int index,
      required IconData icon,
      required IconData activeIcon,
      required String label,
      required bool isSelected}) {
    final color = isSelected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).iconTheme.color?.withValues(alpha: 0.5) ??
            Colors.grey;

    return GestureDetector(
      onTap: () => _onTap(context, index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isSelected ? activeIcon : icon,
            color: color,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom clipper to create hexagon shape
class HexagonClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return _createHexagonPath(size);
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

/// Custom painter to draw hexagon with fill and stroke
class HexagonPainter extends CustomPainter {
  final Color fillColor;
  final Color borderColor;
  final double borderWidth;

  HexagonPainter({
    required this.fillColor,
    required this.borderColor,
    this.borderWidth = 2.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = _createHexagonPath(size);

    // Fill
    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    // Border
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(HexagonPainter oldDelegate) =>
      oldDelegate.fillColor != fillColor ||
      oldDelegate.borderColor != borderColor ||
      oldDelegate.borderWidth != borderWidth;
}

/// Shared function to create hexagon path
Path _createHexagonPath(Size size) {
  final path = Path();
  final w = size.width;
  final h = size.height;

  // Pointy-top hexagon
  path.moveTo(w * 0.5, 0); // Top center
  path.lineTo(w, h * 0.25); // Top right
  path.lineTo(w, h * 0.75); // Bottom right
  path.lineTo(w * 0.5, h); // Bottom center
  path.lineTo(0, h * 0.75); // Bottom left
  path.lineTo(0, h * 0.25); // Top left
  path.close();

  return path;
}
