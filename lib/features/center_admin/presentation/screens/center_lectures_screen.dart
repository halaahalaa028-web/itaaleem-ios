import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:itaaleem/core/error/failure.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';
import 'package:itaaleem/core/widgets/app_shimmer.dart';
import 'package:itaaleem/features/center_admin/data/center_admin_models.dart';
import 'package:itaaleem/features/center_admin/presentation/widgets/admin_common.dart';
import 'package:itaaleem/features/center_admin/providers/center_admin_providers.dart';

/// Every lecture of the center, grouped by subject (collapsible), with a
/// local title search. Each lecture: title, subject, doctor, views.
///
/// `GET /center-admin/lectures` answers 405 on the live server (that was
/// why this screen showed an error), so the lectures come from each
/// subject's `GET subjects/{id}/lectures` — see
/// `CenterAdminRepository.lecturesBySubject`.
class CenterLecturesScreen extends ConsumerStatefulWidget {
  const CenterLecturesScreen({super.key});

  @override
  ConsumerState<CenterLecturesScreen> createState() =>
      _CenterLecturesScreenState();
}

class _CenterLecturesScreenState extends ConsumerState<CenterLecturesScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final async = ref.watch(centerLecturesBySubjectProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('المحاضرات')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(centerLecturesBySubjectProvider.future),
        child: async.when(
          loading: () => const ShimmerList(count: 6, thumbnailSize: 44),
          error: (e, _) => _Message(
            icon: Icons.cloud_off_rounded,
            text: failureOf(e).message,
            onRetry: () => ref.invalidate(centerLecturesBySubjectProvider),
          ),
          data: (groups) {
            final q = _query.trim().toLowerCase();
            final filtered = [
              for (final g in groups)
                (
                  subject: g.subject,
                  lectures: q.isEmpty
                      ? g.lectures
                      : g.lectures
                            .where((l) => l.title.toLowerCase().contains(q))
                            .toList(),
                ),
            ].where((g) => g.lectures.isNotEmpty).toList();
            final total = groups.fold<int>(0, (n, g) => n + g.lectures.length);

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: 'ابحث بعنوان المحاضرة',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: scheme.surfaceContainerHigh,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  '$total محاضرة في ${groups.length} مادة',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (filtered.isEmpty)
                  _Message(
                    icon: Icons.play_circle_outline_rounded,
                    text: q.isEmpty
                        ? 'لا توجد محاضرات'
                        : 'لا توجد محاضرات بهذا الاسم',
                    embedded: true,
                  )
                else
                  for (final g in filtered)
                    _SubjectGroup(
                      key: ValueKey('subject-${g.subject.id}'),
                      subject: g.subject,
                      lectures: g.lectures,
                    ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SubjectGroup extends StatelessWidget {
  const _SubjectGroup({
    super.key,
    required this.subject,
    required this.lectures,
  });

  final AdminRecord subject;
  final List<AdminRecord> lectures;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: true,
        shape: const Border(),
        collapsedShape: const Border(),
        leading: AdminAvatar(
          name: subject.title,
          imageUrl: subject.image,
          icon: Icons.menu_book_rounded,
        ),
        title: Text(
          subject.title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Text(
          '${lectures.length} محاضرة',
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        children: [
          for (final l in lectures)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: _LectureRow(lecture: l, subjectName: subject.title),
            ),
        ],
      ),
    );
  }
}

class _LectureRow extends StatelessWidget {
  const _LectureRow({required this.lecture, required this.subjectName});

  final AdminRecord lecture;
  final String subjectName;

  @override
  Widget build(BuildContext context) {
    final r = lecture;
    final views = r.number(['views_count', 'views', 'watch_count']);
    final teacher =
        r.nestedName('teacher') ??
        r.nestedName('doctor') ??
        r.text(['teacher_name', 'doctor_name']);
    return AdminRecordCard(
      title: r.title,
      leading: AdminAvatar(
        name: '',
        imageUrl: r.image,
        icon: Icons.play_arrow_rounded,
      ),
      lines: [
        [r.nestedName('subject') ?? subjectName, ?teacher].join(' • '),
        [
          '${views ?? 0} مشاهدة',
          if (r.count(['duration_minutes']) case final m?) '$m دقيقة',
        ].join(' • '),
      ],
      trailing: adminStatusBadge(r.status),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.text,
    this.onRetry,
    this.embedded = false,
  });

  final IconData icon;
  final String text;
  final VoidCallback? onRetry;

  /// Inside the list already (no own scroll view).
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final content = Column(
      children: [
        const SizedBox(height: 64),
        Icon(icon, size: 56, color: scheme.onSurfaceVariant),
        const SizedBox(height: AppSpacing.md),
        Text(
          text,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
        ),
        if (onRetry != null) ...[
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size(120, 44)),
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('إعادة المحاولة'),
          ),
        ],
      ],
    );
    if (embedded) return content;
    // Scrollable so pull-to-refresh works on the error state.
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [content],
    );
  }
}
