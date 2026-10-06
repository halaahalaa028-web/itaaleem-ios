import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:itaaleem/core/error/failure.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';
import 'package:itaaleem/core/widgets/app_button.dart';
import 'package:itaaleem/core/widgets/app_card.dart';
import 'package:itaaleem/core/widgets/app_input.dart';
import 'package:itaaleem/core/widgets/status_badge.dart';
import 'package:itaaleem/features/admin/data/models/admin_models.dart';
import 'package:itaaleem/features/admin/presentation/providers/admin_provider.dart';
import 'package:itaaleem/features/admin/presentation/widgets/admin_widgets.dart';

/// One subscription row: student, subject, state and end date. Tapping it
/// opens [showSubscriptionActions]; [onChanged] fires after any successful
/// action so the owning list can reload.
class AdminSubscriptionTile extends ConsumerWidget {
  const AdminSubscriptionTile({
    super.key,
    required this.subscription,
    required this.onChanged,
    this.showStudent = true,
  });

  final AdminSubscription subscription;
  final VoidCallback onChanged;

  /// `false` on the student-details screen, where the student is implied.
  final bool showStudent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final s = subscription;
    final (StatusType type, String label) = subscriptionStatus(s);
    final expires = s.expiresAt;
    final subjectName = s.subjectName.isEmpty
        ? 'مادة #${s.subjectId}'
        : s.subjectName;

    return AppCard(
      onTap: () => showSubscriptionActions(context, ref, s, onChanged),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  showStudent
                      ? (s.studentName.isEmpty
                            ? 'طالب #${s.studentId}'
                            : s.studentName)
                      : subjectName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleSmall,
                ),
                if (showStudent) ...[
                  const SizedBox(height: 2),
                  Text(
                    subjectName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodyMedium?.copyWith(color: cs.primary),
                  ),
                ],
                const SizedBox(height: AppSpacing.xs),
                Text(
                  expires == null
                      ? 'اشتراك دائم'
                      : '${s.isExpired ? 'انتهى في' : 'ينتهي في'} ${displayDate(expires)}',
                  style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          StatusBadge(type: type, label: label),
        ],
      ),
    );
  }
}

(StatusType, String) subscriptionStatus(AdminSubscription s) {
  if (s.isCancelled) return (StatusType.locked, 'ملغي');
  if (s.isPending) return (StatusType.pending, 'قيد الانتظار');
  if (s.isExpired) return (StatusType.error, 'منتهي');
  if (s.isActive) return (StatusType.success, 'نشط');
  return (StatusType.info, s.status.isEmpty ? 'غير معروف' : s.status);
}

/// تفعيل / تمديد / إلغاء for one subscription.
Future<void> showSubscriptionActions(
  BuildContext context,
  WidgetRef ref,
  AdminSubscription s,
  VoidCallback onChanged,
) async {
  final repo = ref.read(adminRepositoryProvider);
  final action = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(
              '${s.studentName} — ${s.subjectName}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          if (!s.isActive)
            ListTile(
              leading: const Icon(Icons.check_circle_outline_rounded),
              title: const Text('تفعيل'),
              onTap: () => Navigator.pop(context, 'activate'),
            ),
          ListTile(
            leading: const Icon(Icons.update_rounded),
            title: const Text('تمديد'),
            onTap: () => Navigator.pop(context, 'extend'),
          ),
          if (!s.isCancelled)
            ListTile(
              leading: Icon(
                Icons.cancel_rounded,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                'إلغاء الاشتراك',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: () => Navigator.pop(context, 'cancel'),
            ),
        ],
      ),
    ),
  );
  if (action == null || !context.mounted) return;

  var ok = false;
  switch (action) {
    case 'activate':
      ok = await runAdminAction(
        context,
        () => repo.updateSubscription(s.id, {'status': 'active'}),
        successMessage: 'تم تفعيل الاشتراك',
      );
    case 'extend':
      final base = s.expiresAt != null && s.expiresAt!.isAfter(DateTime.now())
          ? s.expiresAt!
          : DateTime.now();
      final newDate = await pickExpiryDate(context, from: base);
      if (newDate == null || !context.mounted) return;
      ok = await runAdminAction(
        context,
        () => repo.updateSubscription(s.id, {
          'status': 'active',
          'expires_at': apiDate(newDate),
        }),
        successMessage: 'تم تمديد الاشتراك حتى ${displayDate(newDate)}',
      );
    case 'cancel':
      final confirmed = await confirmAdminAction(
        context,
        title: 'إلغاء الاشتراك',
        message: 'هيتقفل على ${s.studentName} محتوى ${s.subjectName}. متأكد؟',
        confirmLabel: 'إلغاء الاشتراك',
        destructive: true,
      );
      if (!confirmed || !context.mounted) return;
      ok = await runAdminAction(
        context,
        () => repo.cancelSubscription(s.id),
        successMessage: 'تم إلغاء الاشتراك',
      );
  }
  if (ok) onChanged();
}

/// Quick durations from [from], plus a custom date. `null` = dismissed.
Future<DateTime?> pickExpiryDate(
  BuildContext context, {
  required DateTime from,
}) async {
  DateTime addMonths(int m) => DateTime(from.year, from.month + m, from.day);
  final choice = await showModalBottomSheet<Object>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (months, label) in const [
            (1, 'شهر'),
            (3, '3 شهور'),
            (6, '6 شهور (ترم)'),
            (12, 'سنة'),
          ])
            ListTile(
              leading: const Icon(Icons.event_repeat_rounded),
              title: Text('+ $label'),
              subtitle: Text('حتى ${displayDate(addMonths(months))}'),
              onTap: () => Navigator.pop(context, months),
            ),
          ListTile(
            leading: const Icon(Icons.calendar_month_rounded),
            title: const Text('تاريخ مخصص'),
            onTap: () => Navigator.pop(context, 'custom'),
          ),
        ],
      ),
    ),
  );
  if (choice is int) return addMonths(choice);
  if (choice == 'custom' && context.mounted) {
    final now = DateTime.now();
    return showDatePicker(
      context: context,
      initialDate: from.isBefore(now) ? now : from,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
    );
  }
  return null;
}

/// "اشتراك جديد": pick a student (unless [student] is given) and a subject,
/// then a duration. Returns `true` once created.
Future<bool> showAddSubscriptionSheet(
  BuildContext context, {
  AdminStudent? student,
}) async {
  final created = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _AddSubscriptionSheet(student: student),
  );
  return created == true;
}

class _AddSubscriptionSheet extends ConsumerStatefulWidget {
  const _AddSubscriptionSheet({this.student});

  final AdminStudent? student;

  @override
  ConsumerState<_AddSubscriptionSheet> createState() =>
      _AddSubscriptionSheetState();
}

class _AddSubscriptionSheetState extends ConsumerState<_AddSubscriptionSheet> {
  AdminStudent? _student;
  int? _subjectId;

  /// Months; `0` = lifetime.
  int _months = 1;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _student = widget.student;
  }

  Future<void> _pickStudent() async {
    final picked = await showModalBottomSheet<AdminStudent>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => const _StudentPickerSheet(),
    );
    if (picked != null) setState(() => _student = picked);
  }

  Future<void> _save() async {
    final student = _student;
    final subjectId = _subjectId;
    if (student == null || subjectId == null) return;
    setState(() => _saving = true);
    final now = DateTime.now();
    final ok = await runAdminAction(
      context,
      () => ref.read(adminRepositoryProvider).createSubscription({
        'student_id': student.id,
        'subject_id': subjectId,
        'status': 'active',
        'starts_at': apiDate(now),
        'expires_at': _months == 0
            ? null
            : apiDate(DateTime(now.year, now.month + _months, now.day)),
      }),
      successMessage: 'تمت إضافة الاشتراك',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final subjects = ref.watch(adminSubjectsProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.screenHorizontal,
        right: AppSpacing.screenHorizontal,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.base,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('اشتراك جديد', style: text.titleMedium),
            const SizedBox(height: AppSpacing.base),
            Text('الطالب', style: text.labelLarge),
            const SizedBox(height: AppSpacing.xs),
            AppCard(
              onTap: widget.student == null ? _pickStudent : null,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.base,
                vertical: AppSpacing.md,
              ),
              child: Row(
                children: [
                  Icon(Icons.person_rounded, color: cs.primary),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      _student == null
                          ? 'اختر طالب'
                          : '${_student!.name} — ${_student!.mobile}',
                      style: text.bodyMedium?.copyWith(
                        color: _student == null ? cs.onSurfaceVariant : null,
                      ),
                    ),
                  ),
                  if (widget.student == null)
                    Icon(Icons.search_rounded, color: cs.onSurfaceVariant),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.base),
            Text('المادة', style: text.labelLarge),
            const SizedBox(height: AppSpacing.xs),
            subjects.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text(
                failureOf(e).message,
                style: text.bodySmall?.copyWith(color: cs.error),
              ),
              data: (items) => DropdownButtonFormField<int>(
                initialValue: _subjectId,
                isExpanded: true,
                hint: const Text('اختر المادة'),
                items: [
                  for (final s in items)
                    DropdownMenuItem(value: s.id, child: Text(s.name)),
                ],
                onChanged: (v) => setState(() => _subjectId = v),
              ),
            ),
            const SizedBox(height: AppSpacing.base),
            Text('المدة', style: text.labelLarge),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final (months, label) in const [
                  (1, 'شهر'),
                  (3, '3 شهور'),
                  (6, 'ترم'),
                  (12, 'سنة'),
                  (0, 'دائم'),
                ])
                  ChoiceChip(
                    label: Text(label),
                    selected: _months == months,
                    onSelected: (_) => setState(() => _months = months),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton.primary(
              'إضافة الاشتراك',
              loading: _saving,
              onPressed: _student == null || _subjectId == null || _saving
                  ? null
                  : _save,
            ),
          ],
        ),
      ),
    );
  }
}

/// Searchable student list returning the tapped [AdminStudent].
class _StudentPickerSheet extends ConsumerStatefulWidget {
  const _StudentPickerSheet();

  @override
  ConsumerState<_StudentPickerSheet> createState() =>
      _StudentPickerSheetState();
}

class _StudentPickerSheetState extends ConsumerState<_StudentPickerSheet> {
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
      _search = value;
      _controller.refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.75,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenHorizontal,
              ),
              child: AppInput(
                hint: 'ابحث بالاسم أو الرقم',
                prefixIcon: Icons.search_rounded,
                autofocus: true,
                onChanged: _onSearch,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: ListenableBuilder(
                listenable: _controller,
                builder: (context, _) {
                  if (_controller.initialLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (_controller.items.isEmpty && _controller.error != null) {
                    return AdminErrorView(
                      error: _controller.error!,
                      onRetry: _controller.refresh,
                      panelPath: 'students',
                    );
                  }
                  if (_controller.items.isEmpty) {
                    return const Center(child: Text('لا يوجد طلاب'));
                  }
                  return NotificationListener<ScrollNotification>(
                    onNotification: (n) {
                      if (n.metrics.extentAfter < 200) _controller.loadMore();
                      return false;
                    },
                    child: ListView.builder(
                      itemCount: _controller.items.length,
                      itemBuilder: (context, i) {
                        final s = _controller.items[i];
                        return ListTile(
                          leading: CircleAvatar(
                            child: Text(s.name.isEmpty ? '?' : s.name[0]),
                          ),
                          title: Text(s.name),
                          subtitle: Text(s.mobile),
                          onTap: () => Navigator.pop(context, s),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
