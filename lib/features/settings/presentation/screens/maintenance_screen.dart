import 'package:itaaleem/app/router/app_router.dart';
import 'package:itaaleem/features/settings/presentation/providers/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:itaaleem/core/theme/app_palette.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';
/// Shown in place of every screen except the login screen while
/// `maintenance_mode` is true in `GET /public/settings`.
class MaintenanceScreen extends ConsumerWidget {
  const MaintenanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final message = ref
        .watch(appSettingsProvider)
        .valueOrNull
        ?.maintenanceMessage;

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
                      color: context.palette.onPrimary.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.build_circle_rounded,
                      color: context.palette.onPrimary,
                      size: 52,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'التطبيق تحت الصيانة حالياً',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(color: context.palette.onPrimary, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    (message != null && message.isNotEmpty)
                        ? message
                        : 'نعمل حالياً على تحسين التطبيق، سنعود قريباً',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.palette.onPrimary.withValues(alpha: 0.9),
                    ),
                  ),
                  const SizedBox(height: 36),
                  OutlinedButton.icon(
                    onPressed: () => ref.invalidate(appSettingsProvider),
                    icon: Icon(Icons.refresh_rounded, color: context.palette.onPrimary),
                    label: Text(
                      'إعادة المحاولة',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.palette.onPrimary),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: context.palette.onPrimary),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextButton(
                    onPressed: () => context.go(loginPath),
                    child: Text(
                      'تسجيل الدخول',
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
