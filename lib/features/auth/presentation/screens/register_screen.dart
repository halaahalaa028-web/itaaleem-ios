import 'package:itaaleem/app/router/app_router.dart';
import 'package:itaaleem/core/error/failure.dart';
import 'package:itaaleem/core/localization/generated/app_localizations.dart';
import 'package:itaaleem/core/utils/platform_utils.dart';
import 'package:itaaleem/core/widgets/app_input.dart';
import 'package:itaaleem/core/widgets/app_toast.dart';
import 'package:itaaleem/core/widgets/auth_shell.dart';
import 'package:itaaleem/features/auth/presentation/providers/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Registration is just the student's own details — which center/grade
/// they belong to is chosen afterwards via the center-search/select-grade
/// flow, not during sign-up.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _submitting = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  /// iOS only: sign up with the phone (default) or with the email.
  bool _useEmail = false;

  /// Server-side (422) field errors from the last failed submit — keyed by
  /// the API's own field names (`name`, `mobile`, `email`, `password`).
  Map<String, List<String>> _fieldErrors = const {};

  @override
  void dispose() {
    _fullNameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final l10n = AppLocalizations.of(context)!;

    setState(() {
      _submitting = true;
      _fieldErrors = const {};
    });
    final failure = await ref
        .read(authControllerProvider.notifier)
        .register(
          fullName: _fullNameController.text
              .trim()
              .split(RegExp(r'\s+'))
              .where((w) => w.isNotEmpty)
              .join(' '),
          // iOS sends only the chosen identifier; Android both, as before.
          mobile: PlatformUtils.flexibleSignUp && _useEmail
              ? ''
              : _mobileController.text.trim(),
          email: PlatformUtils.flexibleSignUp && !_useEmail
              ? ''
              : _emailController.text.trim(),
          password: _passwordController.text,
          passwordConfirmation: _confirmPasswordController.text,
        );
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _fieldErrors = failure is ValidationFailure
          ? failure.fieldErrors
          : const {};
    });

    if (failure != null) {
      // Email sign-up while the server still requires a mobile number.
      final mobileRequired =
          PlatformUtils.flexibleSignUp &&
          _useEmail &&
          _fieldErrors.containsKey('mobile');
      AppToast.showError(
        context,
        mobileRequired
            ? 'التسجيل بالبريد الإلكتروني غير متاح حالياً، سجّل برقم التليفون'
            : failure.message.isNotEmpty
            ? failure.message
            : l10n.genericError,
      );
    }
  }

  String? _errorFor(String field) => _fieldErrors[field]?.first;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Form(
      key: _formKey,
      child: AuthShell(
        title: 'إنشاء حساب جديد',
        subtitle: 'ابدأ رحلتك التعليمية معنا 🚀',
        headerFactor: 0.25,
        badgeSize: 64,
        onBack: () => context.go(loginPath),
        fields: [
          AppInput(
            label: 'الاسم الكامل',
            controller: _fullNameController,
            prefixIcon: Icons.person_outline_rounded,
            textInputAction: TextInputAction.next,
            errorText: _errorFor('name'),
            validator: (value) {
              final trimmed = value?.trim() ?? '';
              if (trimmed.isEmpty) {
                return l10n.fieldRequired;
              }
              final words = trimmed
                  .split(RegExp(r'\s+'))
                  .where((w) => w.isNotEmpty)
                  .toList();
              if (words.length < 3) {
                return 'الاسم لازم يكون ثلاثي على الأقل';
              }
              return null;
            },
          ),
          // iOS: choose phone or email — only the chosen field is shown
          // (and required). Android: both fields, unchanged.
          if (PlatformUtils.flexibleSignUp) ...[
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  label: Text('رقم التليفون'),
                  icon: Icon(Icons.phone_iphone_rounded),
                ),
                ButtonSegment(
                  value: true,
                  label: Text('البريد الإلكتروني'),
                  icon: Icon(Icons.email_rounded),
                ),
              ],
              selected: {_useEmail},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _useEmail = s.first),
            ),
            if (_useEmail)
              AppInput(
                label: 'البريد الإلكتروني',
                controller: _emailController,
                prefixIcon: Icons.email_rounded,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                errorText: _errorFor('email'),
                validator: (value) {
                  final v = value?.trim() ?? '';
                  if (v.isEmpty) return l10n.fieldRequired;
                  return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)
                      ? null
                      : 'البريد الإلكتروني غير صحيح';
                },
              )
            else
              AppInput(
                label: 'رقم الهاتف',
                controller: _mobileController,
                prefixIcon: Icons.phone_iphone_rounded,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                errorText: _errorFor('mobile'),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(11),
                ],
                validator: (value) {
                  final trimmed = value?.trim() ?? '';
                  if (trimmed.isEmpty) {
                    return l10n.fieldRequired;
                  }
                  if (!RegExp(r'^01[0-9]{9}$').hasMatch(trimmed)) {
                    return 'رقم الهاتف لازم يكون 11 رقم ويبدأ بـ 01';
                  }
                  return null;
                },
              ),
          ] else ...[
            AppInput(
              label: 'رقم الهاتف',
              controller: _mobileController,
              prefixIcon: Icons.phone_iphone_rounded,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              errorText: _errorFor('mobile'),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(11),
              ],
              validator: (value) {
                final trimmed = value?.trim() ?? '';
                if (trimmed.isEmpty) {
                  return l10n.fieldRequired;
                }
                if (!RegExp(r'^01[0-9]{9}$').hasMatch(trimmed)) {
                  return 'رقم الهاتف لازم يكون 11 رقم ويبدأ بـ 01';
                }
                return null;
              },
            ),
            AppInput(
              label: 'الإيميل (اختياري)',
              controller: _emailController,
              prefixIcon: Icons.email_rounded,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              errorText: _errorFor('email'),
            ),
          ],
          AppInput(
            label: 'كلمة المرور',
            controller: _passwordController,
            prefixIcon: Icons.lock_outline_rounded,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.next,
            errorText: _errorFor('password'),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                size: 20,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return l10n.fieldRequired;
              }
              if (value.length < 6) {
                return l10n.passwordTooShort;
              }
              return null;
            },
          ),
          AppInput(
            label: 'تأكيد كلمة المرور',
            controller: _confirmPasswordController,
            prefixIcon: Icons.lock_outline_rounded,
            obscureText: _obscureConfirmPassword,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirmPassword
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                size: 20,
              ),
              onPressed: () => setState(
                () => _obscureConfirmPassword = !_obscureConfirmPassword,
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return l10n.fieldRequired;
              }
              if (value != _passwordController.text) {
                return l10n.passwordsDontMatch;
              }
              return null;
            },
          ),
        ],
        action: AuthGradientButton(
          'إنشاء الحساب',
          onPressed: _submitting ? null : _submit,
          loading: _submitting,
        ),
        footer: AuthFooterLink(
          prompt: 'عندك حساب؟',
          action: 'سجل دخول',
          onTap: () => context.go(loginPath),
        ),
      ),
    );
  }
}
