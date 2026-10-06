import 'package:flutter/material.dart';
import 'package:itaaleem/core/theme/app_radius.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';
import 'package:itaaleem/core/widgets/app_shimmer.dart';

/// Which container colour family a stat card uses.
enum AdminTone { primary, secondary, tertiary, error }

/// A dashboard counter: icon, big number, label. `value == null` shows "—".
class AdminStatCard extends StatelessWidget {
  const AdminStatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.tone = AdminTone.primary,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final num? value;
  final AdminTone tone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final (Color bg, Color fg) = switch (tone) {
      AdminTone.primary => (scheme.primaryContainer, scheme.onPrimaryContainer),
      AdminTone.secondary => (
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
      ),
      AdminTone.tertiary => (
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
      ),
      AdminTone.error => (scheme.errorContainer, scheme.onErrorContainer),
    };
    return Semantics(
      label: '$label: ${value ?? 'غير متاح'}',
      button: onTap != null,
      child: Card(
        elevation: 1,
        margin: EdgeInsets.zero,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(icon, color: fg, size: 22),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          value == null ? '—' : _format(value!),
                          style: text.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _format(num v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 10000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v % 1 == 0 ? '${v.toInt()}' : v.toStringAsFixed(1);
  }
}

/// Shimmer placeholder sized like [AdminStatCard].
class AdminStatCardShimmer extends StatelessWidget {
  const AdminStatCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppShimmer(
      child: Row(
        children: [
          ShimmerBlock(width: 42, height: 42, radius: AppRadius.md),
          SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBlock(width: 48, height: 18),
                SizedBox(height: AppSpacing.xs),
                ShimmerBlock(width: 80, height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
