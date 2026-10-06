import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:itaaleem/app/router/app_router.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';
import 'package:itaaleem/core/widgets/app_card.dart';
import 'package:itaaleem/core/widgets/app_empty_state.dart';
import 'package:itaaleem/core/widgets/app_input.dart';
import 'package:itaaleem/core/widgets/app_shimmer.dart';
import 'package:itaaleem/core/widgets/section_header.dart';
import 'package:itaaleem/core/widgets/status_badge.dart';
import 'package:itaaleem/features/admin/data/models/admin_models.dart';
import 'package:itaaleem/features/admin/presentation/providers/admin_provider.dart';
import 'package:itaaleem/features/admin/presentation/widgets/admin_subscription_widgets.dart';
import 'package:itaaleem/features/admin/presentation/widgets/admin_widgets.dart';

/// Students list with search (debounced) and infinite scroll. Tapping a
/// student opens [AdminStudentDetailsScreen].
class AdminStudentsScreen extends ConsumerStatefulWidget {
  const AdminStudentsScreen({super.key});

  @override
  ConsumerState<AdminStudentsScreen> createState() =>
      _AdminStudentsScreenState();
}

class _AdminStudentsScreenState extends ConsumerState<AdminStudentsScreen> {
  late final AdminPagedController<AdminStudent> _controller;
  Timer? _debounce;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _controller = AdminPagedController(
      (page) => ref
          .read(adminRepositoryProvider)
          .getStudents(search: _search, page: page),
    )..refresh();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (value.trim() == _search) return;
      _search = value.trim();
      _controller.refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الطلاب')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              AppSpacing.sm,
              AppSpacing.screenHorizontal,
              AppSpacing.sm,
            ),
            child: AppInput(
              hint: 'ابحث بالاسم أو رقم الموبايل',
              prefixIcon: Icons.search_rounded,
              textInputAction: TextInputAction.search,
              onChanged: _onSearch,
            ),
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: _controller,
              builder: (context, _) => RefreshIndicator(
                onRefresh: _controller.refresh,
                child: _buildList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    final c = _controller;
    if (c.initialLoading) return const ShimmerList(count: 6);
    if (c.items.isEmpty && c.error != null) {
      return AdminScrollable(
        child: AdminErrorView(
          error: c.error!,
          onRetry: c.refresh,
          panelPath: 'students',
        ),
      );
    }
    if (c.items.isEmpty) {
      return AdminScrollable(
        child: AppEmptyState(
          icon: Icons.person_search_rounded,
          title: _search.isEmpty ? 'لا يوجد طلاب بعد' : 'لا نتائج للبحث',
          subtitle: _search.isEmpty ? null : 'جرّب اسم أو رقم تاني',
        ),
      );
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.extentAfter < 300) c.loadMore();
        return false;
      },
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenHorizontal,
          AppSpacing.xs,
          AppSpacing.screenHorizontal,
          AppSpacing.xxl,
        ),
        itemCount: c.items.length + (c.hasMore || c.error != null ? 1 : 0),
        separatorBuilder: (_, _) =>
            const SizedBox(height: AppSpacing.listItemSpacing),
        itemBuilder: (context, i) {
          if (i == c.items.length) {
            return Padding(
              padding: const EdgeInsets.all(AppSpacing.base),
              child: Center(
                child: c.error != null
                    ? TextButton(
                        onPressed: c.loadMore,
                        child: const Text('تعذر التحميل — إعادة المحاولة'),
                      )
                    : const CircularProgressIndicator(),
              ),
            );
          }
          final student = c.items[i];
          return _StudentCard(
            student: student,
            onTap: () => context.push(
              adminStudentDetailsPath(student.id),
              extra: student,
            ),
          );
        },
      ),
    );
  }
}

class _StudentCard extends StatelessWidget {
  const _StudentCard({required this.student, required this.onTap});

  final AdminStudent student;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final s = student;
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          _Avatar(student: s),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.name.isEmpty ? 'طالب #${s.id}' : s.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleSmall,
                ),
                Text(
                  s.mobile,
                  textDirection: TextDirection.ltr,
                  style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.md,
                  children: [
                    _Meta(
                      icon: Icons.menu_book_rounded,
                      label: '${s.subjectsCount} مادة',
                    ),
                    _Meta(
                      icon: Icons.access_time_rounded,
                      label: s.lastLoginAt == null
                          ? 'لم يسجل دخول'
                          : 'آخر دخول ${displayDate(s.lastLoginAt!)}',
                    ),
                  ],
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_left_rounded,
            color: cs.onSurface.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.student, this.radius = 24});

  final AdminStudent student;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final url = student.avatarUrl;
    return CircleAvatar(
      radius: radius,
      backgroundColor: cs.primaryContainer,
      foregroundImage: url == null
          ? null
          : ResizeImage(
              CachedNetworkImageProvider(url),
              width: (radius * 2 * MediaQuery.devicePixelRatioOf(context))
                  .round(),
            ),
      child: Text(
        student.name.isEmpty ? '?' : student.name.characters.first,
        style: TextStyle(
          fontFamily: 'Cairo',
          color: cs.onPrimaryContainer,
          fontWeight: FontWeight.w700,
          fontSize: radius * 0.75,
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
        ),
      ],
    );
  }
}

/// One student: subscriptions (with تفعيل/تمديد/إلغاء and a new-subscription
/// button), registered devices (removable) and exam results.
class AdminStudentDetailsScreen extends ConsumerWidget {
  const AdminStudentDetailsScreen({
    super.key,
    required this.studentId,
    this.preview,
  });

  final int studentId;

  /// The list row, shown in the header while the details load.
  final AdminStudent? preview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final details = ref.watch(adminStudentDetailsProvider(studentId));
    void reload() => ref.invalidate(adminStudentDetailsProvider(studentId));
    final student = details.valueOrNull?.student ?? preview;

    return Scaffold(
      appBar: AppBar(title: Text(student?.name ?? 'الطالب')),
      floatingActionButton: student == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () async {
                if (await showAddSubscriptionSheet(context, student: student)) {
                  reload();
                }
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('اشتراك جديد'),
            ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.refresh(adminStudentDetailsProvider(studentId).future),
        child: details.when(
          loading: () => const ShimmerList(count: 4),
          error: (e, _) => AdminScrollable(
            child: AdminErrorView(
              error: e,
              onRetry: reload,
              panelPath: 'students/$studentId',
            ),
          ),
          data: (d) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              AppSpacing.base,
              AppSpacing.screenHorizontal,
              96,
            ),
            children: [
              _StudentHeader(student: d.student),
              const SectionHeader(
                title: 'الاشتراكات',
                icon: Icons.card_membership_rounded,
              ),
              if (d.subscriptions.isEmpty)
                const _EmptyLine('لا توجد اشتراكات')
              else
                for (final s in d.subscriptions) ...[
                  AdminSubscriptionTile(
                    subscription: s,
                    showStudent: false,
                    onChanged: reload,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
              const SectionHeader(
                title: 'الأجهزة',
                icon: Icons.devices_rounded,
              ),
              if (d.devices.isEmpty)
                const _EmptyLine('لا توجد أجهزة مسجلة')
              else
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (final device in d.devices)
                        _DeviceTile(
                          device: device,
                          onRemove: () async {
                            final confirmed = await confirmAdminAction(
                              context,
                              title: 'حذف الجهاز',
                              message:
                                  'هيقدر الطالب يسجل دخول من جهاز جديد مكانه. متأكد؟',
                              confirmLabel: 'حذف',
                              destructive: true,
                            );
                            if (!confirmed || !context.mounted) return;
                            final ok = await runAdminAction(
                              context,
                              () => ref
                                  .read(adminRepositoryProvider)
                                  .removeStudentDevice(studentId, device.id),
                              successMessage: 'تم حذف الجهاز',
                            );
                            if (ok) reload();
                          },
                        ),
                    ],
                  ),
                ),
              const SectionHeader(
                title: 'نتائج الامتحانات',
                icon: Icons.quiz_rounded,
              ),
              if (d.examResults.isEmpty)
                const _EmptyLine('لم يحل أي امتحان بعد')
              else
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (final r in d.examResults) _ExamResultTile(result: r),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudentHeader extends StatelessWidget {
  const _StudentHeader({required this.student});

  final AdminStudent student;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final s = student;
    return AppCard(
      child: Row(
        children: [
          _Avatar(student: s, radius: 30),
          const SizedBox(width: AppSpacing.base),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.name, style: text.titleMedium),
                Text(
                  s.mobile,
                  textDirection: TextDirection.ltr,
                  style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  s.lastLoginAt == null
                      ? 'لم يسجل دخول بعد'
                      : 'آخر دخول ${displayDate(s.lastLoginAt!)}',
                  style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          if (!s.isActive)
            const StatusBadge(type: StatusType.locked, label: 'موقوف'),
        ],
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({required this.device, required this.onRemove});

  final AdminDevice device;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final platform = device.platform?.toLowerCase() ?? '';
    return ListTile(
      leading: Icon(
        platform.contains('ios')
            ? Icons.phone_iphone_rounded
            : Icons.phone_android_rounded,
        color: cs.primary,
      ),
      title: Text(device.name.isEmpty ? 'جهاز #${device.id}' : device.name),
      subtitle: device.lastUsedAt == null
          ? null
          : Text('آخر استخدام ${displayDate(device.lastUsedAt!)}'),
      trailing: IconButton(
        tooltip: 'حذف الجهاز',
        icon: Icon(Icons.delete_outline_rounded, color: cs.error),
        onPressed: onRemove,
      ),
    );
  }
}

class _ExamResultTile extends StatelessWidget {
  const _ExamResultTile({required this.result});

  final AdminExamResult result;

  @override
  Widget build(BuildContext context) {
    final r = result;
    String fmt(num n) => n == n.roundToDouble() ? '${n.toInt()}' : '$n';
    return ListTile(
      title: Text(r.title.isEmpty ? 'امتحان' : r.title),
      subtitle: r.submittedAt == null
          ? null
          : Text(displayDate(r.submittedAt!)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${fmt(r.score)} / ${fmt(r.total)}',
            textDirection: TextDirection.ltr,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          if (r.passed != null) ...[
            const SizedBox(width: AppSpacing.sm),
            StatusBadge(
              type: r.passed! ? StatusType.success : StatusType.error,
              label: r.passed! ? 'ناجح' : 'راسب',
              showIcon: false,
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyLine extends StatelessWidget {
  const _EmptyLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
