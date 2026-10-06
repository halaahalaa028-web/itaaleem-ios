import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:itaaleem/core/error/failure.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';
import 'package:itaaleem/core/widgets/app_empty_state.dart';
import 'package:itaaleem/core/widgets/app_error_state.dart';
import 'package:itaaleem/core/widgets/app_shimmer.dart';
import 'package:itaaleem/core/widgets/app_toast.dart';
import 'package:itaaleem/features/center_admin/data/center_admin_models.dart';
import 'package:itaaleem/features/center_admin/presentation/widgets/admin_search_bar.dart';
import 'package:itaaleem/features/center_admin/providers/center_admin_providers.dart';

/// The shared list engine of every admin section: optional search bar,
/// pull-to-refresh, infinite scroll, shimmer / empty / error-with-retry
/// states. Each screen only says what a row looks like ([itemBuilder]).
class AdminDataTable extends ConsumerStatefulWidget {
  const AdminDataTable({
    super.key,
    required this.path,
    required this.itemBuilder,
    this.filters = const {},
    this.searchHint,
    this.emptyTitle = 'لا توجد بيانات',
    this.emptyIcon = Icons.inbox_rounded,
    this.header,
    this.bottomPadding = AppSpacing.xl,
  });

  /// Section under `/center-admin/` (e.g. `students`).
  final String path;
  final Map<String, Object?> filters;

  /// Shows a search bar when set.
  final String? searchHint;
  final String emptyTitle;
  final IconData emptyIcon;

  /// Extra widget above the list (e.g. a filter row).
  final Widget? header;
  final double bottomPadding;
  final Widget Function(BuildContext context, AdminRecord record) itemBuilder;

  @override
  ConsumerState<AdminDataTable> createState() => _AdminDataTableState();
}

class _AdminDataTableState extends ConsumerState<AdminDataTable> {
  String _search = '';

  AdminListQuery get _query =>
      adminQuery(widget.path, search: _search, filters: widget.filters);

  bool _onScroll(ScrollNotification n) {
    if (n.metrics.pixels >= n.metrics.maxScrollExtent - 300) {
      ref.read(adminListProvider(_query).notifier).loadMore().catchError((
        Object e,
      ) {
        if (mounted) AppToast.showError(context, failureOf(e).message);
      });
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final query = _query;
    final async = ref.watch(adminListProvider(query));

    Widget body = async.when(
      skipLoadingOnRefresh: true,
      loading: () => const ShimmerList(count: 6),
      error: (error, _) => _Fill(
        child: AppErrorState(
          message: failureOf(error).message,
          onRetry: () => ref.invalidate(adminListProvider(query)),
        ),
      ),
      data: (state) {
        if (state.items.isEmpty) {
          return _Fill(
            child: AppEmptyState(
              icon: _search.isEmpty
                  ? widget.emptyIcon
                  : Icons.search_off_rounded,
              title: _search.isEmpty ? widget.emptyTitle : 'لا توجد نتائج',
            ),
          );
        }
        return NotificationListener<ScrollNotification>(
          onNotification: _onScroll,
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              widget.bottomPadding,
            ),
            itemCount: state.items.length + (state.hasMore ? 1 : 0),
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, i) {
              if (i >= state.items.length) {
                return const Padding(
                  padding: EdgeInsets.all(AppSpacing.base),
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  ),
                );
              }
              return widget.itemBuilder(context, state.items[i]);
            },
          ),
        );
      },
    );

    body = RefreshIndicator(
      onRefresh: () => ref.refresh(adminListProvider(query).future),
      child: body,
    );

    return Column(
      children: [
        if (widget.searchHint != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.xs,
            ),
            child: AdminSearchBar(
              hint: widget.searchHint!,
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
        ?widget.header,
        Expanded(child: body),
      ],
    );
  }
}

/// Full-height scrollable wrapper so pull-to-refresh works on empty/error.
class _Fill extends StatelessWidget {
  const _Fill({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: c.maxHeight,
          child: Center(child: child),
        ),
      ),
    );
  }
}
