import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:itaaleem/core/theme/app_palette.dart';
import 'package:itaaleem/core/widgets/app_card.dart';
import 'package:itaaleem/features/center/data/models/center_review.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';

/// Read-only row of gold stars for [rating] (supports halves for averages).
class StarRow extends StatelessWidget {
  const StarRow({super.key, required this.rating, this.size = 16});

  final double rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            rating >= i
                ? Icons.star_rounded
                : rating >= i - 0.5
                ? Icons.star_half_rounded
                : Icons.star_outline_rounded,
            size: size,
            color: rating >= i - 0.5
                ? context.palette.gold
                : context.palette.textTertiary,
          ),
      ],
    );
  }
}

/// Tappable 1–5 star selector.
class StarPicker extends StatelessWidget {
  const StarPicker({super.key, required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 1; i <= 5; i++)
          IconButton(
            onPressed: () => onChanged(i),
            iconSize: 42,
            padding: const EdgeInsets.all(AppSpacing.xs),
            constraints: const BoxConstraints(),
            icon: Icon(
              i <= value ? Icons.star_rounded : Icons.star_outline_rounded,
              color: i <= value
                  ? context.palette.gold
                  : context.palette.textTertiary,
            ),
          ),
      ],
    );
  }
}

/// One review as a card: avatar + name + date, stars, comment.
class ReviewCard extends StatelessWidget {
  const ReviewCard({super.key, required this.review, this.trailing});

  final CenterReview review;

  /// e.g. an edit/delete menu on the student's own review.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final date = review.createdAt == null
        ? null
        : DateFormat('yyyy/MM/dd').format(review.createdAt!.toLocal());
    final avatar = review.studentAvatar;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: palette.primarySurface,
                foregroundImage: avatar == null
                    ? null
                    : CachedNetworkImageProvider(avatar),
                child: Icon(
                  Icons.person_rounded,
                  size: 22,
                  color: palette.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.isOwner
                          ? '${review.studentName} (تقييمك)'
                          : review.studentName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (date != null)
                      Text(
                        date,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11,
                          color: palette.textTertiary,
                        ),
                      ),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 10),
          StarRow(rating: review.rating.toDouble()),
          if (review.comment.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              review.comment,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                height: 1.6,
                color: palette.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
