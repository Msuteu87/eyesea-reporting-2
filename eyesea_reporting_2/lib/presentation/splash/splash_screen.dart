import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';

/// Animated splash screen with ocean waves, logo reveal, and smooth transitions.
/// Duration: ~3 seconds with auto-transition via onComplete callback.
class SplashScreen extends StatefulWidget {
  final VoidCallback onComplete;
  final bool skipOnTap;

  const SplashScreen({
    super.key,
    required this.onComplete,
    this.skipOnTap = true,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _waveController;
  late AnimationController _bubbleController;
  bool _canSkip = false;

  @override
  void initState() {
    super.initState();

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _bubbleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    // Allow skip after 1 second
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) setState(() => _canSkip = true);
    });

    // Auto-complete after 3.5 seconds
    Future.delayed(const Duration(milliseconds: 3500), () {
      if (mounted) widget.onComplete();
    });
  }

  @override
  void dispose() {
    _waveController.dispose();
    _bubbleController.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (_canSkip && widget.skipOnTap) {
      widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: Scaffold(
        body: Stack(
          children: [
            // Background Gradient
            _buildGradientBackground(),

            // Ocean Waves (3 layers)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: MediaQuery.of(context).size.height * 0.4,
              child: AnimatedBuilder(
                animation: _waveController,
                builder: (context, child) => CustomPaint(
                  painter: OceanWavePainter(
                    animationValue: _waveController.value,
                    baseColor: AppColors.primary,
                  ),
                  size: Size.infinite,
                ),
              ),
            ),

            // Floating Bubbles
            ..._buildBubbles(),

            // Center Content (Logo + Text)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  Image.asset(
                    'assets/images/logo_white.png',
                    height: 180,
                    fit: BoxFit.contain,
                  )
                      .animate()
                      .scale(
                        begin: const Offset(0, 0),
                        end: const Offset(1, 1),
                        duration: 800.ms,
                        curve: Curves.elasticOut,
                      )
                      .fadeIn(duration: 600.ms),

                  const SizedBox(height: 24),

                  // Tagline
                  Text(
                    'Empowering communities',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w300,
                          letterSpacing: 1.5,
                        ),
                  )
                      .animate(delay: 1200.ms)
                      .fadeIn(duration: 600.ms)
                      .slideY(begin: 0.3, end: 0),

                  const SizedBox(height: 48),

                  // Subtitle
                  Text(
                    'Protecting our oceans',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.6),
                          letterSpacing: 1.0,
                        ),
                  )
                      .animate(delay: 1800.ms)
                      .fadeIn(duration: 600.ms)
                      .slideY(begin: 0.3, end: 0),
                ],
              ),
            ),

            // Skip indicator (bottom)
            if (_canSkip && widget.skipOnTap)
              Positioned(
                bottom: 60,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    'Tap to continue',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                  ).animate().fadeIn(delay: 500.ms),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGradientBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF0A1628), // Deep navy
            AppColors.primary.withValues(alpha: 0.8),
            AppColors.primary,
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
    ).animate().fadeIn(duration: 800.ms);
  }

  List<Widget> _buildBubbles() {
    final random = math.Random(42);
    return List.generate(12, (index) {
      final size = 8.0 + random.nextDouble() * 16;
      final left = random.nextDouble() * MediaQuery.of(context).size.width;
      final delay = random.nextDouble() * 2000;
      final duration = 3000 + random.nextDouble() * 2000;

      return Positioned(
        left: left,
        bottom: -size,
        child: AnimatedBuilder(
          animation: _bubbleController,
          builder: (context, child) {
            final progress =
                ((_bubbleController.value * 1000 + delay) % duration) /
                    duration;
            final y =
                progress * (MediaQuery.of(context).size.height + size * 2);
            final wobble = math.sin(progress * math.pi * 4) * 20;

            return Transform.translate(
              offset: Offset(wobble, -y),
              child: Opacity(
                opacity: (1 - progress).clamp(0.0, 0.6),
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.2),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
    });
  }
}

/// Custom painter for animated ocean waves
class OceanWavePainter extends CustomPainter {
  final double animationValue;
  final Color baseColor;

  OceanWavePainter({
    required this.animationValue,
    required this.baseColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Wave 1 (back, slowest)
    _drawWave(
      canvas,
      size,
      offset: animationValue * 0.5,
      amplitude: 25,
      verticalOffset: size.height * 0.3,
      color: baseColor.withValues(alpha: 0.3),
    );

    // Wave 2 (middle)
    _drawWave(
      canvas,
      size,
      offset: animationValue * 0.75,
      amplitude: 20,
      verticalOffset: size.height * 0.45,
      color: baseColor.withValues(alpha: 0.5),
    );

    // Wave 3 (front, fastest)
    _drawWave(
      canvas,
      size,
      offset: animationValue,
      amplitude: 15,
      verticalOffset: size.height * 0.6,
      color: baseColor.withValues(alpha: 0.7),
    );
  }

  void _drawWave(
    Canvas canvas,
    Size size, {
    required double offset,
    required double amplitude,
    required double verticalOffset,
    required Color color,
  }) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, size.height);

    for (double x = 0; x <= size.width; x++) {
      final y = verticalOffset +
          amplitude * math.sin((x / size.width * 2 + offset) * math.pi * 2);
      path.lineTo(x, y);
    }

    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(OceanWavePainter oldDelegate) =>
      oldDelegate.animationValue != animationValue;
}
