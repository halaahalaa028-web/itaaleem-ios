import 'package:itaaleem/features/subjects/presentation/providers/subjects_providers.dart';
import 'dart:async';

import 'package:itaaleem/app/router/app_router.dart';
import 'package:itaaleem/core/error/failure.dart';
import 'package:itaaleem/core/utils/result.dart';
import 'package:itaaleem/features/activation/presentation/providers/activation_providers.dart';
import 'package:itaaleem/features/auth/presentation/providers/auth_controller.dart';
import 'package:itaaleem/features/courses/presentation/providers/courses_providers.dart';
import 'package:itaaleem/features/home/presentation/providers/home_subjects_provider.dart';
import 'package:flutter/material.dart';
import 'package:itaaleem/core/theme/app_radius.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:itaaleem/core/theme/app_palette.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';
/// Pushes [ActivationScreen] as a full-screen route on top of whatever tab
/// the student is currently on (the "المواد" tab's empty state, or the
/// subscribe-request sheet) — the code-redeem form is not a bottom-nav tab
/// of its own.
///
/// A real GoRouter route ([activationPath], see `app_router.dart`, which also
/// owns the `onActivated` callback). Uses [rootNavigatorKey] rather than a
/// local `BuildContext` so it stays safe to call from a widget (e.g. a
/// bottom sheet) that is popped and disposed right after.
Future<void> pushActivationScreen() {
  final context = rootNavigatorKey.currentContext;
  if (context == null) return Future.value();
  return context.push<void>(activationPath);
}

/// Redeem-an-activation-code screen, reached via [pushActivationScreen]
/// rather than as its own bottom-nav tab (`POST /activation/redeem`).
class ActivationScreen extends ConsumerStatefulWidget {
  const ActivationScreen({super.key, required this.onActivated});

  /// Called after a successful redeem so the shell can switch the student
  /// back to "الرئيسية" and show the newly activated course.
  final VoidCallback onActivated;

  @override
  ConsumerState<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends ConsumerState<ActivationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  bool _submitting = false;
  _ActivationOutcome? _outcome;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _submitting = true;
      _outcome = null;
    });

    // A demo ("دخول تجريبي") session has no real subscription to activate
    // server-side — simulate the same success flow locally instead of
    // hitting `POST /activate-code` with a session the API doesn't know.
    final isDemo =
        ref.read(authControllerProvider).valueOrNull?.isDemo ?? false;
    if (isDemo) {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _outcome = _ActivationOutcome.success(
          'تم تفعيل الكود بنجاح (وضع تجريبي)',
        );
      });
      _codeController.clear();
      return;
    }

    final useCase = ref.read(redeemActivationCodeUseCaseProvider);
    final result = await useCase(_codeController.text.trim());
    if (!mounted) return;

    switch (result) {
      case Ok<String>(:final value):
        // Reload courses/materials immediately so the newly activated
        // course shows up on the home tab without a manual app restart, and
        // refresh the student's own profile in case activation changed it
        // (e.g. subscription status).
        ref.invalidate(coursesProvider);
        ref.invalidate(availableCoursesProvider);
        ref.invalidate(homeSubjectsProvider);
        ref.invalidate(subjectsListProvider);
        ref.invalidate(subjectDetailsProvider);
        ref.invalidate(homeLessonsProvider);
        ref.invalidate(attachmentsProvider);
        ref.invalidate(lessonAttachmentsProvider);
        unawaited(ref.read(authControllerProvider.notifier).refreshProfile());
        setState(() {
          _submitting = false;
          _outcome = _ActivationOutcome.success(value);
        });
        _codeController.clear();
      case Err<String>(:final failure):
        setState(() {
          _submitting = false;
          _outcome = _ActivationOutcome.error(failure);
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تفعيل كود')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.xxl,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    decoration: BoxDecoration(
                      gradient: context.palette.brandGradient,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: context.palette.onPrimary.withValues(
                            alpha: 0.24,
                          ),
                          child: Icon(
                            Icons.qr_code_2_rounded,
                            color: context.palette.onPrimary,
                            size: 32,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.base),
                        Text(
                          'فعّل كورسك الآن',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: context.palette.onPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'أدخل كود التفعيل الذي حصلت عليه لبدء الكورس',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: context.palette.onPrimary.withValues(
                                  alpha: 0.85,
                                ),
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _codeController,
                          textAlign: TextAlign.center,
                          textCapitalization: TextCapitalization.characters,
                          inputFormatters: [_UpperCaseTextFormatter()],
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: 6,
                              ),
                          decoration: const InputDecoration(
                            hintText: 'XXXX-XXXX',
                            prefixIcon: Icon(
                              Icons.confirmation_number_rounded,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'أدخل كود التفعيل';
                            }
                            return null;
                          },
                          onFieldSubmitted: (_) => _submit(),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        FilledButton(
                          onPressed: _submitting ? null : _submit,
                          child: _submitting
                              ? SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(
                                      context.palette.onPrimary,
                                    ),
                                  ),
                                )
                              : const Text('تفعيل'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(scale: animation, child: child),
                    ),
                    child: _outcome == null
                        ? const SizedBox.shrink(key: ValueKey('empty'))
                        : _OutcomeBanner(
                            key: ValueKey(_outcome!.isSuccess),
                            outcome: _outcome!,
                            onViewCourses: widget.onActivated,
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActivationOutcome {
  const _ActivationOutcome._(this.isSuccess, this.message);

  factory _ActivationOutcome.success(String message) =>
      _ActivationOutcome._(true, message);

  factory _ActivationOutcome.error(Failure failure) =>
      _ActivationOutcome._(false, failure.message);

  final bool isSuccess;
  final String message;
}

class _OutcomeBanner extends StatelessWidget {
  const _OutcomeBanner({
    super.key,
    required this.outcome,
    required this.onViewCourses,
  });

  final _ActivationOutcome outcome;
  final VoidCallback onViewCourses;

  @override
  Widget build(BuildContext context) {
    final color = outcome.isSuccess
        ? context.palette.success
        : Theme.of(context).colorScheme.error;
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.all(18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(
            outcome.isSuccess
                ? Icons.check_circle_rounded
                : Icons.error_outline_rounded,
            color: color,
            size: 36,
          ),
          const SizedBox(height: 10),
          Text(
            outcome.message.isNotEmpty
                ? outcome.message
                : (outcome.isSuccess
                      ? 'تم تفعيل الكود بنجاح'
                      : 'حدث خطأ ما، حاول مرة أخرى'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          if (outcome.isSuccess) ...[
            const SizedBox(height: AppSpacing.md),
            TextButton(
              onPressed: onViewCourses,
              child: const Text('عرض كورساتي الآن'),
            ),
          ],
        ],
      ),
    );
  }
}

class _UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
