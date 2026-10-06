import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:itaaleem/core/error/failure.dart';
import 'package:itaaleem/core/theme/app_radius.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';
import 'package:itaaleem/core/theme/dynamic_theme.dart';
import 'package:itaaleem/core/widgets/app_error_state.dart';
import 'package:itaaleem/core/widgets/app_shimmer.dart';
import 'package:itaaleem/features/center_admin/data/center_admin_models.dart';
import 'package:itaaleem/features/center_admin/presentation/widgets/admin_common.dart';
import 'package:itaaleem/features/center_admin/providers/center_admin_providers.dart';

/// `GET` / `PUT /center-admin/settings` — name, phone and email are
/// editable; logo and colour are shown (changed from the web panel).
class CenterSettingsScreen extends ConsumerWidget {
  const CenterSettingsScreen({super.key});

  static const _path = 'settings';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(centerAdminRecordProvider(_path));
    return Scaffold(
      appBar: AppBar(title: const Text('إعدادات السنتر')),
      body: async.when(
        loading: () => const ShimmerList(count: 4),
        error: (e, _) => AppErrorState(
          message: failureOf(e).message,
          onRetry: () => ref.invalidate(centerAdminRecordProvider(_path)),
        ),
        data: (settings) => _SettingsForm(
          // Rebuilt with fresh values after a save.
          key: ValueKey(settings.json.hashCode),
          settings: settings,
        ),
      ),
    );
  }
}

class _SettingsForm extends ConsumerStatefulWidget {
  const _SettingsForm({super.key, required this.settings});

  final AdminRecord settings;

  @override
  ConsumerState<_SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends ConsumerState<_SettingsForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(
    text: _s.title == '—' ? '' : _s.title,
  );
  late final _phone = TextEditingController(text: _s.phone ?? '');
  late final _email = TextEditingController(text: _s.email ?? '');
  bool _saving = false;

  AdminRecord get _s => widget.settings;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    await runAdminAction(
      context,
      ref,
      () => ref.read(centerAdminRepositoryProvider).update('settings', {
        'name': _name.text.trim(),
        'phone': _phone.text.trim(),
        'email': _email.text.trim(),
      }),
      success: 'تم حفظ إعدادات السنتر',
    );
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final color = tryParseHexColor(
      _s.text(['primary_color', 'color', 'brand_color']),
    );
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Center(
            child: AdminAvatar(
              name: _s.title,
              imageUrl: _s.image,
              radius: 44,
              icon: _s.image == null ? Icons.apartment_rounded : null,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Center(
            child: Text(
              'اللوجو يتغيّر من لوحة الويب',
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'اسم السنتر',
              prefixIcon: Icon(Icons.apartment_rounded),
              border: OutlineInputBorder(),
            ),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'هذا الحقل مطلوب' : null,
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'رقم التواصل',
              prefixIcon: Icon(Icons.phone_rounded),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'البريد الإلكتروني',
              prefixIcon: Icon(Icons.email_rounded),
              border: OutlineInputBorder(),
            ),
            validator: (v) {
              final s = v?.trim() ?? '';
              if (s.isEmpty) return null;
              return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s)
                  ? null
                  : 'البريد الإلكتروني غير صحيح';
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color ?? scheme.primary,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: scheme.outlineVariant),
              ),
            ),
            title: const Text('لون السنتر'),
            subtitle: Text(
              _s.text(['primary_color', 'color', 'brand_color']) ??
                  'اللون الافتراضي',
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            onPressed: _saving ? null : _save,
            icon: _saving
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: scheme.onPrimary,
                    ),
                  )
                : const Icon(Icons.save_rounded),
            label: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}
