import 'package:flutter/material.dart';

import 'package:itaaleem/core/theme/app_palette.dart';

/// Rounded progress bar with a purple gradient fill, used on course cards
/// and the course details header.
class CourseProgressBar extends StatelessWidget {
  const CourseProgressBar({
    super.key,
    required this.percent,
    this.trackColor,
    this.fillColor,
    this.height = 8,
  });

  /// 0-100.
  final double percent;
  final Color? trackColor;

  /// Solid override for the fill — defaults to [context.palette.brandGradient]
  /// when null.
  final Color? fillColor;
  final double height;

  @override
  Widget build(BuildContext context) {
    final clamped = percent.clamp(0, 100) / 100;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              Container(
                height: height,
                width: constraints.maxWidth,
                color:
                    trackColor ??
                    Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.08),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOutCubic,
                height: height,
                width: constraints.maxWidth * clamped,
                decoration: BoxDecoration(
                  color: fillColor,
                  gradient: fillColor == null
                      ? context.palette.brandGradient
                      : null,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
