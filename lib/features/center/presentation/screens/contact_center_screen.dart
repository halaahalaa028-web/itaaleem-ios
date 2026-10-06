import 'package:itaaleem/core/theme/app_colors.dart';
import 'package:itaaleem/app/router/app_router.dart';
import 'package:itaaleem/core/widgets/app_button.dart';
import 'package:itaaleem/core/widgets/app_toast.dart';
import 'package:itaaleem/features/center/presentation/providers/center_providers.dart';
import 'package:itaaleem/features/center/presentation/utils/center_color.dart';
import 'package:itaaleem/features/center/presentation/utils/leave_center_dialog.dart';
import 'package:itaaleem/features/center/presentation/widgets/social_icon_button.dart';
import 'package:flutter/material.dart';
import 'package:itaaleem/core/widgets/app_shimmer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:itaaleem/core/utils/safe_url.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:itaaleem/core/theme/app_palette.dart';
import 'package:itaaleem/core/theme/app_radius.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';

/// Reads the currently-joined center off [centerMembershipProvider] rather
/// than taking a `centerId` — this screen only ever makes sense for the
/// center the student is already in.
class ContactCenterScreen extends ConsumerWidget {
  const ContactCenterScreen({super.key});

  Future<void> _open(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    final launched =
        uri != null &&
        await launchUrlSafely(
          uri,
          mode: uri.scheme == 'tel'
              ? LaunchMode.platformDefault
              : LaunchMode.externalApplication,
        );
    if (!launched && context.mounted) {
      AppToast.showError(context, 'تعذر فتح الرابط');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membership = ref.watch(centerMembershipProvider).valueOrNull;
    final center = membership == null
        ? null
        : ref.watch(centerByIdProvider(membership.centerId));

    if (center == null) {
      return const Scaffold(
        body: SafeArea(child: ShimmerDetail(heroHeight: 120)),
      );
    }

    final color = parseCenterColor(center.primaryColor);

    return Scaffold(
      appBar: AppBar(title: const Text('تواصل مع السنتر')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      center.initial,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: context.palette.onPrimary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        center.name,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (center.description != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          center.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.palette.textSecondary),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton.primary(
              'مراسلة السنتر',
              icon: Icons.chat_bubble_rounded,
              onPressed: () => context.push(chatPath),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Divider(),
            const SizedBox(height: AppSpacing.md),
            if (center.phoneNumbers.isNotEmpty) ...[
              const _SectionTitle(title: 'أرقام التواصل'),
              const SizedBox(height: AppSpacing.sm),
              for (final phone in center.phoneNumbers)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: context.palette.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Icon(
                      Icons.call_rounded,
                      color: context.palette.success,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    phone,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () => _open(context, 'tel:$phone'),
                        icon: Icon(
                          Icons.call_rounded,
                          color: context.palette.success,
                        ),
                      ),
                      IconButton(
                        onPressed: () =>
                            _open(context, 'https://wa.me/2$phone'),
                        icon: const Icon(
                          Icons.chat_rounded,
                          color: AppColors.whatsapp,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: AppSpacing.base),
            ],
            if (center.socialLinks.isNotEmpty) ...[
              const _SectionTitle(title: 'تابعنا'),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: 16,
                runSpacing: 12,
                children: [
                  for (final entry in center.socialLinks.entries)
                    if (entry.value != null)
                      SocialIconButton(
                        platform: entry.key,
                        onTap: () => _open(context, entry.value!),
                        size: 48,
                      ),
                ],
              ),
              const SizedBox(height: AppSpacing.base),
            ],
            if (center.address != null) ...[
              const _SectionTitle(title: 'العنوان'),
              const SizedBox(height: AppSpacing.sm),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: context.palette.primarySurface,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(
                    Icons.location_on_rounded,
                    color: context.palette.primary,
                    size: 20,
                  ),
                ),
                title: Text(
                  center.address!,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
            Center(
              child: TextButton.icon(
                onPressed: () => confirmLeaveCenter(context, ref, center.name),
                style: TextButton.styleFrom(foregroundColor: context.palette.error),
                icon: const Icon(Icons.logout_rounded),
                label: const Text('مغادرة السنتر'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontFamily: 'Cairo',
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
