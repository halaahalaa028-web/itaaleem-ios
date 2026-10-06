import 'package:itaaleem/core/widgets/app_toast.dart';
import 'package:itaaleem/features/center/presentation/widgets/social_icon_button.dart';
import 'package:flutter/material.dart';
import 'package:itaaleem/core/utils/safe_url.dart';
import 'package:url_launcher/url_launcher.dart';

/// A row of [SocialIconButton]s for a [CenterModel.socialLinks] map — one
/// per platform key with a non-null/non-empty URL, tapping opens it via
/// `url_launcher`. Renders nothing if [socialLinks] has no usable entries,
/// so callers can drop it in unconditionally.
class SocialLinksBar extends StatelessWidget {
  const SocialLinksBar({
    super.key,
    required this.socialLinks,
    this.iconSize = 44,
  });

  final Map<String, String?> socialLinks;
  final double iconSize;

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
  Widget build(BuildContext context) {
    final entries = socialLinks.entries
        .where((e) => e.value != null && e.value!.isNotEmpty)
        .toList();
    if (entries.isEmpty) return const SizedBox.shrink();

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 16,
      runSpacing: 12,
      children: [
        for (final entry in entries)
          SocialIconButton(
            platform: entry.key,
            size: iconSize,
            onTap: () => _open(context, entry.value!),
          ),
      ],
    );
  }
}
