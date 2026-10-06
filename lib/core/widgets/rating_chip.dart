import 'package:flutter/material.dart';
import 'package:itaaleem/core/theme/app_palette.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';

/// Compact inline rating: a gold star, the average in w700, and the number
/// of ratings in parentheses in the secondary text color.
class RatingChip extends StatelessWidget {
  const RatingChip({
    super.key,
    required this.rating,
    this.count,
    this.size = 18,
  });

  final double rating;

  /// Omitted when null — a card that only has an average shows just the star
  /// and the number.
  final int? count;

  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star_rounded, color: context.palette.gold, size: size),
        const SizedBox(width: 2),
        Text(
          rating.toStringAsFixed(1),
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
        if (count != null) ...[
          const SizedBox(width: AppSpacing.xs),
          Text(
            '($count)',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.palette.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}
