import 'package:itaaleem/features/center_admin/presentation/center_admin_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:itaaleem/app/router/app_router.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';
import 'package:itaaleem/core/widgets/app_card.dart';
import 'package:itaaleem/features/admin/data/models/admin_models.dart';
import 'package:itaaleem/features/admin/presentation/providers/admin_provider.dart';
import 'package:itaaleem/features/auth/presentation/providers/auth_controller.dart';

/// The admin's home: quick counters plus shortcuts to the admin screens.
/// Shown as the "الإدارة" tab of `HomeShell` (and at `/admin`) — only for
/// admins (see [isAdminProvider]). A simplified companion to the full
/// Filament panel, which stays one tap away.
class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(adminStatsProvider);
    final centerName = ref.watch(adminCenterNameProvider);
    final name = ref.watch(
      authControllerProvider.select((s) => s.valueOrNull?.fullName),
    );
    final loaded = stats.valueOrNull;
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    String count(int Function(AdminStats) pick) =>
        loaded == null || !loaded.available ? '—' : '${pick(loaded)}';

    return Scaffold(
      appBar: AppBar(title: const Text('لوحة الإدارة')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(adminStatsProvider.future),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
          children: [
            _WelcomeHeader(
              name: name,
              centerName: loaded?.centerName ?? centerName,
            ),
            const SizedBox(height: AppSpacing.base),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: AppSpacing.gridSpacing,
              crossAxisSpacing: AppSpacing.gridSpacing,
              childAspectRatio: 1.35,
              children: [
                _StatCard(
                  icon: Icons.people_alt_rounded,
                  label: 'الطلاب',
                  value: count((s) => s.studentsCount),
                  color: cs.primary,
                  loading: stats.isLoading,
                  onTap: () => context.push(adminStudentsPath),
                ),
                _StatCard(
                  icon: Icons.menu_book_rounded,
                  label: 'المواد',
                  value: count((s) => s.subjectsCount),
                  color: cs.secondary,
                  loading: stats.isLoading,
                  onTap: () => context.push(adminSubjectsPath),
                ),
                _StatCard(
                  icon: Icons.card_membership_rounded,
                  label: 'اشتراكات نشطة',
                  value: count((s) => s.activeSubscriptions),
                  color: cs.tertiary,
                  loading: stats.isLoading,
                  onTap: () =>
                      context.push('$adminSubscriptionsPath?status=active'),
                ),
                _StatCard(
                  icon: Icons.notifications_active_rounded,
                  label: 'طلبات جديدة',
                  value: count((s) => s.pendingRequests),
                  color: cs.error,
                  loading: stats.isLoading,
                  onTap: () =>
                      context.push('$adminSubscriptionsPath?status=pending'),
                ),
              ],
            ),
            if (loaded != null && !loaded.available) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'الإحصائيات غير متاحة على السيرفر بعد',
                textAlign: TextAlign.center,
                style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: AppSpacing.sectionSpacing),
            Text('إجراءات سريعة', style: text.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Column(
                children: [
                  _ActionItem(
                    icon: Icons.people_alt_rounded,
                    label: 'إدارة الطلاب',
                    subtitle: 'بحث، تفاصيل الطالب، الأجهزة والنتائج',
                    onTap: () => context.push(adminStudentsPath),
                  ),
                  _ActionItem(
                    icon: Icons.menu_book_rounded,
                    label: 'إدارة المواد',
                    subtitle: 'المواد وعدد الطلاب وتفعيلها',
                    onTap: () => context.push(adminSubjectsPath),
                  ),
                  _ActionItem(
                    icon: Icons.calendar_month_rounded,
                    label: 'المواعيد والجدول',
                    subtitle: 'جدول الأسبوع — إضافة وتعديل وحذف',
                    onTap: () => context.push(adminSchedulePath),
                  ),
                  _ActionItem(
                    icon: Icons.card_membership_rounded,
                    label: 'إدارة الاشتراكات',
                    subtitle: 'تفعيل، تمديد، إلغاء، واشتراك جديد',
                    onTap: () => context.push(adminSubscriptionsPath),
                  ),
                  _ActionItem(
                    icon: Icons.campaign_rounded,
                    label: 'الإعلانات',
                    subtitle: 'إعلان جديد مع إشعار للطلاب',
                    onTap: () => context.push(adminAnnouncementsPath),
                  ),
                  _ActionItem(
                    icon: Icons.open_in_new_rounded,
                    label: 'فتح لوحة التحكم الكاملة',
                    subtitle: 'لوحة تحكم السنتر داخل التطبيق',
                    onTap: () => context.push(centerAdminPath),
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

class _WelcomeHeader extends StatelessWidget {
  const _WelcomeHeader({required this.name, required this.centerName});

  final String? name;
  final String? centerName;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final firstName = name?.trim().split(RegExp(r'\s+')).first;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: cs.primary,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.admin_panel_settings_rounded,
              color: cs.onPrimary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  firstName == null || firstName.isEmpty
                      ? 'مرحباً يا أدمن'
                      : 'مرحباً يا $firstName',
                  style: text.titleMedium?.copyWith(
                    color: cs.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (centerName != null)
                  Text(
                    centerName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodyMedium?.copyWith(
                      color: cs.onPrimaryContainer.withValues(alpha: 0.8),
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

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.onTap,
    this.loading = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.base),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: cs.shadow.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const Spacer(),
              loading
                  ? const SizedBox(
                      height: 32,
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  : Text(
                      value,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 24,
                        height: 1.3,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionItem extends StatelessWidget {
  const _ActionItem({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: cs.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: cs.primary, size: 22),
      ),
      title: Text(
        label,
        style: const TextStyle(
          fontFamily: 'Cairo',
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 12,
          color: cs.onSurfaceVariant,
        ),
      ),
      trailing: Icon(
        Icons.chevron_left_rounded,
        color: cs.onSurface.withValues(alpha: 0.3),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base,
        vertical: AppSpacing.xs,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}
