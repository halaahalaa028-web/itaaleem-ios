import 'package:flutter/material.dart';
import 'package:itaaleem/core/theme/app_palette.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';

/// Shown instead of the courses grid when the student has no active
/// enrollments yet — points them at code activation.
class EmptyCoursesView extends StatelessWidget {
  const EmptyCoursesView({super.key, required this.onActivatePressed});

  final VoidCallback onActivatePressed;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    context.palette.primary.withValues(alpha: 0.12),
                    context.palette.primary.withValues(alpha: 0.04),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.school_rounded,
                size: 44,
                color: context.palette.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'لم تشترك في أي كورس بعد',
              textAlign: TextAlign.center,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'فعّل كود الكورس الخاص بك للبدء في رحلتك التعليمية',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton.icon(
              onPressed: onActivatePressed,
              icon: const Icon(Icons.qr_code_rounded),
              label: const Text('فعّل كود الآن'),
              style: FilledButton.styleFrom(minimumSize: const Size(220, 52)),
            ),
          ],
        ),
      ),
    );
  }
}
