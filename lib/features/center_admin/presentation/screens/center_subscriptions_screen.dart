import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:itaaleem/features/center_admin/data/center_admin_models.dart';
import 'package:itaaleem/features/center_admin/presentation/widgets/admin_common.dart';
import 'package:itaaleem/features/center_admin/presentation/widgets/admin_data_table.dart';
import 'package:itaaleem/features/center_admin/providers/center_admin_providers.dart';

/// `GET /center-admin/subscriptions?status=` — tabs الكل / نشط / منتهي,
/// per-row extend / suspend / cancel, and "تفعيل اشتراك" (student +
/// subject + duration).
class CenterSubscriptionsScreen extends ConsumerWidget {
  const CenterSubscriptionsScreen({super.key});

  static const _tabs = <(String, String?)>[
    ('الكل', null),
    ('نشط', 'active'),
    ('منتهي', 'expired'),
  ];

  Future<void> _activateNew(BuildContext context, WidgetRef ref) async {
    final student = await pickAdminRecord(
      context,
      path: 'students',
      title: 'اختر الطالب',
    );
    if (student == null || !context.mounted) return;
    final subject = await pickAdminRecord(
      context,
      path: 'subjects',
      title: 'اختر المادة',
    );
    if (subject == null || !context.mounted) return;
    final values = await showAdminForm(
      context,
      title: 'تفعيل اشتراك: ${student.title} — ${subject.title}',
      submitLabel: 'تفعيل',
      fields: const [
        AdminField(
          'duration_days',
          'المدة (بالأيام)',
          icon: Icons.timelapse_rounded,
          initial: '30',
          numeric: true,
          required: true,
        ),
      ],
    );
    if (values == null || !context.mounted) return;
    await runAdminAction(
      context,
      ref,
      () => ref.read(centerAdminRepositoryProvider).create('subscriptions', {
        'student_id': student.id,
        'subject_id': subject.id,
        ...values,
      }),
      success: 'تم تفعيل الاشتراك',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: _tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الاشتراكات'),
          bottom: TabBar(
            tabs: [for (final (label, _) in _tabs) Tab(text: label)],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _activateNew(context, ref),
          icon: const Icon(Icons.add_card_rounded),
          label: const Text('تفعيل اشتراك'),
        ),
        body: TabBarView(
          children: [
            for (final (_, status) in _tabs)
              AdminDataTable(
                path: 'subscriptions',
                filters: {'status': status},
                searchHint: 'ابحث باسم الطالب',
                emptyTitle: 'لا توجد اشتراكات',
                emptyIcon: Icons.card_membership_outlined,
                bottomPadding: 96,
                itemBuilder: (context, r) => _SubscriptionCard(record: r),
              ),
          ],
        ),
      ),
    );
  }
}

class _SubscriptionCard extends ConsumerWidget {
  const _SubscriptionCard({required this.record});

  final AdminRecord record;

  String get _path => 'subscriptions/${record.id}';

  Future<void> _extend(BuildContext context, WidgetRef ref) async {
    final values = await showAdminForm(
      context,
      title: 'تمديد الاشتراك',
      submitLabel: 'تمديد',
      fields: const [
        AdminField(
          'days',
          'عدد أيام التمديد',
          icon: Icons.more_time_rounded,
          initial: '30',
          numeric: true,
          required: true,
        ),
      ],
    );
    if (values == null || !context.mounted) return;
    await runAdminAction(
      context,
      ref,
      () => ref
          .read(centerAdminRepositoryProvider)
          .action('$_path/extend', values),
      success: 'تم تمديد الاشتراك ${values['days']} يوم',
    );
  }

  Future<void> _simple(
    BuildContext context,
    WidgetRef ref, {
    required String action,
    required String title,
    required String success,
    bool destructive = false,
  }) async {
    final ok = await confirmAdmin(
      context,
      title: title,
      message: '$title لـ $_studentName؟',
      confirmLabel: title,
      destructive: destructive,
    );
    if (!ok || !context.mounted) return;
    await runAdminAction(
      context,
      ref,
      () => ref.read(centerAdminRepositoryProvider).action('$_path/$action'),
      success: success,
    );
  }

  String get _studentName => record.nestedName('student') ?? record.title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = record;
    final status = r.status;
    return AdminRecordCard(
      title: _studentName,
      leading: AdminAvatar(
        name: _studentName,
        imageUrl: r.nested('student')?.image,
      ),
      lines: [
        r.nestedName('subject') ?? r.nestedName('package'),
        'من ${adminDate(r.date(['starts_at', 'start_date']))} '
            'إلى ${adminDate(r.date(['expires_at', 'end_date', 'ends_at']))}',
      ],
      trailing: adminStatusBadge(status),
      menu: [
        AdminMenuAction(
          'تمديد',
          Icons.more_time_rounded,
          () => _extend(context, ref),
        ),
        if (status == 'suspended' || status == 'inactive')
          AdminMenuAction(
            'تفعيل',
            Icons.play_circle_rounded,
            () => _simple(
              context,
              ref,
              action: 'activate',
              title: 'تفعيل',
              success: 'تم تفعيل الاشتراك',
            ),
          )
        else
          AdminMenuAction(
            'إيقاف',
            Icons.pause_circle_rounded,
            () => _simple(
              context,
              ref,
              action: 'suspend',
              title: 'إيقاف',
              success: 'تم إيقاف الاشتراك',
            ),
          ),
        AdminMenuAction(
          'إلغاء',
          Icons.cancel_rounded,
          () => _simple(
            context,
            ref,
            action: 'cancel',
            title: 'إلغاء الاشتراك',
            success: 'تم إلغاء الاشتراك',
            destructive: true,
          ),
          destructive: true,
        ),
      ],
    );
  }
}
