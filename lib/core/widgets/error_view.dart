import 'package:flutter/material.dart';
import 'package:itaaleem/core/widgets/app_error_state.dart';

/// Friendly full-space error placeholder with a retry action, used whenever
/// a [FutureProvider] lands in its `AsyncError` state. Renders
/// [AppErrorState] on the theme's own background.
class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    // Its own theme background, so the message stays readable even when the
    // host Scaffold is black (the video/lecture players).
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: AppErrorState(
        message: message,
        retryLabel: retryLabel,
        onRetry: onRetry,
      ),
    );
  }
}
