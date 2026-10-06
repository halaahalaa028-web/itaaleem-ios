import 'package:flutter/material.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';
import 'package:itaaleem/core/widgets/app_empty_state.dart';

/// Section/list placeholder for legitimately empty content (as opposed to
/// [ErrorView], which is for a failed load). Renders [AppEmptyState].
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.message,
    this.icon,
    this.verticalPadding = AppSpacing.xxl,
  });

  final String message;

  /// Optional icon above the text, for a full-screen empty list.
  final IconData? icon;

  final double verticalPadding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: verticalPadding),
      child: AppEmptyState(
        title: message,
        icon: icon,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
      ),
    );
  }
}
