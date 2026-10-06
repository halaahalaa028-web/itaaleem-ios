import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:itaaleem/core/error/failure.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';
import 'package:itaaleem/core/widgets/app_error_state.dart';
import 'package:itaaleem/core/widgets/app_shimmer.dart';
import 'package:itaaleem/features/center_admin/data/center_admin_models.dart';
import 'package:itaaleem/features/center_admin/presentation/center_admin_routes.dart';
import 'package:itaaleem/features/center_admin/presentation/widgets/admin_common.dart';
import 'package:itaaleem/features/center_admin/presentation/widgets/admin_data_table.dart';
import 'package:itaaleem/features/center_admin/providers/center_admin_providers.dart';

Future<void> _editTeacher(
  BuildContext context,
  WidgetRef ref, {
  AdminRecord? teacher,
}) async {
  final values = await showAdminForm(
    context,
    title: teacher == null ? 'إضافة دكتور' : 'تعديل بيانات الدكتور',
    fields: [
      AdminField(
        'name',
        'اسم الدكتور',
        icon: Icons.person_rounded,
        initial: teacher?.title,
        required: true,
      ),
      AdminField(
        'phone',
        'رقم الهاتف',
        icon: Icons.phone_rounded,
        initial: teacher?.phone,
        keyboard: TextInputType.phone,
      ),
      AdminField(
        'specialization',
        'التخصص',
        icon: Icons.workspace_premium_rounded,
        initial: teacher?.text(['specialization']),
      ),
    ],
  );
  if (values == null || !context.mounted) return;
  final repo = ref.read(centerAdminRepositoryProvider);
  await runAdminAction(
    context,
    ref,
    () => teacher == null
        ? repo.create('teachers', values)
        : repo.update('teachers/${teacher.id}', values),
    success: teacher == null ? 'تمت إضافة الدكتور' : 'تم حفظ التعديلات',
  );
}

/// `GET /center-admin/teachers` — add (FAB), tap for details.
class CenterTeachersScreen extends ConsumerWidget {
  const CenterTeachersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('الدكاترة')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editTeacher(context, ref),
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('دكتور جديد'),
      ),
      body: AdminDataTable(
        path: 'teachers',
        searchHint: 'ابحث باسم الدكتور',
        emptyTitle: 'لا يوجد دكاترة بعد',
        emptyIcon: Icons.school_outlined,
        bottomPadding: 96,
        itemBuilder: (context, r) => AdminRecordCard(
          title: 'د. ${r.title}',
          leading: AdminAvatar(name: r.title, imageUrl: r.image),
          lines: [
            r.text(['specialization']),
            '${r.count(['subjects_count']) ?? r.list('subjects').length} مادة',
          ],
          onTap: () => context.push(centerAdminTeacherPath(r.id), extra: r),
        ),
      ),
    );
  }
}

/// One teacher: details + subjects, with link / unlink.
class CenterTeacherDetailScreen extends ConsumerWidget {
  const CenterTeacherDetailScreen({
    super.key,
    required this.teacherId,
    this.preview,
  });

  final int teacherId;
  final AdminRecord? preview;

  String get _path => 'teachers/$teacherId';

  Future<void> _link(BuildContext context, WidgetRef ref) async {
    final subject = await pickAdminRecord(
      context,
      path: 'subjects',
      title: 'اختر مادة لربطها',
    );
    if (subject == null || !context.mounted) return;
    await runAdminAction(
      context,
      ref,
      () => ref.read(centerAdminRepositoryProvider).action('$_path/subjects', {
        'subject_id': subject.id,
      }),
      success: 'تم ربط مادة ${subject.title}',
    );
  }

  Future<void> _unlink(
    BuildContext context,
    WidgetRef ref,
    AdminRecord subject,
  ) async {
    final ok = await confirmAdmin(
      context,
      title: 'فك الربط',
      message: 'فك ربط "${subject.title}" من هذا الدكتور؟',
      confirmLabel: 'فك الربط',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    await runAdminAction(
      context,
      ref,
      () => ref
          .read(centerAdminRepositoryProvider)
          .remove('$_path/subjects/${subject.id}'),
      success: 'تم فك الربط',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(centerAdminRecordProvider(_path));
    final teacher = async.valueOrNull ?? preview;
    final subjects = async.valueOrNull?.list('subjects') ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: Text(teacher == null ? 'الدكتور' : 'د. ${teacher.title}'),
        actions: [
          if (teacher != null)
            IconButton(
              tooltip: 'تعديل',
              icon: const Icon(Icons.edit_rounded),
              onPressed: () => _editTeacher(context, ref, teacher: teacher),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _link(context, ref),
        icon: const Icon(Icons.link_rounded),
        label: const Text('ربط مادة'),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(centerAdminRecordProvider(_path).future),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            96,
          ),
          children: [
            if (teacher != null) ...[
              Center(
                child: AdminAvatar(
                  name: teacher.title,
                  imageUrl: teacher.image,
                  radius: 40,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AdminInfoRow(
                icon: Icons.phone_rounded,
                label: 'الهاتف',
                value: teacher.phone,
              ),
              AdminInfoRow(
                icon: Icons.workspace_premium_rounded,
                label: 'التخصص',
                value: teacher.text(['specialization']),
              ),
            ],
            AdminSectionTitle('المواد (${subjects.length})'),
            if (async.isLoading && async.valueOrNull == null)
              const ShimmerList(count: 3)
            else if (async.hasError && async.valueOrNull == null)
              AppErrorState(
                message: failureOf(async.error!).message,
                onRetry: () => ref.invalidate(centerAdminRecordProvider(_path)),
              )
            else if (subjects.isEmpty)
              const Text('لا توجد مواد مربوطة بهذا الدكتور')
            else
              for (final s in subjects)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: AdminRecordCard(
                    title: s.title,
                    leading: const AdminAvatar(
                      name: '',
                      icon: Icons.menu_book_rounded,
                    ),
                    onTap: () =>
                        context.push(centerAdminSubjectPath(s.id), extra: s),
                    menu: [
                      AdminMenuAction(
                        'فك الربط',
                        Icons.link_off_rounded,
                        () => _unlink(context, ref, s),
                        destructive: true,
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
