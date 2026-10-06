import 'package:itaaleem/app/theme/app_theme.dart';
import 'package:itaaleem/core/widgets/app_toast.dart';
import 'package:itaaleem/core/widgets/fade_slide_in.dart';
import 'package:itaaleem/features/activation/presentation/screens/activation_screen.dart';
import 'package:itaaleem/features/home/presentation/widgets/communication_shimmer.dart';
import 'package:itaaleem/features/settings/domain/entities/app_settings.dart';
import 'package:itaaleem/features/settings/presentation/providers/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:itaaleem/core/utils/platform_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:itaaleem/core/utils/safe_url.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:itaaleem/core/theme/app_palette.dart';
import 'package:itaaleem/core/theme/app_radius.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';
/// "التواصل" tab (formerly "تفعيل كود"): big, platform-colored contact
/// buttons from `GET /public/settings`, hiding whichever are null. Code
/// activation moves down to a small button at the bottom, opened via
/// [pushActivationScreen] instead of being its own main tab.
class CommunicationTab extends ConsumerWidget {
  const CommunicationTab({super.key});

  /// "تفعيل كود" unlocks content — hidden on iOS (outside In-App Purchase).
  static VoidCallback? get _activateTap =>
      PlatformUtils.hideSubscriptions ? null : pushActivationScreen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(appSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('التواصل'),
      ),
      body: SafeArea(
        child: settingsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsetsDirectional.all(AppSpacing.screenHorizontal),
            child: CommunicationShimmer(),
          ),
          error: (_, _) => _CommunicationBody(
            items: const [],
            onActivateTap: _activateTap,
          ),
          data: (settings) => _CommunicationBody(
            items: _itemsOf(context, settings),
            onActivateTap: _activateTap,
          ),
        ),
      ),
    );
  }

  List<_ContactItem> _itemsOf(BuildContext context, AppSettings settings) {
    return [
      if (settings.whatsappNumber != null)
        _ContactItem(
          icon: Icons.chat_rounded,
          label: 'واتساب',
          color: AppColors.whatsapp,
          url:
              'https://wa.me/${settings.whatsappNumber!.replaceAll(RegExp('[^0-9]'), '')}',
        ),
      if (settings.whatsappGroup != null)
        _ContactItem(
          icon: Icons.groups_rounded,
          label: 'جروب واتساب',
          color: AppColors.whatsapp,
          url: settings.whatsappGroup!,
        ),
      if (settings.facebookUrl != null)
        _ContactItem(
          icon: Icons.facebook_rounded,
          label: 'فيسبوك',
          color: AppColors.facebook,
          url: settings.facebookUrl!,
        ),
      if (settings.youtubeUrl != null)
        _ContactItem(
          icon: Icons.smart_display_rounded,
          label: 'يوتيوب',
          color: AppColors.youtube,
          url: settings.youtubeUrl!,
        ),
      if (settings.telegramUrl != null)
        _ContactItem(
          icon: Icons.send_rounded,
          label: 'تليجرام',
          color: AppColors.telegram,
          url: settings.telegramUrl!,
        ),
      if (settings.websiteUrl != null)
        _ContactItem(
          icon: Icons.language_rounded,
          label: 'الموقع',
          color: context.palette.primary,
          url: settings.websiteUrl!,
        ),
      if (settings.supportPhone != null)
        _ContactItem(
          icon: Icons.call_rounded,
          label: 'اتصال',
          color: context.palette.success,
          url: 'tel:${settings.supportPhone}',
        ),
      if (settings.supportEmail != null)
        _ContactItem(
          icon: Icons.email_rounded,
          label: 'البريد الإلكتروني',
          color: context.palette.warning,
          url: 'mailto:${settings.supportEmail}',
        ),
    ];
  }
}

class _CommunicationBody extends StatelessWidget {
  const _CommunicationBody({required this.items, required this.onActivateTap});

  final List<_ContactItem> items;
  final VoidCallback? onActivateTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsetsDirectional.all(AppSpacing.screenHorizontal),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 28,
                    horizontal: 20,
                  ),
                  decoration: BoxDecoration(
                    gradient: context.palette.brandGradient,
                    borderRadius: BorderRadius.circular(AppRadius.xxl),
                  ),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: context.palette.onPrimary.withValues(
                          alpha: 0.15,
                        ),
                        child: Icon(
                          Icons.headset_mic_rounded,
                          color: context.palette.onPrimary,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'محتاج مساعدة؟',
                        textAlign: TextAlign.center,
                        style: textTheme.titleLarge?.copyWith(
                          color: context.palette.onPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'تواصل معنا من خلال أي من الوسائل دي',
                        textAlign: TextAlign.center,
                        style: textTheme.bodyMedium?.copyWith(
                          color: context.palette.onPrimary.withValues(
                            alpha: 0.85,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                if (items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                    child: Center(
                      child: Text(
                        'تعذر تحميل وسائل التواصل، حاول مرة أخرى',
                        textAlign: TextAlign.center,
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  )
                else
                  GridView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: items.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 14,
                          crossAxisSpacing: 14,
                          childAspectRatio: 1.5,
                        ),
                    itemBuilder: (context, index) => FadeSlideIn(
                      delay: Duration(milliseconds: 40 * index.clamp(0, 8)),
                      child: _ContactCard(item: items[index]),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (onActivateTap != null)
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 20),
          child: OutlinedButton.icon(
            onPressed: onActivateTap,
            icon: const Icon(Icons.qr_code_rounded, size: 18),
            label: const Text('تفعيل كود'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ),
      ],
    );
  }
}

class _ContactItem {
  const _ContactItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.url,
  });

  final IconData icon;
  final String label;
  final Color color;
  final String url;
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({required this.item});

  final _ContactItem item;

  Future<void> _open(BuildContext context) async {
    final uri = Uri.tryParse(item.url);
    if (uri == null) return;
    final mode = (uri.scheme == 'tel' || uri.scheme == 'mailto')
        ? LaunchMode.platformDefault
        : LaunchMode.externalApplication;
    final launched = await launchUrlSafely(uri, mode: mode);
    if (!launched && context.mounted) {
      AppToast.showError(context, 'تعذر فتح الرابط');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: item.color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(AppRadius.xl),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _open(context),
        child: Padding(
          padding: const EdgeInsetsDirectional.all(AppSpacing.cardPadding),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: item.color,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  item.icon,
                  color: context.palette.onPrimary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: item.color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
