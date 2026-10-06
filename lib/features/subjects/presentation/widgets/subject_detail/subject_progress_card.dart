import 'package:flutter/material.dart';
import 'package:itaaleem/core/theme/app_palette.dart';
import 'package:itaaleem/core/theme/app_radius.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';
import 'package:itaaleem/core/widgets/app_progress_bar.dart';
import 'package:itaaleem/core/widgets/app_progress_ring.dart';

/// "تقدمك في المادة": a ring with the completion percentage, "X من Y
/// محاضرات مكتملة" and a linear bar — or a "ابدأ التعلم" nudge when
/// nothing has been watched yet.
class SubjectProgressCard extends StatelessWidget {
  const SubjectProgressCard({
    super.key,
    required this.completed,
    required this.total,
    required this.started,
  });

  final int completed;
  final int total;

  /// Anything watched at all (even a lecture only partly watched).
  final bool started;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fraction = total == 0 ? 0.0 : completed / total;
    final percent = (fraction * 100).round();
    final done = total > 0 && completed >= total;
    final accent = done ? context.palette.success : scheme.primary;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          AppProgressRing(
            progress: fraction,
            size: 74,
            color: accent,
            child: started
                ? Text(
                    '$percent%',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: accent,
                    ),
                  )
                : Icon(Icons.rocket_launch_rounded, color: accent, size: 28),
          ),
          const SizedBox(width: AppSpacing.base),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  !started
                      ? 'ابدأ التعلم'
                      : done
                      ? 'أنهيت المادة بالكامل 🎉'
                      : 'تقدمك في المادة',
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  started
                      ? '$completed من $total محاضرات مكتملة'
                      : 'ابدأ أول محاضرة وتابع تقدمك من هنا',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm + 2),
                AppProgressBar(progress: fraction, height: 6, color: accent),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
