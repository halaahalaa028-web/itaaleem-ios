import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';
import 'package:itaaleem/core/widgets/app_empty_state.dart';
import 'package:itaaleem/core/widgets/app_shimmer.dart';
import 'package:itaaleem/features/admin/data/models/admin_models.dart';
import 'package:itaaleem/features/admin/presentation/providers/admin_provider.dart';
import 'package:itaaleem/features/admin/presentation/widgets/admin_subscription_widgets.dart';
import 'package:itaaleem/features/admin/presentation/widgets/admin_widgets.dart';

const _filters = <String?, String>{
  'active': 'نشط',
  'pending': 'قيد الانتظار',
  'expired': 'منتهي',
  'cancelled': 'ملغي',
  null: 'الكل',
};

/// All subject subscriptions, filtered by state, with تفعيل / تمديد / إلغاء
/// per row (see [showSubscriptionActions]) and a new-subscription FAB.
class AdminSubscriptionsScreen extends ConsumerStatefulWidget {
  const AdminSubscriptionsScreen({super.key, this.initialStatus});

  /// `?status=` from the route (e.g. the dashboard's "طلبات جديدة" card);
  /// defaults to active.
  final String? initialStatus;

  @override
  ConsumerState<AdminSubscriptionsScreen> createState() =>
      _AdminSubscriptionsScreenState();
}

class _AdminSubscriptionsScreenState
    extends ConsumerState<AdminSubscriptionsScreen> {
  late String? _status = _filters.containsKey(widget.initialStatus)
      ? widget.initialStatus
      : 'active';
  late final AdminPagedController<AdminSubscription> _controller;

  @override
  void initState() {
    super.initState();
    _controller = AdminPagedController(
      (page) => ref
          .read(adminRepositoryProvider)
          .getSubscriptions(status: _status, page: page),
    )..refresh();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setStatus(String? status) {
    if (status == _status) return;
    setState(() => _status = status);
    _controller.refresh();
  }

  void _reloadAll() {
    _controller.refresh();
    ref.invalidate(adminStatsProvider);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الاشتراكات')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          if (await showAddSubscriptionSheet(context)) _reloadAll();
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('اشتراك جديد'),
      ),
      body: Column(
        children: [
          const SizedBox(height: AppSpacing.sm),
          AdminFilterChips<String?>(
            options: _filters,
            selected: _status,
            onSelected: _setStatus,
          ),
          const SizedBox(height: AppSpacing.sm),
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
          panelPath: 'subject-subscriptions',
        ),
      );
    }
    if (c.items.isEmpty) {
      return const AdminScrollable(
        child: AppEmptyState(
          icon: Icons.card_membership_rounded,
          title: 'لا توجد اشتراكات بهذه الحالة',
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
          96,
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
          return AdminSubscriptionTile(
            subscription: c.items[i],
            onChanged: _reloadAll,
          );
        },
      ),
    );
  }
}
