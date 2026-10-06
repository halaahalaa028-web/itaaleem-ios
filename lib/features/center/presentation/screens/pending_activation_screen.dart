import 'package:itaaleem/app/router/app_router.dart';
import 'package:itaaleem/features/auth/presentation/providers/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:itaaleem/core/theme/app_palette.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';

/// Shown once the joined center's `subscription_status` (per `GET
/// /profile`) is `"pending"` — [AppRouter] redirects here and blocks the
/// back gesture, same as [MaintenanceScreen]/`CenterDeactivatedScreen`; the
/// only ways out are the center activating (student taps "تحديث الحالة" to
/// re-check) or logging out.
class PendingActivationScreen extends ConsumerStatefulWidget {
  const PendingActivationScreen({super.key});

  @override
  ConsumerState<PendingActivationScreen> createState() => _PendingActivationScreenState();
}

class _PendingActivationScreenState extends ConsumerState<PendingActivationScreen> {
  bool _refreshing = false;
  bool _loggingOut = false;

  Future<void> _refreshStatus() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .refreshProfile()
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      // AppRouter reacts automatically once/if the refreshed profile's
      // subscription_status actually changed — nothing further to do on
      // failure, the student just stays here and can retry.
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _logout() async {
    if (_loggingOut) return;
    setState(() => _loggingOut = true);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .logout()
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      // logout() already clears the local session regardless of outcome.
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
                      Icons.hourglass_top_rounded,
                      color: context.palette.gold,
                      size: 52,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'في انتظار التفعيل',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: context.palette.onPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'تم تسجيل طلبك بنجاح. في انتظار التفعيل من إدارة السنتر.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.palette.onPrimary.withValues(alpha: 0.9),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'سيتم إشعارك فور تفعيل حسابك',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.palette.onPrimary.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 36),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _refreshing ? null : _refreshStatus,
                      icon: _refreshing
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: context.palette.primary,
                              ),
                            )
                          : const Icon(Icons.refresh_rounded),
                      label: const Text('تحديث الحالة'),
                      style: FilledButton.styleFrom(
                        backgroundColor: context.palette.onPrimary,
                        foregroundColor: context.palette.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => context.push(contactCenterPath),
                      icon: Icon(Icons.phone_in_talk_rounded, color: context.palette.onPrimary),
                      label: Text(
                        'تواصل مع السنتر',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.palette.onPrimary),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: context.palette.onPrimary),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextButton.icon(
                    onPressed: _loggingOut ? null : _logout,
                    icon: _loggingOut
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: context.palette.onPrimary,
                            ),
                          )
                        : Icon(
                            Icons.logout_rounded,
                            color: context.palette.onPrimary.withValues(alpha: 0.7),
                            size: 18,
                          ),
                    label: Text(
                      'تسجيل خروج',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.palette.onPrimary.withValues(alpha: 0.7)),
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
