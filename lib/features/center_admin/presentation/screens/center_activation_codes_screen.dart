import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:itaaleem/core/error/failure.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';
import 'package:itaaleem/core/widgets/app_toast.dart';
import 'package:itaaleem/features/center_admin/data/center_admin_models.dart';
import 'package:itaaleem/features/center_admin/presentation/widgets/admin_common.dart';
import 'package:itaaleem/features/center_admin/providers/center_admin_providers.dart';

/// `GET /center-admin/activation-codes` + "إنشاء كود تفعيل" (subjects +
/// duration → `POST activation-codes`), each code copyable.
class CenterActivationCodesScreen extends ConsumerWidget {
  const CenterActivationCodesScreen({super.key});

  static String? codeOf(AdminRecord r) =>
      r.text(['code', 'activation_code', 'value']);

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final created = await showModalBottomSheet<AdminRecord>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const _CreateCodeSheet(),
    );
    if (created == null || !context.mounted) return;
    ref.invalidate(centerActivationCodesProvider);
    await showDialog<void>(
      context: context,
      builder: (context) => _CodeDialog(code: codeOf(created) ?? '—'),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final async = ref.watch(centerActivationCodesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('أكواد التفعيل')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _create(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('إنشاء كود تفعيل'),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(centerActivationCodesProvider.future),
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _Message(
            icon: Icons.cloud_off_rounded,
            text: failureOf(e).message,
          ),
          data: (codes) => codes.isEmpty
              ? const _Message(
                  icon: Icons.vpn_key_outlined,
                  text: 'لا توجد أكواد بعد — أنشئ أول كود',
                )
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    96,
                  ),
                  itemCount: codes.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, i) {
                    final r = codes[i];
                    final code = codeOf(r) ?? '—';
                    final subjects = r
                        .list('subjects')
                        .map((s) => s.title)
                        .join('، ');
                    final months = r.count(['duration_months']);
                    final usedBy =
                        r.nestedName('student') ?? r.nestedName('used_by');
                    return AdminRecordCard(
                      title: code,
                      leading: AdminAvatar(
                        name: '',
                        icon: Icons.vpn_key_rounded,
                      ),
                      lines: [
                        if (subjects.isNotEmpty) subjects,
                        [
                          if (months != null) '$months شهر',
                          if (usedBy != null) 'استخدمه: $usedBy',
                          adminDate(r.date(['created_at'])),
                        ].join(' • '),
                      ],
                      trailing: IconButton(
                        tooltip: 'نسخ',
                        icon: Icon(Icons.copy_rounded, color: scheme.primary),
                        onPressed: () => _copy(context, code),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

void _copy(BuildContext context, String code) {
  Clipboard.setData(ClipboardData(text: code));
  AppToast.showSuccess(context, 'تم نسخ الكود');
}

class _CreateCodeSheet extends ConsumerStatefulWidget {
  const _CreateCodeSheet();

  @override
  ConsumerState<_CreateCodeSheet> createState() => _CreateCodeSheetState();
}

class _CreateCodeSheetState extends ConsumerState<_CreateCodeSheet> {
  final _selected = <int>{};
  int _months = 1;
  bool _submitting = false;

  static const _durations = <(int, String)>[
    (1, 'شهر'),
    (3, '3 شهور'),
    (6, '6 شهور'),
    (12, 'سنة'),
  ];

  Future<void> _submit() async {
    if (_selected.isEmpty) {
      AppToast.showError(context, 'اختر مادة واحدة على الأقل');
      return;
    }
    setState(() => _submitting = true);
    try {
      final created = await ref
          .read(centerAdminRepositoryProvider)
          .createActivationCode(
            subjectIds: _selected.toList(),
            durationMonths: _months,
          );
      if (mounted) Navigator.of(context).pop(created);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      AppToast.showError(context, failureOf(e).message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final subjectsAsync = ref.watch(centerSubjectsListProvider);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'إنشاء كود تفعيل',
              style: text.titleMedium?.copyWith(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w800,
              ),
            ),
            const AdminSectionTitle('المواد'),
            subjectsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text(failureOf(e).message),
              data: (subjects) => Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final s in subjects)
                    FilterChip(
                      label: Text(s.title),
                      selected: _selected.contains(s.id),
                      onSelected: (on) => setState(
                        () => on ? _selected.add(s.id) : _selected.remove(s.id),
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
                for (final (months, label) in _durations)
                  ChoiceChip(
                    label: Text(label),
                    selected: _months == months,
                    onSelected: (_) => setState(() => _months = months),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.vpn_key_rounded),
              label: const Text('إنشاء الكود'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CodeDialog extends StatelessWidget {
  const _CodeDialog({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('تم إنشاء الكود'),
      content: Container(
        padding: const EdgeInsets.all(AppSpacing.base),
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: SelectableText(
          code,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: scheme.onPrimaryContainer,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إغلاق'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size(64, 44)),
          onPressed: () => _copy(context, code),
          icon: const Icon(Icons.copy_rounded),
          label: const Text('نسخ'),
        ),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Scrollable so pull-to-refresh works on the empty / error state.
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        const SizedBox(height: 80),
        Icon(icon, size: 56, color: scheme.onSurfaceVariant),
        const SizedBox(height: AppSpacing.md),
        Text(
          text,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
