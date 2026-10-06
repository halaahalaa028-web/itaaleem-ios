import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:itaaleem/features/center_admin/data/center_admin_models.dart';
import 'package:itaaleem/features/center_admin/presentation/center_admin_routes.dart';
import 'package:itaaleem/features/center_admin/presentation/widgets/admin_common.dart';
import 'package:itaaleem/features/center_admin/presentation/widgets/admin_data_table.dart';

/// `GET /center-admin/exams` — filter by subject; tap for student results.
class CenterExamsScreen extends StatefulWidget {
  const CenterExamsScreen({super.key});

  @override
  State<CenterExamsScreen> createState() => _CenterExamsScreenState();
}

class _CenterExamsScreenState extends State<CenterExamsScreen> {
  int? _subjectId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الامتحانات')),
      body: AdminDataTable(
        path: 'exams',
        filters: {'subject_id': _subjectId},
        searchHint: 'ابحث بعنوان الامتحان',
        emptyTitle: 'لا توجد امتحانات',
        emptyIcon: Icons.quiz_outlined,
        header: AdminSubjectFilter(
          selected: _subjectId,
          onChanged: (id) => setState(() => _subjectId = id),
        ),
        itemBuilder: (context, r) {
          final avg = r.number(['average_score', 'average', 'avg_score']);
          return AdminRecordCard(
            title: r.title,
            leading: const AdminAvatar(name: '', icon: Icons.quiz_rounded),
            lines: [
              r.nestedName('subject'),
              [
                if (r.count(['questions_count']) case final q?) '$q سؤال',
                if (r.count(['attempts_count', 'attempts']) case final a?)
                  '$a محاولة',
                if (avg != null) 'المتوسط ${avg.round()}%',
              ].join(' • '),
            ],
            onTap: () => context.push(centerAdminExamPath(r.id), extra: r),
          );
        },
      ),
    );
  }
}

/// `GET /center-admin/exams/{id}/results` — every student's attempt.
class CenterExamResultsScreen extends StatelessWidget {
  const CenterExamResultsScreen({
    super.key,
    required this.examId,
    this.preview,
  });

  final int examId;
  final AdminRecord? preview;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(preview?.title ?? 'نتائج الامتحان')),
      body: AdminDataTable(
        path: 'exams/$examId/results',
        searchHint: 'ابحث باسم الطالب',
        emptyTitle: 'لم يحل أحد هذا الامتحان بعد',
        emptyIcon: Icons.fact_check_outlined,
        itemBuilder: (context, r) {
          final name = r.nestedName('student') ?? r.title;
          final pct = r.number(['percentage', 'score_percentage', 'score']);
          final passed = r.flag(['is_passed', 'passed']);
          return AdminRecordCard(
            title: name,
            leading: AdminAvatar(
              name: name,
              imageUrl: r.nested('student')?.image,
            ),
            lines: [
              adminDate(r.date(['submitted_at', 'created_at'])),
            ],
            trailing: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  pct == null ? '—' : '${pct.round()}%',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (passed != null)
                  adminStatusBadge(passed ? 'active' : 'expired'),
              ],
            ),
          );
        },
      ),
    );
  }
}
