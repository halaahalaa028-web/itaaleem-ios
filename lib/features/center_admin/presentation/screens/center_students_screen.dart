import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:itaaleem/features/center_admin/data/center_admin_models.dart';
import 'package:itaaleem/features/center_admin/presentation/center_admin_routes.dart';
import 'package:itaaleem/features/center_admin/presentation/widgets/admin_common.dart';
import 'package:itaaleem/features/center_admin/presentation/widgets/admin_data_table.dart';
import 'package:itaaleem/features/center_admin/providers/center_admin_providers.dart';

/// Students section, three tabs:
/// * الطلاب — `GET /center-admin/students` (searchable, paginated);
/// * المشتركين — `GET /center-admin/subscriptions?status=active`;
/// * طلبات جديدة — `GET /center-admin/subscriptions?status=pending`, each
///   opening the activation screen.
/// [initialTab] lets the dashboard open straight on the requests.
class CenterStudentsScreen extends ConsumerWidget {
  const CenterStudentsScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(centerPendingRequestsProvider).valueOrNull;
    return DefaultTabController(
      length: 3,
      initialIndex: initialTab.clamp(0, 2),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الطلاب'),
          bottom: TabBar(
            tabs: [
              const Tab(text: 'الطلاب'),
              const Tab(text: 'المشتركين'),
              Tab(
                child: Badge(
                  isLabelVisible: (pending?.total ?? 0) > 0,
                  label: Text('${pending?.total ?? 0}'),
                  offset: const Offset(14, -6),
                  child: const Text('طلبات جديدة'),
                ),
              ),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_AllStudents(), _ActiveSubscribers(), _PendingRequests()],
        ),
      ),
    );
  }
}

class _AllStudents extends StatelessWidget {
  const _AllStudents();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AdminDataTable(
      path: 'students',
      searchHint: 'ابحث بالاسم أو رقم الهاتف',
      emptyTitle: 'لا يوجد طلاب في السنتر بعد',
      emptyIcon: Icons.people_outline_rounded,
      itemBuilder: (context, r) {
        final active = r.count([
          'active_subscriptions_count',
          'active_subscriptions',
          'subscriptions_count',
        ]);
        final lastActive = r.date([
          'last_activity_at',
          'last_active_at',
          'last_seen_at',
          'last_login_at',
        ]);
        return AdminRecordCard(
          title: r.title,
          leading: AdminAvatar(name: r.title, imageUrl: r.image),
          lines: [
            r.phone ?? r.email,
            lastActive == null ? null : 'آخر نشاط: ${adminAgo(lastActive)}',
          ],
          trailing: active == null
              ? null
              : Chip(
                  visualDensity: VisualDensity.compact,
                  avatar: Icon(
                    Icons.card_membership_rounded,
                    size: 16,
                    color: scheme.primary,
                  ),
                  label: Text('$active'),
                ),
          onTap: () => context.push(centerAdminStudentPath(r.id), extra: r),
        );
      },
    );
  }
}

/// Name, phone, subject and date of a subscription / request row.
List<String?> _subscriptionLines(AdminRecord r, {required String dateLabel}) {
  final student = r.nested('student');
  return [
    student?.phone ?? r.phone,
    r.nestedName('subject') ?? r.nestedName('package'),
    '$dateLabel ${adminDate(r.date(['created_at', 'requested_at', 'starts_at']))}',
  ];
}

class _ActiveSubscribers extends StatelessWidget {
  const _ActiveSubscribers();

  @override
  Widget build(BuildContext context) {
    return AdminDataTable(
      path: 'subscriptions',
      filters: const {'status': 'active'},
      searchHint: 'ابحث باسم الطالب',
      emptyTitle: 'لا يوجد طلاب مشتركين حالياً',
      emptyIcon: Icons.card_membership_outlined,
      itemBuilder: (context, r) {
        final name = r.nestedName('student') ?? r.title;
        final studentId = r.nestedId('student');
        return AdminRecordCard(
          title: name,
          leading: AdminAvatar(
            name: name,
            imageUrl: r.nested('student')?.image,
          ),
          lines: [
            ..._subscriptionLines(r, dateLabel: 'منذ'),
            'ينتهي ${adminDate(r.date(['expires_at', 'end_date', 'ends_at']))}',
          ],
          trailing: adminStatusBadge(r.status),
          onTap: studentId == null
              ? null
              : () => context.push(centerAdminStudentPath(studentId)),
        );
      },
    );
  }
}

class _PendingRequests extends StatelessWidget {
  const _PendingRequests();

  @override
  Widget build(BuildContext context) {
    return AdminDataTable(
      path: 'subscriptions',
      filters: const {'status': 'pending'},
      searchHint: 'ابحث باسم الطالب',
      emptyTitle: 'لا توجد طلبات اشتراك جديدة',
      emptyIcon: Icons.mark_email_read_outlined,
      itemBuilder: (context, r) => CenterRequestCard(request: r),
    );
  }
}

/// A pending request row — opens the activation screen. Shared with the
/// dashboard's "طلبات جديدة".
class CenterRequestCard extends StatelessWidget {
  const CenterRequestCard({super.key, required this.request});

  final AdminRecord request;

  @override
  Widget build(BuildContext context) {
    final r = request;
    final name = r.nestedName('student') ?? r.title;
    return AdminRecordCard(
      title: name,
      leading: AdminAvatar(name: name, imageUrl: r.nested('student')?.image),
      lines: _subscriptionLines(r, dateLabel: 'طلب في'),
      trailing: adminStatusBadge(r.status ?? 'pending'),
      onTap: () => context.push(centerAdminRequestPath(r.id), extra: r),
    );
  }
}
