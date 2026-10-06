import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:itaaleem/core/theme/app_palette.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';

/// A slim gradient bar with a back button and a centered title — shared by
/// the subject ("مادة") screen and the per-teacher lecture list.
class GradientBackBar extends StatelessWidget {
  const GradientBackBar({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(gradient: context.palette.brandGradient),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            IconButton(
              onPressed: () => context.pop(),
              icon: const BackButtonIcon(),
              color: context.palette.onPrimary,
            ),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: context.palette.onPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xxxl),
          ],
        ),
      ),
    );
  }
}
