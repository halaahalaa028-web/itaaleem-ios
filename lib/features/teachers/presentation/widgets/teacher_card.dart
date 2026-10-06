import 'package:cached_network_image/cached_network_image.dart';
import 'package:itaaleem/features/teachers/domain/entities/teacher.dart';
import 'package:flutter/material.dart';
import 'package:itaaleem/core/theme/app_palette.dart';
import 'package:itaaleem/core/theme/app_radius.dart';

/// One teacher tile in the "مدرسو هذه المادة" grid: a large, uncropped
/// (~3:4) photo filling most of the card, name + specialization
/// underneath. Tapping one navigates to that teacher's lecture list.
class TeacherCard extends StatelessWidget {
  const TeacherCard({super.key, required this.teacher, required this.onTap});

  final Teacher teacher;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: context.palette.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppRadius.lg),
                  ),
                  child: TeacherPhoto(url: teacher.photoUrl),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                child: Column(
                  children: [
                    Text(
                      teacher.name,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (teacher.displaySpecialization.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        teacher.displaySpecialization,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.55),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A teacher's photo, filling its box via [BoxFit.cover] anchored to
/// [Alignment.topCenter] — crops from the bottom rather than the top, so a
/// tall portrait photo always keeps the face in frame instead of cutting it
/// off. Lightly rounded corners are handled by the caller's [ClipRRect].
/// Falls back to a purple-gradient person icon when there's no photo (or it
/// fails to load). Public so [TeacherCard], the teacher lecture list's
/// header banner, and [LessonCard]'s inline teacher badge all share the
/// exact same image/fallback logic.
class TeacherPhoto extends StatelessWidget {
  const TeacherPhoto({
    super.key,
    required this.url,
    this.iconSize = 56,
    this.boxSize = 220,
  });

  final String? url;
  final double iconSize;

  /// Approximate logical-pixel size this photo actually renders at —
  /// [TeacherCard]'s big grid photo, [SectionLessonsScreen]'s 50x50 group
  /// header, and [LessonCard]'s 20x20 inline badge all reuse this same
  /// widget at very different scales, so this drives how large a bitmap
  /// [CachedNetworkImage] actually decodes/caches instead of always
  /// decoding the source photo at full resolution.
  final double boxSize;

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return TeacherPhotoPlaceholder(iconSize: iconSize);
    }
    final cachePx = (boxSize * MediaQuery.devicePixelRatioOf(context)).round();
    return CachedNetworkImage(
      imageUrl: url!,
      fit: BoxFit.cover,
      alignment: Alignment.topCenter,
      memCacheWidth: cachePx,
      memCacheHeight: cachePx,
      placeholder: (context, url) => TeacherPhotoPlaceholder(iconSize: iconSize),
      errorWidget: (context, url, error) =>
          TeacherPhotoPlaceholder(iconSize: iconSize),
    );
  }
}

class TeacherPhotoPlaceholder extends StatelessWidget {
  const TeacherPhotoPlaceholder({super.key, this.iconSize = 56});

  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(gradient: context.palette.brandGradient),
      child: Center(
        child: Icon(
          Icons.person_rounded,
          color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7),
          size: iconSize,
        ),
      ),
    );
  }
}
