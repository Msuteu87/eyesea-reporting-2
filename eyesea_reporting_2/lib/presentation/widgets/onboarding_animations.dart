import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Animated ocean wave background widget
class AnimatedOceanWave extends StatefulWidget {
  final Color waveColor;
  final double height;
  final Duration animationDuration;

  const AnimatedOceanWave({
    super.key,
    this.waveColor = const Color(0xFF0A2540),
    this.height = 150,
    this.animationDuration = const Duration(seconds: 3),
  });

  @override
  State<AnimatedOceanWave> createState() => _AnimatedOceanWaveState();
}

class _AnimatedOceanWaveState extends State<AnimatedOceanWave>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size(double.infinity, widget.height),
          painter: WavePainter(
            animationValue: _controller.value,
            waveColor: widget.waveColor,
          ),
        );
      },
    );
  }
}

class WavePainter extends CustomPainter {
  final double animationValue;
  final Color waveColor;

  WavePainter({
    required this.animationValue,
    required this.waveColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = waveColor.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    final path = Path();
    const waveHeight = 20.0;
    final waveLength = size.width / 2;

    path.moveTo(0, size.height);

    for (double x = 0; x <= size.width; x++) {
      final y = size.height / 2 +
          waveHeight *
              math.sin((x / waveLength + animationValue) * 2 * math.pi);
      path.lineTo(x, y);
    }

    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, paint);

    // Second wave layer
    final paint2 = Paint()
      ..color = waveColor.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;

    final path2 = Path();
    path2.moveTo(0, size.height);

    for (double x = 0; x <= size.width; x++) {
      final y = size.height / 2 +
          15 +
          waveHeight *
              0.8 *
              math.sin((x / waveLength + animationValue + 0.5) * 2 * math.pi);
      path2.lineTo(x, y);
    }

    path2.lineTo(size.width, size.height);
    path2.close();

    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(WavePainter oldDelegate) =>
      oldDelegate.animationValue != animationValue;
}

/// Pulsing permission icon widget
class PulsingPermissionIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  final double size;
  final bool isGranted;

  const PulsingPermissionIcon({
    super.key,
    required this.icon,
    this.color = const Color(0xFF0A2540),
    this.size = 80,
    this.isGranted = false,
  });

  @override
  State<PulsingPermissionIcon> createState() => _PulsingPermissionIconState();
}

class _PulsingPermissionIconState extends State<PulsingPermissionIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _opacityAnimation = Tween<double>(begin: 0.4, end: 0.8).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isGranted) {
      // Show success checkmark
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 600),
        curve: Curves.elasticOut,
        builder: (context, value, child) {
          return Transform.scale(
            scale: value,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: Colors.green.shade400,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Icon(
                Icons.check,
                color: Colors.white,
                size: widget.size * 0.5,
              ),
            ),
          );
        },
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Outer pulsing ring
            Transform.scale(
              scale: _scaleAnimation.value * 1.3,
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: widget.color
                        .withValues(alpha: _opacityAnimation.value * 0.3),
                    width: 2,
                  ),
                ),
              ),
            ),
            // Inner pulsing ring
            Transform.scale(
              scale: _scaleAnimation.value * 1.1,
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: widget.color
                        .withValues(alpha: _opacityAnimation.value * 0.5),
                    width: 2,
                  ),
                ),
              ),
            ),
            // Icon container
            Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                widget.icon,
                color: widget.color,
                size: widget.size * 0.5,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Success checkmark animation
class SuccessCheckAnimation extends StatefulWidget {
  final VoidCallback? onComplete;
  final double size;

  const SuccessCheckAnimation({
    super.key,
    this.onComplete,
    this.size = 100,
  });

  @override
  State<SuccessCheckAnimation> createState() => _SuccessCheckAnimationState();
}

class _SuccessCheckAnimationState extends State<SuccessCheckAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _checkAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.elasticOut),
      ),
    );

    _checkAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
      ),
    );

    _controller.forward().then((_) {
      widget.onComplete?.call();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: Colors.green.shade400,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.green
                      .withValues(alpha: 0.4 * _scaleAnimation.value),
                  blurRadius: 30 * _scaleAnimation.value,
                  spreadRadius: 10 * _scaleAnimation.value,
                ),
              ],
            ),
            child: CustomPaint(
              painter: CheckmarkPainter(progress: _checkAnimation.value),
              size: Size(widget.size, widget.size),
            ),
          ),
        );
      },
    );
  }
}

class CheckmarkPainter extends CustomPainter {
  final double progress;

  CheckmarkPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);
    final checkStart = Offset(center.dx - size.width * 0.2, center.dy);
    final checkMid =
        Offset(center.dx - size.width * 0.05, center.dy + size.height * 0.15);
    final checkEnd =
        Offset(center.dx + size.width * 0.25, center.dy - size.height * 0.15);

    final path = Path();

    if (progress <= 0.5) {
      // Draw first part of check
      final t = progress * 2;
      path.moveTo(checkStart.dx, checkStart.dy);
      path.lineTo(
        checkStart.dx + (checkMid.dx - checkStart.dx) * t,
        checkStart.dy + (checkMid.dy - checkStart.dy) * t,
      );
    } else {
      // Draw full first part and partial second part
      path.moveTo(checkStart.dx, checkStart.dy);
      path.lineTo(checkMid.dx, checkMid.dy);

      final t = (progress - 0.5) * 2;
      path.lineTo(
        checkMid.dx + (checkEnd.dx - checkMid.dx) * t,
        checkMid.dy + (checkEnd.dy - checkMid.dy) * t,
      );
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CheckmarkPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Parallax page transition for onboarding
class ParallaxPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;

  ParallaxPageRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;
            const curve = Curves.easeInOutCubic;

            final tween = Tween(begin: begin, end: end).chain(
              CurveTween(curve: curve),
            );

            final fadeTween = Tween(begin: 0.0, end: 1.0).chain(
              CurveTween(curve: curve),
            );

            return SlideTransition(
              position: animation.drive(tween),
              child: FadeTransition(
                opacity: animation.drive(fadeTween),
                child: child,
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 500),
        );
}
