import 'package:itaaleem/app/theme/app_theme.dart';
import 'package:flutter/material.dart';

import 'package:itaaleem/core/theme/app_palette.dart';
class _SocialPlatform {
  const _SocialPlatform({
    required this.icon,
    required this.color,
    this.gradientColors,
  });

  final IconData icon;
  final Color color;
  final List<Color>? gradientColors;
}

const _socialPlatforms = <String, _SocialPlatform>{
  'facebook': _SocialPlatform(
    icon: Icons.facebook_rounded,
    color: AppColors.facebook,
  ),
  'whatsapp': _SocialPlatform(
    icon: Icons.chat_rounded,
    color: AppColors.whatsapp,
  ),
  'youtube': _SocialPlatform(
    icon: Icons.smart_display_rounded,
    color: AppColors.youtube,
  ),
  'telegram': _SocialPlatform(
    icon: Icons.send_rounded,
    color: AppColors.telegram,
  ),
  'instagram': _SocialPlatform(
    icon: Icons.camera_alt_rounded,
    color: AppColors.instagram,
    gradientColors: AppColors.instagramGradient,
  ),
  'tiktok': _SocialPlatform(
    icon: Icons.music_note_rounded,
    color: AppColors.tiktok,
  ),
  'website': _SocialPlatform(
    icon: Icons.language_rounded,
    color: AppColors.defaultPrimary,
  ),
  'twitter': _SocialPlatform(
    icon: Icons.alternate_email_rounded,
    color: AppColors.twitter,
  ),
};

/// A colored circular button for one of a center's [CenterModel.socialLinks]
/// platforms (facebook/whatsapp/youtube/telegram/instagram/tiktok/twitter/
/// website). Renders nothing for an unrecognized key, so callers can iterate
/// the map unfiltered.
class SocialIconButton extends StatelessWidget {
  const SocialIconButton({
    super.key,
    required this.platform,
    required this.onTap,
    this.size = 44,
  });

  final String platform;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    final config = _socialPlatforms[platform];
    if (config == null) return const SizedBox.shrink();

    final gradient = config.gradientColors;
    // The website button follows the center's own brand color.
    final color = platform == 'website'
        ? context.palette.primary
        : config.color;
    final iconSize = size * 0.45;

    return Material(
      color: gradient == null
          ? color.withValues(alpha: 0.12)
          : Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        width: size,
        height: size,
        decoration: gradient != null
            ? BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: gradient),
              )
            : null,
        child: InkWell(
          onTap: onTap,
          child: Center(
            child: Icon(
              config.icon,
              color: gradient != null ? Colors.white : color,
              size: iconSize,
            ),
          ),
        ),
      ),
    );
  }
}
