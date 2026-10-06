import 'package:itaaleem/features/auth/presentation/providers/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:itaaleem/core/theme/app_palette.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';
/// Shown once [centerDeactivatedProvider] flips to `true` — the student's
/// joined center was deactivated server-side, so no content endpoint
/// (`/subjects`, `/exams`, `/banners`, …) will serve anything until the
/// center is reactivated. Blocks the back gesture like [MaintenanceScreen];
/// the only way out is logging out.
class CenterDeactivatedScreen extends ConsumerStatefulWidget {
  const CenterDeactivatedScreen({super.key});

  @override
  ConsumerState<CenterDeactivatedScreen> createState() =>
      _CenterDeactivatedScreenState();
}

class _CenterDeactivatedScreenState
    extends ConsumerState<CenterDeactivatedScreen> {
  bool _loggingOut = false;

  Future<void> _logout() async {
    if (_loggingOut) return;
    setState(() => _loggingOut = true);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .logout()
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      // `logout()` already clears the local session regardless of whether
      // the server call itself succeeds — [AppRouter] reacts to the auth
      // state change either way, so nothing further to do here.
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: DecoratedBox(
          decoration: BoxDecoration(gradient: context.palette.brandGradient),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsetsDirectional.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: context.palette.gold.withValues(alpha: 0.22),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.warning_amber_rounded,
                      color: context.palette.gold,
                      size: 52,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'السنتر غير متاح حالياً',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: context.palette.onPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'تواصل مع إدارة السنتر لمزيد من المعلومات.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.palette.onPrimary.withValues(alpha: 0.9),
                    ),
                  ),
                  const SizedBox(height: 36),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _loggingOut ? null : _logout,
                      icon: _loggingOut
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: context.palette.onPrimary,
                              ),
                            )
                          : Icon(
                              Icons.logout_rounded,
                              color: context.palette.onPrimary,
                            ),
                      label: Text(
                        'تسجيل خروج',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.palette.onPrimary),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: context.palette.onPrimary),
                      ),
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
