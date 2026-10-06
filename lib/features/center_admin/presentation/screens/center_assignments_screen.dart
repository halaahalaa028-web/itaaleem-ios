import 'package:flutter/material.dart';
import 'package:itaaleem/core/utils/open_file_in_app.dart';
import 'package:go_router/go_router.dart';
import 'package:itaaleem/features/center_admin/data/center_admin_models.dart';
import 'package:itaaleem/features/center_admin/presentation/center_admin_routes.dart';
import 'package:itaaleem/features/center_admin/presentation/widgets/admin_common.dart';
import 'package:itaaleem/features/center_admin/presentation/widgets/admin_data_table.dart';

/// `GET /center-admin/assignments` — filter by subject; tap for submissions.
class CenterAssignmentsScreen extends StatefulWidget {
  const CenterAssignmentsScreen({super.key});

  @override
  State<CenterAssignmentsScreen> createState() =>
      _CenterAssignmentsScreenState();
}

class _CenterAssignmentsScreenState extends State<CenterAssignmentsScreen> {
  int? _subjectId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الواجبات')),
      body: AdminDataTable(
        path: 'assignments',
        filters: {'subject_id': _subjectId},
        searchHint: 'ابحث بعنوان الواجب',
        emptyTitle: 'لا توجد واجبات',
        emptyIcon: Icons.assignment_outlined,
        header: AdminSubjectFilter(
          selected: _subjectId,
          onChanged: (id) => setState(() => _subjectId = id),
        ),
        itemBuilder: (context, r) {
          final submitted = r.count(['submissions_count', 'submitted_count']);
          final rate =
              r.number(['submission_rate', 'submission_percentage']) ??
              _rate(submitted, r.count(['students_count', 'total_students']));
          return AdminRecordCard(
            title: r.title,
            leading: const AdminAvatar(
              name: '',
              icon: Icons.assignment_rounded,
            ),
            lines: [
              r.nestedName('subject'),
              [
                if (submitted != null) '$submitted تسليم',
                if (rate != null) 'نسبة التسليم ${rate.round()}%',
                if (r.date(['due_date', 'deadline']) case final d?)
                  'آخر موعد ${adminDate(d)}',
              ].join(' • '),
            ],
            onTap: () =>
                context.push(centerAdminAssignmentPath(r.id), extra: r),
          );
        },
      ),
    );
  }

  static num? _rate(int? done, int? total) =>
      done == null || total == null || total == 0 ? null : done * 100 / total;
}

/// `GET /center-admin/assignments/{id}/submissions`.
class CenterAssignmentSubmissionsScreen extends StatelessWidget {
  const CenterAssignmentSubmissionsScreen({
    super.key,
    required this.assignmentId,
    this.preview,
  });

  final int assignmentId;
  final AdminRecord? preview;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(preview?.title ?? 'التسليمات')),
      body: AdminDataTable(
        path: 'assignments/$assignmentId/submissions',
        searchHint: 'ابحث باسم الطالب',
        emptyTitle: 'لا توجد تسليمات بعد',
        emptyIcon: Icons.inbox_outlined,
        itemBuilder: (context, r) {
          final name = r.nestedName('student') ?? r.title;
          final file = r.text(['file_url', 'url', 'file']);
          final grade = r.number(['grade', 'score']);
          return AdminRecordCard(
            title: name,
            leading: AdminAvatar(
              name: name,
              imageUrl: r.nested('student')?.image,
            ),
            lines: [
              'سلّم ${adminAgo(r.date(['submitted_at', 'created_at']))}',
              if (grade != null) 'الدرجة: $grade',
            ],
            trailing: adminStatusBadge(r.status),
            onTap: file == null
                ? null
                : () => openFileInApp(context, file, title: 'تسليم الطالب'),
          );
        },
      ),
    );
  }
}
