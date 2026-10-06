import 'package:flutter/material.dart';
import 'package:itaaleem/core/widgets/fade_slide_in.dart';
import 'package:itaaleem/core/widgets/app_card.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:itaaleem/core/error/failure.dart';
import 'package:itaaleem/core/widgets/empty_state.dart';
import 'package:itaaleem/core/widgets/error_view.dart';
import 'package:itaaleem/core/widgets/skeleton_loading.dart';
import 'package:itaaleem/features/assignments/domain/entities/assignment.dart';
import 'package:itaaleem/features/assignments/presentation/providers/assignments_providers.dart';

import 'package:itaaleem/core/theme/app_palette.dart';
import 'package:itaaleem/core/theme/app_radius.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';

/// Assignments list. With a [subjectId] it shows that subject's assignments
/// (`GET /courses/{subject}/assignments`); without one it aggregates every
/// subject's.
class AssignmentsScreen extends ConsumerWidget {
  const AssignmentsScreen({super.key, this.subjectId});

  final int? subjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = subjectId;
    final async = id == null
        ? ref.watch(allAssignmentsProvider)
        : ref.watch(subjectAssignmentsProvider(id));

    Future<void> refresh() async {
      if (id == null) {
        ref.invalidate(allAssignmentsProvider);
        await ref
            .read(allAssignmentsProvider.future)
            .catchError((_) => const <Assignment>[]);
      } else {
        ref.invalidate(subjectAssignmentsProvider(id));
        await ref
            .read(subjectAssignmentsProvider(id).future)
            .catchError((_) => const <Assignment>[]);
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('الواجبات')),
      body: async.when(
        loading: () => const SingleChildScrollView(
          padding: EdgeInsets.all(AppSpacing.lg),
          physics: NeverScrollableScrollPhysics(),
          child: SkeletonList(count: 4),
        ),
        error: (error, _) => ErrorView(
          message: failureOf(error).message,
          retryLabel: 'إعادة المحاولة',
          onRetry: refresh,
        ),
        data: (items) => RefreshIndicator(
          onRefresh: refresh,
          child: items.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 80),
                    EmptyState(
                      message: 'مفيش واجبات حالياً',
                      icon: Icons.assignment_rounded,
                    ),
                  ],
                )
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: items.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, index) => FadeSlideIn.staggered(
                    index: index,
                    child: _AssignmentCard(assignment: items[index]),
                  ),
                ),
        ),
      ),
    );
  }
}

class _AssignmentCard extends StatelessWidget {
  const _AssignmentCard({required this.assignment});

  final Assignment assignment;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final a = assignment;

    final (label, color) = a.isSubmitted
        ? ('تم التسليم', context.palette.success)
        : a.isOverdue
        ? ('انتهى الموعد', scheme.error)
        : ('مطلوب', scheme.primary);

    return AppCard(
      onTap: () => context.push('/assignments/${a.id}'),
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              a.isSubmitted ? Icons.task_alt_rounded : Icons.assignment_rounded,
              color: color,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  a.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (a.subjectName != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    a.subjectName!,
                    style: text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _Pill(label: label, color: color),
                    if (a.dueDate != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.event_rounded,
                            size: 14,
                            color: scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            DateFormat('d MMM yyyy', 'ar').format(a.dueDate!),
                            style: text.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_left_rounded, color: scheme.onSurfaceVariant),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
