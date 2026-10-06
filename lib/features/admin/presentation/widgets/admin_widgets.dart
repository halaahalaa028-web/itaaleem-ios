import 'package:go_router/go_router.dart';
import 'package:itaaleem/features/center_admin/presentation/center_admin_routes.dart';
import 'package:flutter/material.dart';
import 'package:itaaleem/core/config/admin_config.dart';
import 'package:itaaleem/core/error/failure.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';
import 'package:itaaleem/core/utils/safe_url.dart';
import 'package:itaaleem/core/widgets/app_button.dart';
import 'package:itaaleem/core/widgets/app_empty_state.dart';
import 'package:itaaleem/core/widgets/app_error_state.dart';
import 'package:itaaleem/core/widgets/app_toast.dart';
import 'package:itaaleem/features/admin/data/models/admin_models.dart';
import 'package:itaaleem/features/admin/data/repositories/admin_repository.dart';
import 'package:url_launcher/url_launcher.dart' show LaunchMode;

/// Opens the full Filament panel (optionally at [path], e.g. `subjects`)
/// in the browser.
Future<void> openAdminPanel(BuildContext context, {String? path}) async {
  final base = AdminConfig.panelUrl;
  final uri = Uri.parse(
    path == null ? base : '${base.replaceAll(RegExp(r'/$'), '')}/$path',
  );
  final ok = await launchUrlSafely(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) AppToast.showError(context, 'تعذر فتح الرابط');
}

/// Load failure for an admin list: an endpoint the server doesn't have yet
/// gets a calm "coming soon" state with a shortcut to the web panel; any
/// other failure gets the usual retry state.
class AdminErrorView extends StatelessWidget {
  const AdminErrorView({
    super.key,
    required this.error,
    required this.onRetry,
    this.panelPath,
  });

  final Object error;
  final VoidCallback onRetry;

  /// Where "فتح لوحة التحكم الكاملة" lands for this screen.
  final String? panelPath;

  @override
  Widget build(BuildContext context) {
    if (isAdminEndpointMissing(error)) {
      return AppEmptyState(
        icon: Icons.construction_rounded,
        title: 'غير متاح بعد',
        subtitle: failureOf(error).message,
        action: AppButton.secondary(
          'فتح لوحة التحكم الكاملة',
          icon: Icons.open_in_new_rounded,
          expand: false,
          onPressed: () => context.push(centerAdminPath),
        ),
      );
    }
    return AppErrorState(message: failureOf(error).message, onRetry: onRetry);
  }
}

/// Keeps pull-to-refresh working on full-height empty/error states.
class AdminScrollable extends StatelessWidget {
  const AdminScrollable({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(height: constraints.maxHeight, child: child),
      ),
    );
  }
}

/// Yes/no confirmation; `true` only on an explicit confirm.
Future<bool> confirmAdminAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('إلغاء'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          style: destructive
              ? TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                )
              : null,
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result == true;
}

/// Runs a write [action] and reports it with a toast; returns whether it
/// succeeded so the caller can refresh.
Future<bool> runAdminAction(
  BuildContext context,
  Future<void> Function() action, {
  required String successMessage,
}) async {
  try {
    await action();
    if (context.mounted) AppToast.showSuccess(context, successMessage);
    return true;
  } catch (e) {
    if (context.mounted) AppToast.showError(context, failureOf(e).message);
    return false;
  }
}

/// Page-by-page loader for the paginated admin lists (students,
/// subscriptions): [refresh] restarts from page 1, [loadMore] appends the
/// next page while [hasMore].
class AdminPagedController<T> extends ChangeNotifier {
  AdminPagedController(this._fetch);

  final Future<AdminPage<T>> Function(int page) _fetch;

  final List<T> items = [];
  Object? error;
  bool loading = false;
  bool hasMore = true;
  int _page = 0;

  /// Bumped on every [refresh] so a slow response for an outdated query
  /// (e.g. the previous search text) is dropped instead of appended.
  int _generation = 0;
  bool _disposed = false;

  bool get initialLoading => loading && items.isEmpty;

  Future<void> refresh() async {
    _generation++;
    items.clear();
    _page = 0;
    hasMore = true;
    error = null;
    loading = false;
    await loadMore();
  }

  Future<void> loadMore() async {
    if (loading || !hasMore) return;
    final generation = _generation;
    loading = true;
    error = null;
    _notify();
    try {
      final page = await _fetch(_page + 1);
      if (generation != _generation) return;
      items.addAll(page.items);
      _page = page.currentPage;
      hasMore = page.hasMore && page.items.isNotEmpty;
    } catch (e) {
      if (generation != _generation) return;
      error = e;
    } finally {
      if (generation == _generation) {
        loading = false;
        _notify();
      }
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// A row of filter chips (e.g. نشط / منتهي / الكل).
class AdminFilterChips<T> extends StatelessWidget {
  const AdminFilterChips({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final Map<T, String> options;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
      ),
      child: Row(
        children: [
          for (final e in options.entries)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
              child: ChoiceChip(
                label: Text(e.value),
                selected: e.key == selected,
                onSelected: (_) => onSelected(e.key),
              ),
            ),
        ],
      ),
    );
  }
}
