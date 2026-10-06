import 'dart:math' as math;

import 'package:itaaleem/core/providers/package_info_provider.dart';
import 'package:itaaleem/core/widgets/app_button.dart';
import 'package:itaaleem/core/widgets/app_toast.dart';
import 'package:itaaleem/core/widgets/auth_shell.dart';
import 'package:itaaleem/core/widgets/student_avatar.dart';
import 'package:itaaleem/app/router/app_router.dart';
import 'package:itaaleem/features/account/presentation/widgets/quick_link_card.dart';
import 'package:itaaleem/features/activation/presentation/screens/activation_screen.dart';
import 'package:itaaleem/features/auth/domain/entities/student.dart';
import 'package:itaaleem/features/auth/presentation/providers/auth_controller.dart';
import 'package:itaaleem/features/auth/presentation/screens/edit_profile_screen.dart';
import 'package:itaaleem/features/auth/presentation/widgets/pick_profile_image.dart';
import 'package:itaaleem/features/center/domain/entities/center_model.dart';
import 'package:itaaleem/features/center/presentation/providers/center_providers.dart';
import 'package:itaaleem/features/center/presentation/utils/leave_center_dialog.dart';
import 'package:itaaleem/features/center/presentation/widgets/social_links_bar.dart';
import 'package:itaaleem/features/settings/presentation/providers/theme_mode_provider.dart';
import 'package:flutter/material.dart';
import 'package:itaaleem/core/utils/platform_utils.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:itaaleem/core/theme/app_palette.dart';
import 'package:itaaleem/core/theme/app_radius.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';

String? _gradeNameOf(CenterModel center, int? gradeId) {
  if (gradeId == null) return null;
  for (final grade in center.grades) {
    if (grade.id == gradeId) return grade.name;
  }
  return null;
}

/// "حسابي" tab: profile header (with the joined center/grade), quick
/// links, grouped settings sections, and sign-out.
class AccountTab extends ConsumerWidget {
  const AccountTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final student = ref.watch(authControllerProvider).valueOrNull;
    final membership = ref.watch(centerMembershipProvider).valueOrNull;
    final center = membership == null
        ? null
        : ref.watch(centerByIdProvider(membership.centerId));
    final gradeName = (center != null && membership != null)
        ? _gradeNameOf(center, membership.gradeId)
        : null;
    final version =
        ref.watch(packageInfoProvider).valueOrNull?.version ?? '1.0.0';

    // The header paints under the status bar, so its icons need to be light.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: ListView(
          padding: EdgeInsets.zero,
          children: [
            _Header(
              student: student,
              centerName: center?.name,
              gradeName: gradeName,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenHorizontal,
                AppSpacing.sectionSpacing,
                AppSpacing.screenHorizontal,
                AppSpacing.sectionSpacing,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'روابطك السريعة',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.5,
                    children: [
                      QuickLinkCard(
                        icon: Icons.support_agent_rounded,
                        label: 'الدعم',
                        color: context.palette.success,
                        onTap: () => context.push<void>(supportPath),
                      ),
                      QuickLinkCard(
                        icon: Icons.download_for_offline_rounded,
                        label: 'المحمّلات',
                        color: Theme.of(context).colorScheme.secondary,
                        // A real GoRouter navigation (not Navigator.push) —
                        // `/downloads` is one of the paths the app's
                        // connectivity gate keeps reachable while offline,
                        // which it only recognizes by the router's own
                        // location.
                        onTap: () => context.push(downloadsPath),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  const _SectionLabel('الحساب'),
                  const SizedBox(height: 10),
                  _MenuCard(
                    children: [
                      _MenuTile(
                        icon: Icons.person_outline_rounded,
                        label: 'تعديل البيانات',
                        onTap: () => context.push<void>(editProfilePath),
                      ),
                      _MenuTile(
                        icon: Icons.lock_reset_rounded,
                        label: 'تغيير كلمة المرور',
                        onTap: () => context.push<void>(changePasswordPath),
                      ),
                      _MenuTile(
                        icon: Icons.card_membership_rounded,
                        label: 'اشتراكاتي',
                        onTap: () => context.push<void>(mySubscriptionsPath),
                      ),
                      // An activated student can still redeem a code for
                      // more subjects — except on iOS, where unlocking
                      // content outside In-App Purchase isn't allowed.
                      if (!PlatformUtils.hideSubscriptions)
                        const _MenuTile(
                          icon: Icons.confirmation_number_rounded,
                          label: 'تفعيل كود الاشتراك',
                          onTap: pushActivationScreen,
                        ),
                    ],
                  ),
                  if (center != null && membership != null) ...[
                    const SizedBox(height: AppSpacing.lg),
                    const _SectionLabel('السنتر'),
                    const SizedBox(height: 10),
                    _MenuCard(
                      children: [
                        _MenuTile(
                          icon: Icons.school_rounded,
                          label: 'بيانات السنتر',
                          onTap: () => context.push<void>(contactCenterPath),
                        ),
                        _MenuTile(
                          icon: Icons.groups_rounded,
                          label: 'تغيير الكورس',
                          onTap: () =>
                              context.push<void>('/select-grade/${center.id}'),
                        ),
                        _MenuTile(
                          icon: Icons.logout_rounded,
                          label: 'مغادرة السنتر',
                          destructive: true,
                          onTap: () =>
                              confirmLeaveCenter(context, ref, center.name),
                        ),
                      ],
                    ),
                    if (center.socialLinks.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.base),
                      SocialLinksBar(socialLinks: center.socialLinks),
                    ],
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  const _SectionLabel('التطبيق'),
                  const SizedBox(height: 10),
                  _MenuCard(
                    children: [
                      const _DarkModeTile(),
                      _MenuTile(
                        icon: Icons.info_outline_rounded,
                        label: 'عن التطبيق',
                        onTap: () => context.push<void>(aboutPath),
                      ),
                      const _DeleteAccountTile(),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const _LogoutButton(),
                  const SizedBox(height: AppSpacing.sm),
                  Center(
                    child: Text(
                      'منصة أونلاين v$version',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11,
                        color: context.palette.textTertiary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.student, this.centerName, this.gradeName});

  final Student? student;
  final String? centerName;
  final String? gradeName;

  /// Outer radius of the avatar ring — half of it sits in the gradient.
  static const _avatarRadius = 48.0;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final trimmedName = student?.fullName.trim() ?? '';
    final top = MediaQuery.paddingOf(context).top;
    final headerHeight = math.max(
      MediaQuery.sizeOf(context).height * 0.2,
      top + 96,
    );

    return Column(
      children: [
        Stack(
          children: [
            Column(
              children: [
                GradientWaveHeader(
                  height: headerHeight,
                  child: Padding(
                    padding: EdgeInsets.only(top: top + 14),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Text(
                        'حسابي',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: context.palette.onPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: _avatarRadius),
              ],
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: palette.surface,
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(
                          context,
                        ).colorScheme.shadow.withValues(alpha: 0.2),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    child: _ProfileAvatar(student: student),
                  ),
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenHorizontal,
            AppSpacing.md,
            AppSpacing.screenHorizontal,
            0,
          ),
          child: Column(
            children: [
              Text(
                trimmedName.isNotEmpty ? trimmedName : 'طالب',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (student?.isDemo ?? false) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: palette.accentSurface,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.science_rounded,
                        size: 12,
                        color: palette.textPrimary,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        'حساب تجريبي',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: palette.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (student?.mobile.isNotEmpty ?? false) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  student!.mobile,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
                    color: palette.textSecondary,
                  ),
                ),
              ],
              if (centerName != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: palette.primarySurface,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    gradeName != null
                        ? 'منضم لـ $centerName — $gradeName'
                        : 'منضم لـ $centerName',
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: palette.primary),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontFamily: 'Cairo',
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: context.palette.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1)
              Divider(height: 1, color: context.palette.borderLight),
          ],
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool destructive;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? context.palette.error : context.palette.primary;
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20, color: color),
      ),
      title: Text(
        label,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(color: color),
      ),
      trailing:
          trailing ??
          Icon(Icons.chevron_left_rounded, color: context.palette.textTertiary),
    );
  }
}

class _DarkModeTile extends ConsumerWidget {
  const _DarkModeTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final platformIsDark =
        MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final isDark = themeMode == ThemeMode.system
        ? platformIsDark
        : themeMode == ThemeMode.dark;

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: context.palette.primary.withValues(alpha: 0.08),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.dark_mode_rounded,
          size: 20,
          color: context.palette.primary,
        ),
      ),
      title: const Text(
        'الوضع الليلي',
        style: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: Switch(
        value: isDark,
        activeTrackColor: context.palette.primary,
        onChanged: (value) =>
            ref.read(themeModeProvider.notifier).setDark(value),
      ),
    );
  }
}

/// Profile header's avatar: tapping it picks a new photo straight from
/// gallery/camera and uploads it via `PUT /profile` immediately — unlike
/// [EditProfileScreen], which stages the pick until "حفظ التغييرات".
class _ProfileAvatar extends ConsumerStatefulWidget {
  const _ProfileAvatar({required this.student});

  final Student? student;

  @override
  ConsumerState<_ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends ConsumerState<_ProfileAvatar> {
  bool _uploading = false;

  Future<void> _changePhoto() async {
    final image = await pickProfileImage(context);
    if (image == null) return;

    setState(() => _uploading = true);
    final failure = await ref
        .read(authControllerProvider.notifier)
        .updateProfile(
          fullName: widget.student?.fullName ?? '',
          avatarFilePath: image.path,
        );
    if (!mounted) return;
    setState(() => _uploading = false);

    if (failure != null) {
      AppToast.showError(
        context,
        failure.message.isNotEmpty
            ? failure.message
            : 'تعذر تحديث الصورة، حاول مرة أخرى',
      );
    } else {
      AppToast.showSuccess(context, 'تم تحديث الصورة بنجاح');
    }
  }

  void _viewFullscreen(BuildContext context) {
    final url = widget.student?.avatarUrl;
    if (url == null || url.isEmpty) return;
    context.push<void>(imageViewerPath, extra: url);
  }

  @override
  Widget build(BuildContext context) {
    return StudentAvatar(
      radius: 44,
      avatarUrl: widget.student?.avatarUrl,
      isLoading: _uploading,
      showCameraBadge: true,
      onTap: _uploading ? null : () => _viewFullscreen(context),
      onCameraTap: _uploading ? null : _changePhoto,
    );
  }
}

/// Destructive "حذف الحساب" menu tile — confirms via dialog, then calls
/// `DELETE /account`. On success the auth controller clears the session,
/// which redirects to `/login` automatically (same mechanism as logout).
class _DeleteAccountTile extends ConsumerStatefulWidget {
  const _DeleteAccountTile();

  @override
  ConsumerState<_DeleteAccountTile> createState() => _DeleteAccountTileState();
}

class _DeleteAccountTileState extends ConsumerState<_DeleteAccountTile> {
  bool _isDeleting = false;

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف الحساب'),
        content: const Text(
          'هل أنت متأكد من حذف حسابك؟ لا يمكن التراجع عن هذا الإجراء',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: context.palette.error),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isDeleting = true);
    final failure = await ref
        .read(authControllerProvider.notifier)
        .deleteAccount();
    if (!mounted) return;
    setState(() => _isDeleting = false);

    if (failure != null) {
      AppToast.showError(
        context,
        failure.message.isNotEmpty
            ? failure.message
            : 'تعذر حذف الحساب، حاول مرة أخرى',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return _MenuTile(
      icon: Icons.delete_forever_rounded,
      label: 'حذف الحساب',
      destructive: true,
      onTap: _isDeleting ? null : _confirmDelete,
      trailing: _isDeleting
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: context.palette.error,
              ),
            )
          : null,
    );
  }
}

class _LogoutButton extends ConsumerWidget {
  const _LogoutButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoggingOut = ref.watch(authControllerProvider).isLoading;

    return AppButton.secondary(
      'تسجيل الخروج',
      icon: Icons.logout_rounded,
      color: context.palette.error,
      loading: isLoggingOut,
      onPressed: isLoggingOut
          ? null
          : () => ref.read(authControllerProvider.notifier).logout(),
    );
  }
}
