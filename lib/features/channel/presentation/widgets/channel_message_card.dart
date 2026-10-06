import 'package:cached_network_image/cached_network_image.dart';
import 'package:itaaleem/core/widgets/linkified_text.dart';
import 'package:itaaleem/features/channel/domain/entities/channel_message.dart';
import 'package:itaaleem/app/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';
import 'package:go_router/go_router.dart';
import 'package:itaaleem/core/theme/app_palette.dart';

const _arabicMonths = [
  'يناير',
  'فبراير',
  'مارس',
  'أبريل',
  'مايو',
  'يونيو',
  'يوليو',
  'أغسطس',
  'سبتمبر',
  'أكتوبر',
  'نوفمبر',
  'ديسمبر',
];

/// Hand-rolled Arabic date/time label — avoids depending on `intl`'s
/// locale-data bootstrap (`initializeDateFormatting`), which nothing else in
/// this app has wired up yet.
String _formatArabicDateTime(DateTime dateTime) {
  final local = dateTime.toLocal();
  final hour24 = local.hour;
  final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
  final period = hour24 < 12 ? 'ص' : 'م';
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.day} ${_arabicMonths[local.month - 1]} ${local.year} - $hour12:$minute $period';
}

/// One "القناة" message: an optional image, optional text, and a date
/// stamp. Pinned messages get a highlighted purple-tinted background and a
/// pin badge. Tapping the image opens [ChannelImageViewerScreen]; there is
/// no long-press/share affordance anywhere on the thumbnail either, so
/// there's nothing here for the user to save it with directly.
class ChannelMessageCard extends StatelessWidget {
  const ChannelMessageCard({super.key, required this.message});

  final ChannelMessage message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final pinned = message.isPinned;

    return Container(
      decoration: BoxDecoration(
        color: pinned
            ? context.palette.primary.withValues(alpha: 0.08)
            : colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: pinned
              ? context.palette.primary.withValues(alpha: 0.35)
              : colorScheme.outline.withValues(alpha: 0.1),
          width: pinned ? 1.2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (pinned)
            Container(
              width: double.infinity,
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: 14,
                vertical: 6,
              ),
              color: context.palette.primary.withValues(alpha: 0.14),
              child: Row(
                children: [
                  Icon(
                    Icons.push_pin_rounded,
                    size: 14,
                    color: context.palette.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'رسالة مثبّتة',
                    style: textTheme.labelSmall?.copyWith(
                      color: context.palette.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          if (message.imageUrl != null)
            GestureDetector(
              onTap: () =>
                  context.push<void>(channelImagePath, extra: message.imageUrl),
              child: AspectRatio(
                aspectRatio: 16 / 10,
                child: CachedNetworkImage(
                  imageUrl: message.imageUrl!,
                  fit: BoxFit.cover,
                  memCacheWidth: 800,
                  placeholder: (context, url) =>
                      Container(color: colorScheme.surfaceContainerHighest),
                  errorWidget: (context, url, error) => Container(
                    color: colorScheme.surfaceContainerHighest,
                    child: Icon(
                      Icons.broken_image_rounded,
                      color: colorScheme.onSurface.withValues(alpha: 0.35),
                    ),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsetsDirectional.all(AppSpacing.cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (message.text != null && message.text!.isNotEmpty)
                  LinkifiedText(
                    message.text!,
                    style: textTheme.bodyMedium?.copyWith(height: 1.5),
                    linkColor: context.palette.primary,
                  ),
                if (message.text != null && message.text!.isNotEmpty)
                  const SizedBox(height: 10),
                Text(
                  _formatArabicDateTime(message.createdAt),
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
