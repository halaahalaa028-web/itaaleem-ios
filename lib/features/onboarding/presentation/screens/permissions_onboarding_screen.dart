import 'package:itaaleem/features/onboarding/presentation/providers/permissions_onboarding_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:itaaleem/core/theme/app_palette.dart';
import 'package:itaaleem/core/theme/app_radius.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';

/// Shown once, on the app's very first launch (or right after a fresh
/// install), before login — asks for the permission the app actually
/// uses (notifications for FCM) with a plain-language reason. "متابعة" always advances regardless of
/// what was granted/denied; nothing here is a hard gate, since every feature
/// that needs a permission re-checks/re-requests it itself when actually
/// used.
class PermissionsOnboardingScreen extends ConsumerStatefulWidget {
  const PermissionsOnboardingScreen({super.key});

  @override
  ConsumerState<PermissionsOnboardingScreen> createState() =>
      _PermissionsOnboardingScreenState();
}

enum _PermissionChoice { undecided, granted, denied }

class _PermissionsOnboardingScreenState
    extends ConsumerState<PermissionsOnboardingScreen> {
  final Map<Permission, _PermissionChoice> _choices = {
    Permission.notification: _PermissionChoice.undecided,
  };

  bool _continuing = false;

  Future<void> _allow(Permission permission) async {
    final result = await permission.request();
    if (!mounted) return;
    setState(() {
      _choices[permission] = result.isGranted
          ? _PermissionChoice.granted
          : _PermissionChoice.denied;
    });
  }

  void _deny(Permission permission) {
    setState(() => _choices[permission] = _PermissionChoice.denied);
  }

  Future<void> _continue() async {
    if (_continuing) return;
    setState(() => _continuing = true);
    await ref.read(permissionsOnboardingSeenProvider.notifier).markSeen();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(24, 28, 24, 8),
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      gradient: context.palette.brandGradient,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.shield_moon_rounded,
                      color: context.palette.onPrimary,
                      size: 34,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.base),
                  Text(
                    'قبل ما نبدأ',
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'نحتاج بعض الأذونات عشان التطبيق يشتغل بأفضل شكل ليك',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsetsDirectional.all(AppSpacing.screenHorizontal),
                children: [
                  _PermissionTile(
                    icon: Icons.notifications_active_rounded,
                    title: 'الإشعارات',
                    description:
                        'عشان توصلك إشعارات المحاضرات والامتحانات الجديدة أول بأول',
                    choice: _choices[Permission.notification]!,
                    onAllow: () => _allow(Permission.notification),
                    onDeny: () => _deny(Permission.notification),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 20),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _continuing ? null : _continue,
                  style: FilledButton.styleFrom(
                    backgroundColor: context.palette.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.button),
                    ),
                  ),
                  child: _continuing
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation(
                              context.palette.onPrimary,
                            ),
                          ),
                        )
                      : Text(
                          'متابعة',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: context.palette.onPrimary,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PermissionTile extends StatelessWidget {
  const _PermissionTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.choice,
    required this.onAllow,
    required this.onDeny,
  });

  final IconData icon;
  final String title;
  final String description;
  final _PermissionChoice choice;
  final VoidCallback onAllow;
  final VoidCallback onDeny;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final decided = choice != _PermissionChoice.undecided;

    return Container(
      padding: const EdgeInsetsDirectional.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: context.palette.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(icon, color: context.palette.primary, size: 22),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      description,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              if (choice == _PermissionChoice.granted)
                Icon(Icons.check_circle_rounded, color: context.palette.success)
              else if (choice == _PermissionChoice.denied)
                Icon(
                  Icons.cancel_rounded,
                  color: colorScheme.onSurface.withValues(alpha: 0.3),
                ),
            ],
          ),
          if (!decided) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onDeny,
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.button),
                      ),
                    ),
                    child: const Text('رفض'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: onAllow,
                    style: FilledButton.styleFrom(
                      backgroundColor: context.palette.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.button),
                      ),
                    ),
                    child: const Text('سماح'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
