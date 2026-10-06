import 'package:flutter/material.dart';
import 'package:itaaleem/core/utils/platform_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:itaaleem/core/theme/app_radius.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';
import 'package:itaaleem/features/subscriptions/presentation/providers/subscription_providers.dart';
import 'package:itaaleem/features/subscriptions/presentation/widgets/subject_subscription_sheet.dart';

/// Wraps a subject card: while the subject needs a subscription the student
/// doesn't have, a lock + "اشتراك" overlay covers the card and every tap opens
/// [showSubjectSubscriptionSheet] instead of the subject. Loading and errors
/// leave the card as it is (never lock on a guess).
class SubjectLockGate extends ConsumerWidget {
  const SubjectLockGate({
    super.key,
    required this.subjectId,
    required this.subjectName,
    required this.child,
    this.borderRadius = AppRadius.lg,
  });

  final int subjectId;
  final String subjectName;
  final Widget child;

  /// Must match the wrapped card's corners.
  final double borderRadius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref
        .watch(subjectSubscriptionProvider(subjectId))
        .valueOrNull;
    if (status == null || status.hasAccess) return child;
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: _LockOverlay(
            radius: borderRadius,
            onTap: () => showSubjectSubscriptionSheet(
              context,
              subjectId: subjectId,
              subjectName: subjectName,
              status: status,
            ),
          ),
        ),
      ],
    );
  }
}

class _LockOverlay extends StatelessWidget {
  const _LockOverlay({required this.radius, required this.onTap});

  final double radius;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: PlatformUtils.hideSubscriptions
          ? 'مادة مقفولة'
          : 'مادة مقفولة — اشتراك',
      child: Material(
        color: cs.scrim.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.lock_rounded, size: 24, color: cs.primary),
                ),
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.base,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: cs.primary,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    PlatformUtils.hideSubscriptions ? 'مقفولة' : 'اشتراك',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: cs.onPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
