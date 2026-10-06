import 'package:flutter/material.dart';
import 'package:itaaleem/core/theme/app_palette.dart';

/// Wraps [child] with a moving light-sweep shimmer effect, used as a loading
/// placeholder instead of a bare spinner. Hand-rolled (AnimationController +
/// ShaderMask) rather than pulling in the `shimmer` package, since the app
/// avoids extra dependencies where a small widget does the job.
class ShimmerLoading extends StatefulWidget {
  const ShimmerLoading({super.key, required this.child});

  final Widget child;

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = context.palette.shimmerBase;
    final highlightColor = context.palette.shimmerHighlight;

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (bounds) {
              final dx = _controller.value * 2 - 1;
              return LinearGradient(
                begin: Alignment(-1 - dx, 0),
                end: Alignment(1 - dx, 0),
                colors: [baseColor, highlightColor, baseColor],
                stops: const [0.35, 0.5, 0.65],
              ).createShader(bounds);
            },
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}

/// A solid rounded-rect placeholder block, meant to be wrapped by
/// [ShimmerLoading] (directly or via an ancestor) to skeleton-load content.
class ShimmerBox extends StatelessWidget {
  const ShimmerBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 12,
  });

  final double? width;
  final double? height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}
