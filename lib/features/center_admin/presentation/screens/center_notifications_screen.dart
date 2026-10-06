import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';
import 'package:itaaleem/features/center_admin/data/center_admin_models.dart';
import 'package:itaaleem/features/center_admin/presentation/widgets/admin_common.dart';
import 'package:itaaleem/features/center_admin/presentation/widgets/admin_data_table.dart';
import 'package:itaaleem/features/center_admin/providers/center_admin_providers.dart';

/// `GET /center-admin/notifications` (sent history) and
/// `POST /center-admin/notifications` (send — to everyone or one subject).
class CenterNotificationsScreen extends ConsumerWidget {
  const CenterNotificationsScreen({super.key});

  Future<void> _compose(BuildContext context, WidgetRef ref) async {
    AdminRecord? subject;
    final values = await showAdminForm(
      context,
      title: 'إرسال إشعار جديد',
      submitLabel: 'إرسال',
      fields: const [
        AdminField(
          'title',
          'العنوان',
          icon: Icons.title_rounded,
          required: true,
        ),
        AdminField(
          'body',
          'نص الإشعار',
          icon: Icons.notes_rounded,
          required: true,
          maxLines: 4,
        ),
      ],
      extra: (values, setState) => [
        Text('المستلمون', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(
              value: false,
              label: Text('كل الطلاب'),
              icon: Icon(Icons.groups_rounded),
            ),
            ButtonSegment(
              value: true,
              label: Text('طلاب مادة'),
              icon: Icon(Icons.menu_book_rounded),
            ),
          ],
          selected: {values['target'] == 'subject'},
          onSelectionChanged: (s) async {
            if (!s.first) {
              setState(() {
                values['target'] = 'all';
                values.remove('subject_id');
                subject = null;
              });
              return;
            }
            final picked = await pickAdminRecord(
              context,
              path: 'subjects',
              title: 'اختر المادة',
            );
            if (picked == null) return;
            setState(() {
              subject = picked;
              values['target'] = 'subject';
              values['subject_id'] = picked.id;
            });
          },
        ),
        if (subject != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text('المادة: ${subject!.title}'),
          ),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
    if (values == null || !context.mounted) return;
    values.putIfAbsent('target', () => 'all');
    await runAdminAction(
      context,
      ref,
      () => ref
          .read(centerAdminRepositoryProvider)
          .create('notifications', values),
      success: 'تم إرسال الإشعار',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('الإشعارات')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _compose(context, ref),
        icon: const Icon(Icons.send_rounded),
        label: const Text('إشعار جديد'),
      ),
      body: AdminDataTable(
        path: 'notifications',
        emptyTitle: 'لم يتم إرسال إشعارات بعد',
        emptyIcon: Icons.notifications_none_rounded,
        bottomPadding: 96,
        itemBuilder: (context, r) {
          final recipients = r.count([
            'recipients_count',
            'sent_count',
            'recipients',
          ]);
          return AdminRecordCard(
            title: r.text(['title']) ?? r.title,
            leading: const AdminAvatar(
              name: '',
              icon: Icons.notifications_rounded,
            ),
            lines: [
              r.text(['body', 'message']),
              [
                adminDate(r.date(['sent_at', 'created_at'])),
                if (recipients != null) '$recipients مستلم',
                if (r.nestedName('subject') case final s?) 'مادة $s',
              ].join(' • '),
            ],
          );
        },
      ),
    );
  }
}
