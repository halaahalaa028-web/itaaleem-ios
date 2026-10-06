import 'package:flutter/material.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';

/// Shown when a player can't play its video — a clear Arabic message plus a
/// retry button. There is deliberately no second player to fall back to.
class PlayerErrorView extends StatelessWidget {
  const PlayerErrorView({
    super.key,
    required this.onRetry,
    this.message = 'تعذر تشغيل الفيديو — تأكد من اتصالك بالإنترنت',
  });

  final VoidCallback onRetry;
  final String message;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ColoredBox(
        color: Colors.black,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Cairo',
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('إعادة المحاولة'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
