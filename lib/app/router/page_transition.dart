import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:itaaleem/core/theme/app_page_transitions.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';

/// The page used for every route in [appRouterProvider] — the app-wide
/// fade + direction-aware slide (see [buildAppPageTransition]).
CustomTransitionPage<T> buildPageWithTransition<T>({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: AppMotion.medium,
    reverseTransitionDuration: AppMotion.medium,
    transitionsBuilder: buildAppPageTransition,
  );
}
