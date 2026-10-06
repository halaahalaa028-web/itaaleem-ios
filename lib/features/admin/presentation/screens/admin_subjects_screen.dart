import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';
import 'package:itaaleem/core/widgets/app_card.dart';
import 'package:itaaleem/core/widgets/app_empty_state.dart';
import 'package:itaaleem/core/widgets/app_shimmer.dart';
import 'package:itaaleem/features/admin/data/models/admin_models.dart';
import 'package:itaaleem/features/admin/presentation/providers/admin_provider.dart';
import 'package:itaaleem/features/admin/presentation/widgets/admin_widgets.dart';
import 'package:itaaleem/features/subjects/presentation/widgets/subject_icon.dart';

/// The center's subjects with their student/lesson counts and an
/// active/hidden switch. Content editing (lessons, files) stays on the web
/// panel — the app bar links there.
class AdminSubjectsScreen extends ConsumerWidget {
  const AdminSubjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjects = ref.watch(adminSubjectsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('المواد'),
        actions: [
          IconButton(
            tooltip: 'تعديل المحتوى من لوحة التحكم',
            icon: const Icon(Icons.open_in_new_rounded),
            onPressed: () => openAdminPanel(context, path: 'subjects'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(adminSubjectsProvider.future),
        child: subjects.when(
          loading: () => const ShimmerList(count: 5),
          error: (e, _) => AdminScrollable(
            child: AdminErrorView(
              error: e,
              onRetry: () => ref.invalidate(adminSubjectsProvider),
              panelPath: 'subjects',
            ),
          ),
          data: (items) => items.isEmpty
              ? const AdminScrollable(
                  child: AppEmptyState(
                    icon: Icons.menu_book_rounded,
                    title: 'لا توجد مواد بعد',
                  ),
                )
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.listItemSpacing),
                  itemBuilder: (context, i) => _SubjectCard(subject: items[i]),
                ),
        ),
      ),
    );
  }
}

class _SubjectCard extends ConsumerStatefulWidget {
  const _SubjectCard({required this.subject});

  final AdminSubject subject;

  @override
  ConsumerState<_SubjectCard> createState() => _SubjectCardState();
}

class _SubjectCardState extends ConsumerState<_SubjectCard> {
  late bool _active = widget.subject.isActive;
  bool _saving = false;

  Future<void> _toggle(bool value) async {
    setState(() {
      _active = value;
      _saving = true;
    });
    final ok = await runAdminAction(
      context,
      () => ref.read(adminRepositoryProvider).updateSubject(widget.subject.id, {
        'is_active': value,
      }),
      successMessage: value ? 'المادة ظاهرة للطلاب' : 'تم إخفاء المادة',
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (!ok) _active = !value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final s = widget.subject;
    final meta = [
      if (s.studentsCount != null) '${s.studentsCount} طالب',
      if (s.lessonsCount != null) '${s.lessonsCount} درس',
    ].join(' • ');
    return AppCard(
      child: Row(
        children: [
          SubjectIcon(
            iconUrl: s.iconUrl,
            seed: s.id,
            name: s.name,
            size: 48,
            iconSize: 24,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleSmall,
                ),
                if (meta.isNotEmpty)
                  Text(
                    meta,
                    style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
              ],
            ),
          ),
          Switch(value: _active, onChanged: _saving ? null : _toggle),
        ],
      ),
    );
  }
}
