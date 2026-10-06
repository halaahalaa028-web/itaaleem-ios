import 'package:flutter/material.dart';
import 'package:itaaleem/core/theme/app_palette.dart';
import 'package:itaaleem/core/theme/app_radius.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';

enum StatusType { success, warning, error, info, locked, completed, pending }

/// Small pill label colored by [type] (e.g. "مكتمل"، "مقفول"، "قيد المراجعة").
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.type,
    required this.label,
    this.showIcon = true,
  });

  final StatusType type;
  final String label;
  final bool showIcon;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final scheme = Theme.of(context).colorScheme;
    final (Color fg, IconData icon) = switch (type) {
      StatusType.success => (palette.success, Icons.check_circle_rounded),
      StatusType.completed => (palette.success, Icons.task_alt_rounded),
      StatusType.warning => (palette.warning, Icons.warning_amber_rounded),
      StatusType.pending => (palette.warning, Icons.schedule_rounded),
      StatusType.error => (scheme.error, Icons.error_rounded),
      StatusType.info => (palette.info, Icons.info_rounded),
      StatusType.locked => (scheme.outline, Icons.lock_rounded),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: fg.withValues(alpha: palette.isDark ? 0.18 : 0.12),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(color: fg),
          ),
        ],
      ),
    );
  }
}
