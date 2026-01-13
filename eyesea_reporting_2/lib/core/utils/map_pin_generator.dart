import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Generates teardrop/pin-style map markers programmatically using Flutter's Canvas.
/// Similar to Google Maps pin markers with customizable colors.
class MapPinGenerator {
  /// Size of the generated pin image
  static const double pinWidth = 48.0;
  static const double pinHeight = 64.0;

  /// Generate a pin marker image with the specified color
  /// Returns a PNG-encoded Uint8List ready for Mapbox addImage()
  static Future<Uint8List> generatePin({
    required Color fillColor,
    Color borderColor = Colors.white,
    Color innerCircleColor = Colors.white,
    double borderWidth = 2.5,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Draw the pin shape
    _drawPin(
      canvas,
      fillColor: fillColor,
      borderColor: borderColor,
      innerCircleColor: innerCircleColor,
      borderWidth: borderWidth,
    );

    // Convert to image
    final picture = recorder.endRecording();
    final image = await picture.toImage(
      pinWidth.toInt(),
      pinHeight.toInt(),
    );

    // Encode to PNG
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  /// Draw the teardrop pin shape
  static void _drawPin(
    Canvas canvas, {
    required Color fillColor,
    required Color borderColor,
    required Color innerCircleColor,
    required double borderWidth,
  }) {
    const centerX = pinWidth / 2;
    final topRadius = pinWidth / 2 - borderWidth;
    final circleCenter = Offset(centerX, topRadius + borderWidth);

    // Create teardrop path
    final path = Path();

    // Start at the bottom point
    const bottomPoint = Offset(centerX, pinHeight - 4);

    // Control points for the curves
    final leftControl1 = Offset(centerX - topRadius * 0.6, pinHeight - 16);
    final leftControl2 = Offset(borderWidth, circleCenter.dy + topRadius * 0.5);

    final rightControl1 = Offset(pinWidth - borderWidth, circleCenter.dy + topRadius * 0.5);
    final rightControl2 = Offset(centerX + topRadius * 0.6, pinHeight - 16);

    // Build the teardrop shape
    path.moveTo(bottomPoint.dx, bottomPoint.dy);

    // Left side curve going up
    path.cubicTo(
      leftControl1.dx,
      leftControl1.dy,
      leftControl2.dx,
      leftControl2.dy,
      borderWidth,
      circleCenter.dy,
    );

    // Top arc (left side)
    path.arcToPoint(
      Offset(pinWidth - borderWidth, circleCenter.dy),
      radius: Radius.circular(topRadius),
      clockwise: true,
      largeArc: true,
    );

    // Right side curve going down
    path.cubicTo(
      rightControl1.dx,
      rightControl1.dy,
      rightControl2.dx,
      rightControl2.dy,
      bottomPoint.dx,
      bottomPoint.dy,
    );

    path.close();

    // Draw shadow (offset slightly)
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    canvas.save();
    canvas.translate(1, 2);
    canvas.drawPath(path, shadowPaint);
    canvas.restore();

    // Draw border (stroke)
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    // Draw fill
    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, borderPaint);

    // Draw inner circle (dot)
    final innerCirclePaint = Paint()
      ..color = innerCircleColor
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(centerX, circleCenter.dy),
      topRadius * 0.35,
      innerCirclePaint,
    );

    // Add subtle highlight for depth
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(centerX - topRadius * 0.25, circleCenter.dy - topRadius * 0.25),
      topRadius * 0.15,
      highlightPaint,
    );
  }

  /// Pre-defined pin colors
  static const Color reportedPinColor = Color(0xFFEF4444); // Red for reported/active
  static const Color recoveredPinColor = Color(0xFF10B981); // Green for recovered
  static const Color pendingPinColor = Color(0xFFFF9F1C); // Amber for pending

  /// Generate all pin variants needed for the map
  static Future<Map<String, Uint8List>> generateAllPins() async {
    return {
      'pin-reported': await generatePin(fillColor: reportedPinColor),
      'pin-recovered': await generatePin(fillColor: recoveredPinColor),
      'pin-pending': await generatePin(fillColor: pendingPinColor),
    };
  }
}
