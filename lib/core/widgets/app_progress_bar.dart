import 'package:flutter/material.dart';
import 'package:itaaleem/core/theme/app_radius.dart';
import 'package:itaaleem/core/theme/app_palette.dart';

/// Rounded progress bar that animates smoothly whenever [progress] changes,
/// instead of jumping straight to the new value.
class AppProgressBar extends StatelessWidget {
  const AppProgressBar({
    super.key,
    required this.progress,
    this.color,
    this.backgroundColor,
    this.height = 8,
  });

  /// 0.0–1.0. Values outside that range are clamped.
  final double progress;
  final Color? color;
  final Color? backgroundColor;
  final double height;

  @override
  Widget build(BuildContext context) {
    final track = backgroundColor ?? context.palette.surfaceVariant;
    final fill = color ?? context.palette.primary;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: Container(
        height: height,
        color: track,
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) {
              return FractionallySizedBox(
                widthFactor: value,
                child: Container(
                  height: height,
                  decoration: BoxDecoration(
                    color: fill,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
