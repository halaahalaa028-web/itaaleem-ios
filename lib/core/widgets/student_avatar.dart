import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:itaaleem/core/theme/app_palette.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';

/// Circular student avatar shared by the account tab and the edit-profile
/// screen: the uploaded photo when there is one, a freshly-picked local
/// file while it's mid-upload, or an elegant purple-gradient person icon
/// as the default placeholder — never bare initials.
class StudentAvatar extends StatelessWidget {
  const StudentAvatar({
    super.key,
    required this.radius,
    this.avatarUrl,
    this.localFile,
    this.onTap,
    this.onCameraTap,
    this.isLoading = false,
    this.showCameraBadge = false,
  });

  final double radius;
  final String? avatarUrl;
  final File? localFile;

  /// Tapping the photo itself — e.g. to view it full screen.
  final VoidCallback? onTap;

  /// Tapping the small camera badge — e.g. to change the photo. Falls back
  /// to [onTap] when not provided, so callers that only want one action
  /// (both taps doing the same thing) don't need to pass both.
  final VoidCallback? onCameraTap;
  final bool isLoading;

  /// Draws the small purple camera icon at the bottom corner.
  final bool showCameraBadge;

  @override
  Widget build(BuildContext context) {
    final diameter = radius * 2;
    final content = Stack(
      clipBehavior: Clip.none,
      children: [
        ClipOval(
          child: SizedBox(width: diameter, height: diameter, child: _image()),
        ),
        if (isLoading)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.scrim.withValues(alpha: 0.35),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                ),
              ),
            ),
          ),
        if (showCameraBadge && !isLoading)
          PositionedDirectional(
            bottom: 0,
            end: 0,
            child: Material(
              color: context.palette.primary,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onCameraTap ?? onTap,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Icon(
                    Icons.edit_rounded,
                    color: context.palette.onPrimary,
                    size: 18,
                  ),
                ),
              ),
            ),
          ),
      ],
    );

    if (onTap == null) return content;
    return GestureDetector(onTap: onTap, child: content);
  }

  Widget _image() {
    if (localFile != null) {
      return Image.file(localFile!, fit: BoxFit.cover);
    }
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      final cachePx = (radius * 2 * 3).round();
      return CachedNetworkImage(
        imageUrl: avatarUrl!,
        fit: BoxFit.cover,
        memCacheWidth: cachePx,
        memCacheHeight: cachePx,
        placeholder: (context, url) => _GradientPersonIcon(size: radius),
        errorWidget: (context, url, error) => _GradientPersonIcon(size: radius),
      );
    }
    return _GradientPersonIcon(size: radius);
  }
}

class _GradientPersonIcon extends StatelessWidget {
  const _GradientPersonIcon({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(gradient: context.palette.brandGradient),
      child: Center(
        child: Icon(
          Icons.person_rounded,
          color: context.palette.onPrimary,
          size: size * 0.75,
        ),
      ),
    );
  }
}
