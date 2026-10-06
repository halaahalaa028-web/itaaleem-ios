import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:itaaleem/core/error/failure.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';
import 'package:itaaleem/core/widgets/app_toast.dart';
import 'package:itaaleem/features/center_admin/data/center_admin_models.dart';
import 'package:itaaleem/features/center_admin/presentation/widgets/admin_common.dart';
import 'package:itaaleem/features/center_admin/providers/center_admin_providers.dart';

/// A student's pending subscription request: their details, every subject
/// of the center as chips (the requested one pre-selected), a duration, and
/// "تفعيل".
class CenterRequestApproveScreen extends ConsumerStatefulWidget {
  const CenterRequestApproveScreen({super.key, required this.request});

  final AdminRecord request;

  @override
  ConsumerState<CenterRequestApproveScreen> createState() =>
      _CenterRequestApproveScreenState();
}

class _CenterRequestApproveScreenState
    extends ConsumerState<CenterRequestApproveScreen> {
  /// Starts with the subject the student asked for.
  late final Set<int> _selected = {
    ?widget.request.nestedId('subject'),
  }..removeWhere((id) => id <= 0);
  int _days = 30;
  bool _submitting = false;

  static const _durations = <(int, String)>[
    (30, 'شهر'),
    (90, '3 شهور'),
    (180, '6 شهور'),
    (365, 'سنة'),
  ];

  Future<void> _approve() async {
    if (_selected.isEmpty) {
      AppToast.showError(context, 'اختر مادة واحدة على الأقل');
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref
          .read(centerAdminRepositoryProvider)
          .approveRequest(
            widget.request,
            _selected.toList(),
            durationDays: _days,
          );
      if (!mounted) return;
      invalidateAdminSection(ref, 'subscriptions');
      AppToast.showSuccess(context, 'تم تفعيل الاشتراك');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      AppToast.showError(context, failureOf(e).message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final r = widget.request;
    final student = r.nested('student');
    final name = r.nestedName('student') ?? r.title;
    final subjectsAsync = ref.watch(centerSubjectsListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('تفعيل اشتراك')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(centerSubjectsListProvider.future),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Card(
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.base),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        AdminAvatar(
                          name: name,
                          imageUrl: student?.image,
                          radius: 28,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            name,
                            style: text.titleMedium?.copyWith(
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        adminStatusBadge(r.status),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if ((student?.phone ?? r.phone) case final phone?)
                      AdminInfoRow(
                        icon: Icons.phone_rounded,
                        label: 'الموبايل',
                        value: phone,
                      ),
                    if (r.nestedName('subject') case final subject?)
                      AdminInfoRow(
                        icon: Icons.menu_book_rounded,
                        label: 'المادة المطلوبة',
                        value: subject,
                      ),
                    AdminInfoRow(
                      icon: Icons.event_rounded,
                      label: 'تاريخ الطلب',
                      value: adminDate(r.date(['created_at', 'requested_at'])),
                    ),
                  ],
                ),
              ),
            ),
            const AdminSectionTitle('المواد المراد تفعيلها'),
            subjectsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text(
                failureOf(e).message,
                style: TextStyle(color: scheme.error),
              ),
              data: (subjects) => subjects.isEmpty
                  ? Text(
                      'لا توجد مواد في السنتر',
                      style: text.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    )
                  : Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        for (final s in subjects)
                          FilterChip(
                            label: Text(s.title),
                            selected: _selected.contains(s.id),
                            onSelected: (on) => setState(
                              () => on
                                  ? _selected.add(s.id)
                                  : _selected.remove(s.id),
                            ),
                          ),
                      ],
                    ),
            ),
            const AdminSectionTitle('مدة الاشتراك'),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final (days, label) in _durations)
                  ChoiceChip(
                    label: Text(label),
                    selected: _days == days,
                    onSelected: (_) => setState(() => _days = days),
                  ),
              ],
            ),
            const SizedBox(height: 96),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.base,
          ),
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            onPressed: _submitting ? null : _approve,
            icon: _submitting
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: scheme.onPrimary,
                    ),
                  )
                : const Icon(Icons.check_circle_rounded),
            label: Text(
              _selected.isEmpty ? 'تفعيل' : 'تفعيل (${_selected.length})',
            ),
          ),
        ),
      ),
    );
  }
}
