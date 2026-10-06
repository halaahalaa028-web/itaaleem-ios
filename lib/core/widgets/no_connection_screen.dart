import 'package:itaaleem/core/network/connectivity_provider.dart';
import 'package:flutter/material.dart';
import 'package:itaaleem/core/theme/app_radius.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:itaaleem/core/theme/app_palette.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';

/// Full-screen block shown whenever [connectivityStatusProvider] reports no
/// connectivity — replaces the routed app content entirely (wired in
/// [App.builder]) so no other screen is reachable while offline.
class NoConnectionScreen extends ConsumerWidget {
  const NoConnectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: context.palette.brandGradient),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 104,
                    height: 104,
                    decoration: BoxDecoration(
                      color: context.palette.onPrimary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: context.palette.onPrimary.withValues(
                          alpha: 0.35,
                        ),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      Icons.wifi_off_rounded,
                      color: context.palette.onPrimary,
                      size: 56,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'لا يوجد اتصال بالإنترنت',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.palette.onPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'تحقق من اتصالك بالواي فاي أو بيانات الجوال ثم أعد المحاولة',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.palette.onPrimary.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  FilledButton.icon(
                    onPressed: () => ref.invalidate(connectivityStatusProvider),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('إعادة المحاولة'),
                    style: FilledButton.styleFrom(
                      backgroundColor: context.palette.onPrimary,
                      foregroundColor: context.palette.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.button),
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
