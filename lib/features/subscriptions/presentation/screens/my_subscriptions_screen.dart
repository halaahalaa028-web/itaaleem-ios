import 'package:flutter/material.dart';
import 'package:itaaleem/core/widgets/fade_slide_in.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:itaaleem/core/error/failure.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';
import 'package:itaaleem/core/widgets/app_card.dart';
import 'package:itaaleem/core/widgets/app_empty_state.dart';
import 'package:itaaleem/core/widgets/app_error_state.dart';
import 'package:itaaleem/core/widgets/app_shimmer.dart';
import 'package:itaaleem/core/widgets/status_badge.dart';
import 'package:itaaleem/features/subjects/presentation/widgets/subject_icon.dart';
import 'package:itaaleem/features/subscriptions/data/models/subject_subscription_model.dart';
import 'package:itaaleem/features/subscriptions/presentation/providers/subscription_providers.dart';

/// "اشتراكاتي": every subject subscription of the student with its state
/// (active / expired / cancelled) and end date.
class MySubscriptionsScreen extends ConsumerWidget {
  const MySubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscriptions = ref.watch(mySubscriptionsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('اشتراكاتي')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(mySubscriptionsProvider.future),
        child: subscriptions.when(
          loading: () => const ShimmerList(count: 4),
          error: (error, _) => _Scrollable(
            child: AppErrorState(
              message: failureOf(error).message,
              onRetry: () => ref.invalidate(mySubscriptionsProvider),
            ),
          ),
          data: (items) => items.isEmpty
              ? const _Scrollable(
                  child: AppEmptyState(
                    icon: Icons.card_membership_rounded,
                    title: 'لا توجد اشتراكات حالياً',
                    subtitle:
                        'المواد اللي هتشترك فيها هتظهر هنا بعد تفعيلها من الإدارة',
                  ),
                )
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.listItemSpacing),
                  itemBuilder: (context, i) => FadeSlideIn.staggered(
                    index: i,
                    child: _SubscriptionCard(subscription: items[i]),
                  ),
                ),
        ),
      ),
    );
  }
}

/// Keeps pull-to-refresh working on the empty/error states.
class _Scrollable extends StatelessWidget {
  const _Scrollable({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(height: constraints.maxHeight, child: child),
      ),
    );
  }
}

class _SubscriptionCard extends StatelessWidget {
  const _SubscriptionCard({required this.subscription});

  final SubjectSubscription subscription;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final s = subscription;
    final (StatusType type, String label) = s.isActive
        ? (StatusType.success, 'مفعّل')
        : s.isCancelled
        ? (StatusType.locked, 'ملغي')
        : (StatusType.error, 'منتهي');
    final expires = s.expiresAt;

    return AppCard(
      onTap: s.subjectId > 0
          ? () => context.push('/subject-detail/${s.subjectId}')
          : null,
      child: Row(
        children: [
          SubjectIcon(
            iconUrl: s.subjectIcon,
            seed: s.subjectId,
            name: s.subjectName,
            size: 48,
            iconSize: 24,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.subjectName.isEmpty
                      ? 'مادة #${s.subjectId}'
                      : s.subjectName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleSmall,
                ),
                if (s.teacherName != null || s.lecturesCount != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    [
                      if (s.teacherName != null) 'د. ${s.teacherName}',
                      if (s.lecturesCount != null) '${s.lecturesCount} محاضرة',
                    ].join(' • '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
                const SizedBox(height: AppSpacing.xs),
                Text(
                  expires == null
                      ? 'اشتراك دائم'
                      : '${s.isExpired ? 'انتهى في' : 'ينتهي في'} ${_date(expires)}',
                  style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          StatusBadge(type: type, label: label),
        ],
      ),
    );
  }

  static String _date(DateTime d) =>
      '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
}
