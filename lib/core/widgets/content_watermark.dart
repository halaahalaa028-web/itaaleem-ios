import 'package:flutter/material.dart';
import 'package:itaaleem/core/theme/app_typography.dart';

/// Faint diagonal tiling of the viewing student's name and phone over
/// protected content (lecture video / PDF): a photo or recording of any part
/// of the screen still identifies who leaked it. Complements the moving
/// `IdentityWatermark`.
///
/// Painted with one [CustomPainter] (not a grid of Text widgets), so it costs
/// a single layer however many tiles fit, and it never takes touches.
/// Each label is drawn white over a 1px dark offset so it stays legible on
/// both dark video and white PDF pages.
class ContentWatermark extends StatelessWidget {
  const ContentWatermark({
    super.key,
    required this.studentName,
    required this.studentPhone,
    this.opacity = 0.08,
    this.fontSize = 14,
    this.rotation = -0.35,
    this.spacing = 120,
  });

  final String studentName;
  final String studentPhone;

  /// 0.06–0.08 keeps it readable in a capture without disturbing viewing.
  final double opacity;
  final double fontSize;

  /// Radians (−0.35 ≈ −20°).
  final double rotation;

  /// Gap between tiles, in logical pixels.
  final double spacing;

  @override
  Widget build(BuildContext context) {
    if (studentName.isEmpty && studentPhone.isEmpty) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _WatermarkPainter(
            label: [
              studentName,
              studentPhone,
            ].where((s) => s.isNotEmpty).join('\n'),
            opacity: opacity,
            fontSize: fontSize,
            rotation: rotation,
            spacing: spacing,
            textDirection: Directionality.of(context),
          ),
        ),
      ),
    );
  }
}

class _WatermarkPainter extends CustomPainter {
  _WatermarkPainter({
    required this.label,
    required this.opacity,
    required this.fontSize,
    required this.rotation,
    required this.spacing,
    required this.textDirection,
  });

  final String label;
  final double opacity;
  final double fontSize;
  final double rotation;
  final double spacing;
  final TextDirection textDirection;

  TextPainter _painter(Color color) => TextPainter(
    text: TextSpan(
      text: label,
      style: TextStyle(
        fontFamily: AppTypography.fontFamily,
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: color,
      ),
    ),
    textAlign: TextAlign.center,
    textDirection: textDirection,
  )..layout();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final light = _painter(Colors.white.withValues(alpha: opacity));
    final dark = _painter(Colors.black.withValues(alpha: opacity * 0.8));
    final stepX = light.width + spacing;
    final stepY = light.height + spacing * 0.6;

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    // Rotate around the center and cover the rotated bounding box.
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(rotation);
    final reach = size.longestSide;
    var row = 0;
    for (var y = -reach; y < reach; y += stepY, row++) {
      final shift = row.isEven ? 0.0 : stepX / 2;
      for (var x = -reach - shift; x < reach; x += stepX) {
        dark.paint(canvas, Offset(x + 1, y + 1));
        light.paint(canvas, Offset(x, y));
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_WatermarkPainter old) =>
      old.label != label ||
      old.opacity != opacity ||
      old.fontSize != fontSize ||
      old.rotation != rotation ||
      old.spacing != spacing ||
      old.textDirection != textDirection;
}
