import 'package:flutter/material.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';

/// Fade + small upward-slide entrance for a card/list item.
///
/// Use [FadeSlideIn.staggered] inside list/grid builders so the first items
/// cascade in one after another on the list's initial load. Items further
/// down, and items rebuilt later while scrolling (lists recycle off-screen
/// children), appear immediately instead of re-animating. Skipped entirely
/// when the OS "remove animations" setting is on.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = 0.06,
  }) : _staggerIndex = null;

  /// Entrance for the [index]-th item of a list.
  FadeSlideIn.staggered({
    super.key,
    required int index,
    required this.child,
    this.offset = 0.06,
  }) : delay = AppMotion.stagger * index.clamp(0, maxStaggeredItems),
       _staggerIndex = index;

  /// Items at or past this index never animate.
  static const maxStaggeredItems = 8;

  final Widget child;
  final Duration delay;

  /// Starting vertical offset, as a fraction of the child's height.
  final double offset;

  final int? _staggerIndex;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.medium,
  );
  late final Animation<double> _curved = CurvedAnimation(
    parent: _controller,
    curve: AppMotion.standard,
  );
  bool _decided = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_decided) return;
    _decided = true;
    if (_shouldAnimate()) {
      if (widget.delay == Duration.zero) {
        _controller.forward();
      } else {
        Future.delayed(widget.delay, () {
          if (mounted) _controller.forward();
        });
      }
    } else {
      _controller.value = 1;
    }
  }

  bool _shouldAnimate() {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return false;
    final index = widget._staggerIndex;
    if (index == null) return true;
    if (index >= FadeSlideIn.maxStaggeredItems) return false;
    // Only on the list's first appearance: once the user has scrolled,
    // an item being (re)built is just scrolling into view.
    final position = Scrollable.maybeOf(context)?.position;
    return position == null || !position.hasPixels || position.pixels <= 0;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The tree shape never changes (that would remount the child). At rest,
    // opacity 1 and a zero offset paint the child directly, with no extra
    // layer; list items already get a RepaintBoundary from their ListView.
    return FadeTransition(
      opacity: _curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: Offset(0, widget.offset),
          end: Offset.zero,
        ).animate(_curved),
        child: widget.child,
      ),
    );
  }
}
