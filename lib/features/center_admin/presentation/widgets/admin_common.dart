import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:itaaleem/core/error/failure.dart';
import 'package:itaaleem/core/theme/app_radius.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';
import 'package:itaaleem/core/widgets/app_toast.dart';
import 'package:itaaleem/core/widgets/status_badge.dart';
import 'package:itaaleem/features/center_admin/data/center_admin_models.dart';
import 'package:itaaleem/features/center_admin/presentation/widgets/admin_data_table.dart';
import 'package:itaaleem/features/center_admin/providers/center_admin_providers.dart';

/// `2025/03/14`.
String adminDate(DateTime? d) => d == null
    ? '—'
    : '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

/// "منذ 3 أيام"-style for last-activity columns.
String adminAgo(DateTime? d) {
  if (d == null) return '—';
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 1) return 'الآن';
  if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
  if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
  if (diff.inDays < 30) return 'منذ ${diff.inDays} يوم';
  return adminDate(d);
}

/// Status pill for a subscription / banner / anything with a `status`.
Widget adminStatusBadge(String? status) {
  final (StatusType type, String label) = switch (status) {
    'active' ||
    'approved' ||
    'enabled' ||
    'published' => (StatusType.success, 'فعّال'),
    'expired' || 'ended' => (StatusType.error, 'منتهي'),
    'suspended' ||
    'paused' ||
    'inactive' ||
    'disabled' => (StatusType.warning, 'موقوف'),
    'cancelled' || 'canceled' => (StatusType.locked, 'ملغي'),
    'pending' => (StatusType.pending, 'قيد المراجعة'),
    null => (StatusType.info, 'غير محدد'),
    _ => (StatusType.info, status),
  };
  return StatusBadge(type: type, label: label);
}

/// Photo, else the first letter of [name].
class AdminAvatar extends StatelessWidget {
  const AdminAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.radius = 22,
    this.icon,
  });

  final String name;
  final String? imageUrl;
  final double radius;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final initial = name.trim().isEmpty ? '?' : name.trim().characters.first;
    return CircleAvatar(
      radius: radius,
      backgroundColor: scheme.secondaryContainer,
      foregroundImage: imageUrl == null
          ? null
          : CachedNetworkImageProvider(imageUrl!),
      child: icon != null
          ? Icon(icon, color: scheme.onSecondaryContainer, size: radius)
          : Text(
              initial,
              style: TextStyle(
                color: scheme.onSecondaryContainer,
                fontWeight: FontWeight.w800,
                fontSize: radius * 0.8,
              ),
            ),
    );
  }
}

/// The standard row card of every admin list.
class AdminRecordCard extends StatelessWidget {
  const AdminRecordCard({
    super.key,
    required this.title,
    this.leading,
    this.lines = const [],
    this.trailing,
    this.onTap,
    this.menu,
  });

  final String title;
  final Widget? leading;

  /// Secondary lines (empty ones are skipped).
  final List<String?> lines;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Edit / delete / … — shown as a ⋮ menu.
  final List<AdminMenuAction>? menu;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final shown = lines.whereType<String>().where((l) => l.trim().isNotEmpty);
    return Card(
      elevation: 1,
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.xs,
            AppSpacing.md,
          ),
          child: Row(
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: AppSpacing.md),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    for (final line in shown) ...[
                      const SizedBox(height: 2),
                      Text(
                        line,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: AppSpacing.sm),
                trailing!,
              ],
              if (menu != null && menu!.isNotEmpty)
                PopupMenuButton<AdminMenuAction>(
                  tooltip: 'خيارات',
                  icon: const Icon(Icons.more_vert_rounded),
                  onSelected: (a) => a.onTap(),
                  itemBuilder: (_) => [
                    for (final a in menu!)
                      PopupMenuItem(
                        value: a,
                        child: Row(
                          children: [
                            Icon(
                              a.icon,
                              size: 20,
                              color: a.destructive ? scheme.error : null,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              a.label,
                              style: a.destructive
                                  ? TextStyle(color: scheme.error)
                                  : null,
                            ),
                          ],
                        ),
                      ),
                  ],
                )
              else if (onTap != null)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: AppSpacing.xs),
                  child: Icon(
                    Icons.chevron_left_rounded,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class AdminMenuAction {
  const AdminMenuAction(
    this.label,
    this.icon,
    this.onTap, {
    this.destructive = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool destructive;
}

/// One input of [showAdminForm].
class AdminField {
  const AdminField(
    this.key,
    this.label, {
    this.icon,
    this.initial,
    this.required = false,
    this.keyboard,
    this.maxLines = 1,
    this.numeric = false,
  });

  final String key;
  final String label;
  final IconData? icon;
  final String? initial;
  final bool required;
  final TextInputType? keyboard;
  final int maxLines;
  final bool numeric;
}

/// A bottom-sheet form; resolves to the entered values (trimmed, empties
/// dropped) or `null` if dismissed. [extra] adds custom inputs (a switch, a
/// picker) — they write into the same map through the callback.
Future<Map<String, dynamic>?> showAdminForm(
  BuildContext context, {
  required String title,
  required List<AdminField> fields,
  String submitLabel = 'حفظ',
  List<Widget> Function(
    Map<String, dynamic> values,
    void Function(VoidCallback) setState,
  )?
  extra,
}) {
  final formKey = GlobalKey<FormState>();
  final controllers = {
    for (final f in fields) f.key: TextEditingController(text: f.initial),
  };
  final values = <String, dynamic>{};
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setState) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.base),
                for (final f in fields) ...[
                  TextFormField(
                    controller: controllers[f.key],
                    keyboardType: f.numeric ? TextInputType.number : f.keyboard,
                    inputFormatters: f.numeric
                        ? [FilteringTextInputFormatter.digitsOnly]
                        : null,
                    maxLines: f.maxLines,
                    decoration: InputDecoration(
                      labelText: f.label,
                      prefixIcon: f.icon == null ? null : Icon(f.icon),
                      border: const OutlineInputBorder(),
                    ),
                    validator: f.required
                        ? (v) => v == null || v.trim().isEmpty
                              ? 'هذا الحقل مطلوب'
                              : null
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                if (extra != null) ...extra(values, setState),
                const SizedBox(height: AppSpacing.sm),
                FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: () {
                    if (!(formKey.currentState?.validate() ?? false)) return;
                    final result = <String, dynamic>{...values};
                    for (final f in fields) {
                      final v = controllers[f.key]!.text.trim();
                      if (v.isEmpty) continue;
                      result[f.key] = f.numeric ? int.tryParse(v) ?? v : v;
                    }
                    Navigator.of(sheetContext).pop(result);
                  },
                  child: Text(submitLabel),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ).whenComplete(() {
    for (final c in controllers.values) {
      c.dispose();
    }
  });
}

Future<bool> confirmAdmin(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'تأكيد',
  bool destructive = false,
}) async {
  final scheme = Theme.of(context).colorScheme;
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: scheme.error,
                  foregroundColor: scheme.onError,
                )
              : null,
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Runs a write, then toasts [success] and refreshes the lists — or toasts
/// the Arabic failure.
Future<bool> runAdminAction(
  BuildContext context,
  WidgetRef ref,
  Future<void> Function() action, {
  required String success,
  String section = '',
}) async {
  try {
    await action();
    invalidateAdminSection(ref, section);
    if (context.mounted) AppToast.showSuccess(context, success);
    return true;
  } catch (e) {
    if (context.mounted) AppToast.showError(context, failureOf(e).message);
    return false;
  }
}

/// A searchable bottom-sheet picker over any section (`students`,
/// `subjects`, `teachers`).
Future<AdminRecord?> pickAdminRecord(
  BuildContext context, {
  required String path,
  required String title,
  Map<String, Object?> filters = const {},
}) {
  return showModalBottomSheet<AdminRecord>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.8,
      child: Column(
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          Expanded(
            child: AdminDataTable(
              path: path,
              filters: filters,
              searchHint: 'ابحث بالاسم',
              itemBuilder: (context, r) => AdminRecordCard(
                title: r.title,
                leading: AdminAvatar(name: r.title, imageUrl: r.image),
                lines: [r.phone ?? r.email],
                onTap: () => Navigator.pop(context, r),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Section title used on detail screens.
class AdminSectionTitle extends StatelessWidget {
  const AdminSectionTitle(this.title, {super.key, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

/// "label: value" row on detail screens.
class AdminInfoRow extends StatelessWidget {
  const AdminInfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Icon(icon, size: 18, color: scheme.primary),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '$label: ',
            style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          Expanded(
            child: Text(
              value ?? '—',
              style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Filter chips row from a section's options (e.g. pick a subject).
class AdminSubjectFilter extends ConsumerWidget {
  const AdminSubjectFilter({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final int? selected;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjects =
        ref
            .watch(adminListProvider(adminQuery('subjects')))
            .valueOrNull
            ?.items ??
        const <AdminRecord>[];
    if (subjects.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
            child: ChoiceChip(
              label: const Text('كل المواد'),
              selected: selected == null,
              onSelected: (_) => onChanged(null),
            ),
          ),
          for (final s in subjects)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
              child: ChoiceChip(
                label: Text(s.title),
                selected: selected == s.id,
                onSelected: (_) => onChanged(s.id),
              ),
            ),
        ],
      ),
    );
  }
}
