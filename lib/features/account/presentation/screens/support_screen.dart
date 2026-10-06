import 'package:itaaleem/core/theme/app_colors.dart';
import 'package:itaaleem/core/widgets/app_toast.dart';
import 'package:itaaleem/features/center/domain/entities/center_model.dart';
import 'package:itaaleem/features/center/presentation/providers/center_providers.dart';
import 'package:itaaleem/features/settings/domain/entities/app_settings.dart';
import 'package:itaaleem/features/settings/presentation/providers/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:itaaleem/core/widgets/app_shimmer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:itaaleem/core/utils/safe_url.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:itaaleem/core/theme/app_palette.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';

const _whatsappGreen = AppColors.whatsapp;

/// `https://wa.me/<digits>` for a WhatsApp number — or a link the API already
/// gave as a URL. A local Egyptian number (`01xxxxxxxxx`) gets the `20`
/// country code; numbers already carrying one (`+20…`, `0020…`) are kept.
String? whatsappUrl(String? raw) {
  final value = raw?.trim();
  if (value == null || value.isEmpty) return null;
  if (value.startsWith('http')) return value;
  var digits = value.replaceAll(RegExp('[^0-9]'), '');
  if (digits.isEmpty) return null;
  if (digits.startsWith('00')) {
    digits = digits.substring(2);
  } else if (digits.startsWith('0')) {
    digits = '20${digits.substring(1)}';
  }
  return 'https://wa.me/$digits';
}

/// "الدعم": the joined center's own contact details (name, phone numbers,
/// WhatsApp, email — from `GET /centers/{id}` / the profile's `center`), each
/// tappable, followed by the platform's general support channels from
/// `GET /public/settings`. There's no ticketing system on the backend, so
/// direct contact is the whole flow.
class SupportScreen extends ConsumerWidget {
  const SupportScreen({super.key});

  Future<void> _open(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    final launched =
        uri != null &&
        await launchUrlSafely(
          uri,
          mode: (uri.scheme == 'tel' || uri.scheme == 'mailto')
              ? LaunchMode.platformDefault
              : LaunchMode.externalApplication,
        );
    if (!launched && context.mounted) {
      AppToast.showError(context, 'تعذر فتح الرابط');
    }
  }

  List<_SupportItem> _centerItems(BuildContext context, CenterModel center) {
    final whatsappRaw = center.socialLinks['whatsapp'];
    final whatsapp = whatsappUrl(whatsappRaw);
    return [
      for (final phone in center.phoneNumbers)
        _SupportItem(
          icon: Icons.call_rounded,
          label: 'اتصل بالسنتر',
          subtitle: phone,
          color: context.palette.success,
          onTap: () => _open(context, 'tel:${phone.replaceAll(' ', '')}'),
        ),
      if (whatsapp != null)
        _SupportItem(
          icon: Icons.chat_rounded,
          label: 'واتساب السنتر',
          subtitle: whatsappRaw!.startsWith('http')
              ? 'محادثة واتساب'
              : whatsappRaw,
          color: _whatsappGreen,
          onTap: () => _open(context, whatsapp),
        ),
      if (center.email != null)
        _SupportItem(
          icon: Icons.email_rounded,
          label: 'راسل السنتر بالبريد الإلكتروني',
          subtitle: center.email!,
          color: context.palette.primary,
          onTap: () => _open(context, 'mailto:${center.email}'),
        ),
    ];
  }

  List<_SupportItem> _platformItems(BuildContext context, AppSettings settings) {
    // No usable number -> no WhatsApp entry at all (rather than opening the
    // bare `https://wa.me/` landing page).
    final waUrl = whatsappUrl(settings.whatsappNumber);
    return [
      if (waUrl != null)
        _SupportItem(
          icon: Icons.chat_rounded,
          label: 'راسلنا على واتساب',
          subtitle: settings.whatsappNumber!,
          color: _whatsappGreen,
          onTap: () => _open(context, waUrl),
        ),
      if (settings.supportPhone != null)
        _SupportItem(
          icon: Icons.call_rounded,
          label: 'اتصل بنا',
          subtitle: settings.supportPhone!,
          color: context.palette.success,
          onTap: () => _open(context, 'tel:${settings.supportPhone}'),
        ),
      if (settings.supportEmail != null)
        _SupportItem(
          icon: Icons.email_rounded,
          label: 'راسلنا بالبريد الإلكتروني',
          subtitle: settings.supportEmail!,
          color: context.palette.primary,
          onTap: () => _open(context, 'mailto:${settings.supportEmail}'),
        ),
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(appSettingsProvider);
    final center = ref.watch(joinedCenterProvider);
    final theme = Theme.of(context);

    final settings = settingsAsync.valueOrNull;
    final centerItems = center == null
        ? const <_SupportItem>[]
        : _centerItems(context, center);
    final platformItems = settings == null
        ? const <_SupportItem>[]
        : _platformItems(context, settings);
    final centerWhatsapp =
        whatsappUrl(center?.socialLinks['whatsapp']) ??
        whatsappUrl(center?.phoneNumbers.firstOrNull) ??
        whatsappUrl(settings?.whatsappNumber);

    final settingsPending = settingsAsync.isLoading && center == null;
    final nothingToShow = centerItems.isEmpty && platformItems.isEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('الدعم')),
      body: SafeArea(
        child: settingsPending
            ? const ShimmerList(count: 4, thumbnailSize: 44)
            : ListView(
                padding: const EdgeInsetsDirectional.all(AppSpacing.screenHorizontal),
                children: [
                  Text(
                    'محتاج مساعدة؟',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'تقدر تتواصل مع فريق الدعم من خلال أي من الطرق دي',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  if (center != null) ...[
                    Text(
                      center.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (centerWhatsapp != null) ...[
                      FilledButton.icon(
                        onPressed: () => _open(context, centerWhatsapp),
                        style: FilledButton.styleFrom(
                          backgroundColor: _whatsappGreen,
                          foregroundColor: Theme.of(context).colorScheme.onPrimary,
                          minimumSize: const Size.fromHeight(48),
                        ),
                        icon: const Icon(Icons.chat_rounded),
                        label: const Text('محادثة واتساب'),
                      ),
                      const SizedBox(height: 14),
                    ],
                    for (final item in centerItems) ...[
                      item,
                      const SizedBox(height: 14),
                    ],
                    if (centerItems.isEmpty)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(bottom: 14),
                        child: Text(
                          'لا تتوفر بيانات تواصل للسنتر حالياً',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.palette.textSecondary),
                        ),
                      ),
                    if (platformItems.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        'دعم المنصة',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                  ],
                  for (final item in platformItems) ...[
                    item,
                    const SizedBox(height: 14),
                  ],
                  if (nothingToShow && center == null)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(top: 12),
                      child: Text(
                        settingsAsync.hasError
                            ? 'تعذر تحميل بيانات الدعم'
                            : 'لا تتوفر بيانات تواصل حالياً',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.palette.textSecondary),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _SupportItem extends StatelessWidget {
  const _SupportItem({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_left_rounded,
                color: colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
