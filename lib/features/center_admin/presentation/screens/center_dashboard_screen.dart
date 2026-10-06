import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:itaaleem/core/error/failure.dart';
import 'package:itaaleem/core/network/api_endpoints.dart';
import 'package:itaaleem/core/theme/app_radius.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';
import 'package:itaaleem/core/widgets/app_error_state.dart';
import 'package:itaaleem/features/auth/presentation/providers/auth_controller.dart';
import 'package:itaaleem/features/center_admin/data/center_admin_models.dart';
import 'package:itaaleem/features/center_admin/presentation/center_admin_routes.dart';
import 'package:itaaleem/features/center_admin/presentation/screens/center_students_screen.dart';
import 'package:itaaleem/features/center_admin/presentation/widgets/admin_common.dart';
import 'package:itaaleem/features/center_admin/presentation/widgets/admin_menu_item.dart';
import 'package:itaaleem/features/center_admin/presentation/widgets/admin_stat_card.dart';
import 'package:itaaleem/features/center_admin/providers/center_admin_providers.dart';

/// Home of the center-admin dashboard: center header, pending subscription
/// requests (badge + "طلبات جديدة"), 8 counters, the latest subscriptions
/// and students, and a grid into every section.
/// Everything comes from `GET /center-admin/dashboard`, already scoped to
/// this admin's center by the server.
class CenterDashboardScreen extends ConsumerWidget {
  const CenterDashboardScreen({super.key});

  static const _sections = <(IconData, String, String)>[
    (Icons.people_alt_rounded, 'الطلاب', centerAdminStudentsPath),
    (Icons.menu_book_rounded, 'المواد', centerAdminSubjectsPath),
    (Icons.school_rounded, 'الدكاترة', centerAdminTeachersPath),
    (Icons.play_circle_rounded, 'المحاضرات', centerAdminLecturesPath),
    (Icons.quiz_rounded, 'الامتحانات', centerAdminExamsPath),
    (Icons.card_membership_rounded, 'الاشتراكات', centerAdminSubscriptionsPath),
    (Icons.vpn_key_rounded, 'أكواد التفعيل', centerAdminActivationCodesPath),
    (
      Icons.notifications_active_rounded,
      'الإشعارات',
      centerAdminNotificationsPath,
    ),
    (Icons.view_carousel_rounded, 'البنرات', centerAdminBannersPath),
    (Icons.folder_rounded, 'الملفات', centerAdminFilesPath),
    (Icons.insights_rounded, 'الإحصائيات', centerAdminStatsPath),
    (Icons.settings_rounded, 'الإعدادات', centerAdminSettingsPath),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(centerDashboardProvider);
    final pendingAsync = ref.watch(centerPendingRequestsProvider);
    final pendingCount = pendingAsync.valueOrNull?.total ?? 0;
    final profileCenter = ref.watch(
      authControllerProvider.select((s) => s.valueOrNull?.centerJson),
    );
    final data = async.valueOrNull;
    final centerName =
        data?.centerName ??
        (profileCenter?['name'] is String
            ? profileCenter!['name'] as String
            : null);
    final centerLogo =
        data?.centerLogo ??
        ApiEndpoints.mediaUrl(
          (profileCenter?['logo_url'] ?? profileCenter?['logo'])?.toString(),
        );

    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة تحكم السنتر'),
        actions: [
          IconButton(
            tooltip: 'طلبات الاشتراك',
            onPressed: () => context.push('$centerAdminStudentsPath?tab=2'),
            icon: Badge(
              isLabelVisible: pendingCount > 0,
              label: Text('$pendingCount'),
              child: const Icon(Icons.notifications_rounded),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(centerPendingRequestsProvider);
          ref.invalidate(centerDashboardProvider);
          // Errors are shown by the page itself; just end the spinner.
          await ref
              .read(centerDashboardProvider.future)
              .then<void>((_) {}, onError: (Object _) {});
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 700;
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                _CenterHeader(name: centerName, logo: centerLogo),
                const SizedBox(height: AppSpacing.lg),
                // Newest subscription requests first — each opens activation.
                _PendingRequestsSection(async: pendingAsync),
                if (async.hasError && data == null)
                  AppErrorState(
                    message: failureOf(async.error!).message,
                    onRetry: () => ref.invalidate(centerDashboardProvider),
                  )
                else
                  _StatsGrid(stats: data?.stats, columns: wide ? 4 : 2),
                const AdminSectionTitle('الأقسام'),
                GridView.count(
                  crossAxisCount: wide ? 6 : 4,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: AppSpacing.sm,
                  crossAxisSpacing: AppSpacing.sm,
                  childAspectRatio: 0.9,
                  children: [
                    for (final (icon, label, path) in _sections)
                      path == centerAdminStudentsPath && pendingCount > 0
                          ? Badge(
                              label: Text('$pendingCount'),
                              offset: const Offset(-6, 6),
                              child: AdminMenuItem(
                                icon: icon,
                                label: label,
                                onTap: () => context.push(path),
                              ),
                            )
                          : AdminMenuItem(
                              icon: icon,
                              label: label,
                              onTap: () => context.push(path),
                            ),
                  ],
                ),
                if (data != null) ...[
                  AdminSectionTitle(
                    'آخر الاشتراكات',
                    action: TextButton(
                      onPressed: () =>
                          context.push(centerAdminSubscriptionsPath),
                      child: const Text('عرض الكل'),
                    ),
                  ),
                  _RecentList(
                    items: data.recentSubscriptions,
                    empty: 'لا توجد اشتراكات حديثة',
                    builder: (r) => AdminRecordCard(
                      title: r.nestedName('student') ?? r.title,
                      leading: AdminAvatar(
                        name: r.nestedName('student') ?? r.title,
                        imageUrl: r.nested('student')?.image,
                      ),
                      lines: [
                        r.nestedName('subject') ?? r.nestedName('package'),
                        adminDate(r.date(['created_at', 'starts_at'])),
                      ],
                      trailing: adminStatusBadge(r.status),
                    ),
                  ),
                  AdminSectionTitle(
                    'آخر الطلاب المسجّلين',
                    action: TextButton(
                      onPressed: () => context.push(centerAdminStudentsPath),
                      child: const Text('عرض الكل'),
                    ),
                  ),
                  _RecentList(
                    items: data.recentStudents,
                    empty: 'لا يوجد طلاب جدد',
                    builder: (r) => AdminRecordCard(
                      title: r.title,
                      leading: AdminAvatar(name: r.title, imageUrl: r.image),
                      lines: [
                        r.phone ?? r.email,
                        'سجّل ${adminAgo(r.date(['created_at', 'joined_at']))}',
                      ],
                      onTap: () =>
                          context.push(centerAdminStudentPath(r.id), extra: r),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CenterHeader extends StatelessWidget {
  const _CenterHeader({required this.name, required this.logo});

  final String? name;
  final String? logo;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          AdminAvatar(
            name: name ?? 'س',
            imageUrl: logo,
            radius: 28,
            icon: logo == null ? Icons.apartment_rounded : null,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name ?? 'السنتر',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                Text(
                  'لوحة تحكم مدير السنتر',
                  style: text.bodySmall?.copyWith(
                    color: scheme.onPrimaryContainer.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats, required this.columns});

  /// `null` while loading — shimmer cards.
  final AdminRecord? stats;
  final int columns;

  @override
  Widget build(BuildContext context) {
    final s = stats;
    final cards = <(IconData, String, List<String>, AdminTone, String)>[
      (
        Icons.people_alt_rounded,
        'الطلاب',
        ['students_count', 'students', 'total_students'],
        AdminTone.primary,
        centerAdminStudentsPath,
      ),
      (
        Icons.verified_rounded,
        'الطلاب المشتركين',
        ['subscribed_students_count', 'subscribed_students', 'active_students'],
        AdminTone.secondary,
        centerAdminStudentsPath,
      ),
      (
        Icons.menu_book_rounded,
        'المواد',
        ['subjects_count', 'subjects', 'total_subjects'],
        AdminTone.tertiary,
        centerAdminSubjectsPath,
      ),
      (
        Icons.school_rounded,
        'الدكاترة',
        ['teachers_count', 'teachers', 'total_teachers', 'doctors_count'],
        AdminTone.primary,
        centerAdminTeachersPath,
      ),
      (
        Icons.play_circle_rounded,
        'المحاضرات',
        [
          'lectures_count',
          'lessons_count',
          'lectures',
          'lessons',
          'total_lectures',
        ],
        AdminTone.secondary,
        centerAdminLecturesPath,
      ),
      (
        Icons.quiz_rounded,
        'الامتحانات',
        ['exams_count', 'exams', 'total_exams'],
        AdminTone.tertiary,
        centerAdminExamsPath,
      ),
      (
        Icons.card_membership_rounded,
        'الاشتراكات النشطة',
        ['active_subscriptions_count', 'active_subscriptions'],
        AdminTone.primary,
        centerAdminSubscriptionsPath,
      ),
      (
        Icons.folder_rounded,
        'الملفات',
        ['files_count', 'attachments_count', 'files', 'total_files'],
        AdminTone.secondary,
        centerAdminFilesPath,
      ),
    ];
    return GridView.count(
      crossAxisCount: columns,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.md,
      crossAxisSpacing: AppSpacing.md,
      childAspectRatio: 2.1,
      children: [
        for (final (icon, label, keys, tone, path) in cards)
          s == null
              ? Card(
                  elevation: 1,
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: AdminStatCardShimmer(),
                  ),
                )
              : AdminStatCard(
                  icon: icon,
                  label: label,
                  value: s.number(keys),
                  tone: tone,
                  onTap: () => context.push(path),
                ),
      ],
    );
  }
}

class _RecentList extends StatelessWidget {
  const _RecentList({
    required this.items,
    required this.empty,
    required this.builder,
  });

  final List<AdminRecord> items;
  final String empty;
  final Widget Function(AdminRecord) builder;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Text(
          empty,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    return Column(
      children: [
        for (final r in items)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: builder(r),
          ),
      ],
    );
  }
}

/// "طلبات جديدة": the pending-request count and the latest three requests.
/// Hidden when there are none (or the call fails).
class _PendingRequestsSection extends StatelessWidget {
  const _PendingRequestsSection({required this.async});

  final AsyncValue<({List<AdminRecord> items, int total})> async;

  @override
  Widget build(BuildContext context) {
    final data = async.valueOrNull;
    if (data == null || data.items.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      color: scheme.primaryContainer.withValues(alpha: 0.35),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.mark_email_unread_rounded, color: scheme.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'طلبات جديدة',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Badge(
                  label: Text('${data.total}'),
                  backgroundColor: scheme.error,
                  textColor: scheme.onError,
                ),
                TextButton(
                  style: TextButton.styleFrom(minimumSize: const Size(48, 36)),
                  onPressed: () =>
                      context.push('$centerAdminStudentsPath?tab=2'),
                  child: const Text('عرض الكل'),
                ),
              ],
            ),
            for (final r in data.items.take(3))
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: CenterRequestCard(request: r),
              ),
          ],
        ),
      ),
    );
  }
}
