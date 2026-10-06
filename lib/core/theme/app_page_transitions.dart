import 'package:flutter/material.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';

/// The app's single page transition: the new page fades in while sliding
/// from the reading-start side (left in Arabic/RTL, right in LTR), and the
/// page underneath drifts a little the other way. 300ms, easeOutCubic.
///
/// Shared by every GoRouter page (`buildPageWithTransition`) and, through
/// [AppPageTransitionsBuilder], by plain `Navigator.push` routes.
Widget buildAppPageTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  // Honor the OS "remove animations" accessibility setting.
  if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return child;

  // RTL: "forward" moves left → right, so the new page enters from the left.
  final dir = Directionality.of(context) == TextDirection.rtl ? -1.0 : 1.0;
  final incoming = CurvedAnimation(
    parent: animation,
    curve: AppMotion.standard,
    reverseCurve: Curves.easeInCubic,
  );
  final outgoing = CurvedAnimation(
    parent: secondaryAnimation,
    curve: AppMotion.standard,
    reverseCurve: Curves.easeInCubic,
  );

  return SlideTransition(
    position: Tween<Offset>(
      begin: Offset.zero,
      end: Offset(-0.06 * dir, 0),
    ).animate(outgoing),
    child: FadeTransition(
      opacity: incoming,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: Offset(0.12 * dir, 0),
          end: Offset.zero,
        ).animate(incoming),
        child: child,
      ),
    ),
  );
}

/// [PageTransitionsTheme] hook for routes not built by GoRouter.
class AppPageTransitionsBuilder extends PageTransitionsBuilder {
  const AppPageTransitionsBuilder();

  @override
  Duration get transitionDuration => AppMotion.medium;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => buildAppPageTransition(context, animation, secondaryAnimation, child);
}
