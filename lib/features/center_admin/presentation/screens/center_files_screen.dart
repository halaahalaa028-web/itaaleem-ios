import 'package:flutter/material.dart';
import 'package:itaaleem/core/utils/open_file_in_app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:itaaleem/core/network/api_endpoints.dart';
import 'package:itaaleem/features/center_admin/data/center_admin_models.dart';
import 'package:itaaleem/features/center_admin/presentation/widgets/admin_common.dart';
import 'package:itaaleem/features/center_admin/presentation/widgets/admin_data_table.dart';
import 'package:itaaleem/features/center_admin/providers/center_admin_providers.dart';

/// `GET /center-admin/files` — filter by subject, open, delete.
class CenterFilesScreen extends ConsumerStatefulWidget {
  const CenterFilesScreen({super.key});

  @override
  ConsumerState<CenterFilesScreen> createState() => _CenterFilesScreenState();
}

class _CenterFilesScreenState extends ConsumerState<CenterFilesScreen> {
  int? _subjectId;

  IconData _iconFor(String? name) {
    final n = (name ?? '').toLowerCase();
    if (n.endsWith('.pdf')) return Icons.picture_as_pdf_rounded;
    if (n.endsWith('.doc') || n.endsWith('.docx')) {
      return Icons.description_rounded;
    }
    if (n.endsWith('.png') || n.endsWith('.jpg') || n.endsWith('.jpeg')) {
      return Icons.image_rounded;
    }
    return Icons.insert_drive_file_rounded;
  }

  Future<void> _delete(AdminRecord file) async {
    final ok = await confirmAdmin(
      context,
      title: 'حذف الملف',
      message: 'حذف "${file.title}"؟',
      confirmLabel: 'حذف',
      destructive: true,
    );
    if (!ok || !mounted) return;
    await runAdminAction(
      context,
      ref,
      () => ref.read(centerAdminRepositoryProvider).remove('files/${file.id}'),
      success: 'تم حذف الملف',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الملفات')),
      body: AdminDataTable(
        path: 'files',
        filters: {'subject_id': _subjectId},
        searchHint: 'ابحث باسم الملف',
        emptyTitle: 'لا توجد ملفات',
        emptyIcon: Icons.folder_open_rounded,
        header: AdminSubjectFilter(
          selected: _subjectId,
          onChanged: (id) => setState(() => _subjectId = id),
        ),
        itemBuilder: (context, r) {
          final url = ApiEndpoints.mediaUrl(
            r.text(['url', 'file_url', 'path', 'file']),
          );
          return AdminRecordCard(
            title: r.title,
            leading: AdminAvatar(name: '', icon: _iconFor(url ?? r.title)),
            lines: [
              r.nestedName('subject') ?? r.nestedName('lecture'),
              [
                ?r.text(['size', 'size_label']),
                adminDate(r.date(['created_at'])),
              ].join(' • '),
            ],
            onTap: url == null
                ? null
                : () => openFileInApp(context, url, title: r.title),
            menu: [
              if (url != null)
                AdminMenuAction(
                  'فتح',
                  Icons.open_in_new_rounded,
                  () => openFileInApp(context, url, title: r.title),
                ),
              AdminMenuAction(
                'حذف',
                Icons.delete_rounded,
                () => _delete(r),
                destructive: true,
              ),
            ],
          );
        },
      ),
    );
  }
}
