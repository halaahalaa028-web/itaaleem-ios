import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:itaaleem/core/theme/app_radius.dart';
import 'package:itaaleem/features/center_admin/data/center_admin_models.dart';
import 'package:itaaleem/features/center_admin/presentation/center_admin_routes.dart';
import 'package:itaaleem/features/center_admin/presentation/widgets/admin_common.dart';
import 'package:itaaleem/features/center_admin/presentation/widgets/admin_data_table.dart';
import 'package:itaaleem/features/center_admin/providers/center_admin_providers.dart';

Widget _subjectImage(BuildContext context, AdminRecord r) {
  final scheme = Theme.of(context).colorScheme;
  final image = r.image;
  return ClipRRect(
    borderRadius: BorderRadius.circular(AppRadius.md),
    child: Container(
      width: 48,
      height: 48,
      color: scheme.tertiaryContainer,
      child: image == null
          ? Icon(Icons.menu_book_rounded, color: scheme.onTertiaryContainer)
          : Image.network(
              image,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Icon(
                Icons.menu_book_rounded,
                color: scheme.onTertiaryContainer,
              ),
            ),
    ),
  );
}

Future<void> _editSubject(
  BuildContext context,
  WidgetRef ref, {
  AdminRecord? subject,
}) async {
  final values = await showAdminForm(
    context,
    title: subject == null ? 'إضافة مادة' : 'تعديل المادة',
    fields: [
      AdminField(
        'name',
        'اسم المادة',
        icon: Icons.menu_book_rounded,
        initial: subject?.title,
        required: true,
      ),
      AdminField(
        'description',
        'الوصف',
        icon: Icons.notes_rounded,
        initial: subject?.text(['description']),
        maxLines: 3,
      ),
    ],
  );
  if (values == null || !context.mounted) return;
  final repo = ref.read(centerAdminRepositoryProvider);
  await runAdminAction(
    context,
    ref,
    () => subject == null
        ? repo.create('subjects', values)
        : repo.update('subjects/${subject.id}', values),
    success: subject == null ? 'تمت إضافة المادة' : 'تم حفظ التعديلات',
  );
}

Future<void> _deleteSubject(
  BuildContext context,
  WidgetRef ref,
  AdminRecord subject,
) async {
  final ok = await confirmAdmin(
    context,
    title: 'حذف المادة',
    message: 'هل تريد حذف "${subject.title}"؟ لا يمكن التراجع عن ذلك.',
    confirmLabel: 'حذف',
    destructive: true,
  );
  if (!ok || !context.mounted) return;
  await runAdminAction(
    context,
    ref,
    () => ref
        .read(centerAdminRepositoryProvider)
        .remove('subjects/${subject.id}'),
    success: 'تم حذف المادة',
  );
}

/// `GET /center-admin/subjects` — add (FAB), edit / delete (⋮ menu).
class CenterSubjectsScreen extends ConsumerWidget {
  const CenterSubjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('المواد')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editSubject(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('مادة جديدة'),
      ),
      body: AdminDataTable(
        path: 'subjects',
        searchHint: 'ابحث باسم المادة',
        emptyTitle: 'لا توجد مواد بعد',
        emptyIcon: Icons.menu_book_outlined,
        bottomPadding: 96,
        itemBuilder: (context, r) => AdminRecordCard(
          title: r.title,
          leading: _subjectImage(context, r),
          lines: [
            [
              if (r.count(['lectures_count', 'lessons_count']) case final n?)
                '$n محاضرة',
              if (r.count(['students_count', 'subscribers_count'])
                  case final n?)
                '$n طالب',
            ].join(' • '),
            if (r.nestedName('teacher') case final t?) 'د. $t',
          ],
          onTap: () => context.push(centerAdminSubjectPath(r.id), extra: r),
          menu: [
            AdminMenuAction(
              'تعديل',
              Icons.edit_rounded,
              () => _editSubject(context, ref, subject: r),
            ),
            AdminMenuAction(
              'حذف',
              Icons.delete_rounded,
              () => _deleteSubject(context, ref, r),
              destructive: true,
            ),
          ],
        ),
      ),
    );
  }
}

/// One subject: tabs for its lectures, exams and students.
class CenterSubjectDetailScreen extends ConsumerWidget {
  const CenterSubjectDetailScreen({
    super.key,
    required this.subjectId,
    this.preview,
  });

  final int subjectId;
  final AdminRecord? preview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subject =
        ref
            .watch(centerAdminRecordProvider('subjects/$subjectId'))
            .valueOrNull ??
        preview;
    final filter = {'subject_id': subjectId};
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(subject?.title ?? 'تفاصيل المادة'),
          actions: [
            if (subject != null)
              IconButton(
                tooltip: 'تعديل',
                icon: const Icon(Icons.edit_rounded),
                onPressed: () => _editSubject(context, ref, subject: subject),
              ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'المحاضرات'),
              Tab(text: 'الامتحانات'),
              Tab(text: 'الطلاب'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            AdminDataTable(
              path: 'lectures',
              filters: filter,
              emptyTitle: 'لا توجد محاضرات لهذه المادة',
              itemBuilder: (context, r) => AdminRecordCard(
                title: r.title,
                leading: const AdminAvatar(
                  name: '',
                  icon: Icons.play_arrow_rounded,
                ),
                lines: [
                  if (r.number(['views_count', 'views']) case final v?)
                    '$v مشاهدة',
                ],
              ),
            ),
            AdminDataTable(
              path: 'exams',
              filters: filter,
              emptyTitle: 'لا توجد امتحانات لهذه المادة',
              itemBuilder: (context, r) => AdminRecordCard(
                title: r.title,
                leading: const AdminAvatar(name: '', icon: Icons.quiz_rounded),
                lines: [
                  if (r.count(['questions_count']) case final q?) '$q سؤال',
                ],
                onTap: () => context.push(centerAdminExamPath(r.id), extra: r),
              ),
            ),
            AdminDataTable(
              path: 'students',
              filters: filter,
              emptyTitle: 'لا يوجد طلاب مشتركين في هذه المادة',
              itemBuilder: (context, r) => AdminRecordCard(
                title: r.title,
                leading: AdminAvatar(name: r.title, imageUrl: r.image),
                lines: [r.phone],
                onTap: () =>
                    context.push(centerAdminStudentPath(r.id), extra: r),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
