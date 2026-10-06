import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:itaaleem/core/theme/app_radius.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';

/// Faint, slowly-drifting overlay showing the viewing student's name and
/// mobile number on top of protected content (lecture video or PDF) — a
/// deterrent against screen recording/photos (a still frame or short clip
/// still identifies who watched it), not a way to prevent it outright.
class IdentityWatermark extends StatefulWidget {
  const IdentityWatermark({
    super.key,
    required this.studentName,
    required this.studentMobile,
  });

  final String studentName;
  final String studentMobile;

  @override
  State<IdentityWatermark> createState() => _IdentityWatermarkState();
}

class _IdentityWatermarkState extends State<IdentityWatermark> {
  final _random = Random();
  Alignment _alignment = Alignment.topLeft;
  Timer? _timer;

  // The play/pause button sits at the video's center, so positions are
  // drawn from a ring around it (never the center itself) to avoid
  // covering the tap target.
  static const _corners = [
    Alignment(-0.85, -0.8),
    Alignment(0.85, -0.8),
    Alignment(-0.85, 0.8),
    Alignment(0.85, 0.8),
    Alignment(-0.85, 0),
    Alignment(0.85, 0),
  ];

  @override
  void initState() {
    super.initState();
    _alignment = _randomAlignment();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted) return;
      setState(() => _alignment = _randomAlignment());
    });
  }

  Alignment _randomAlignment() {
    final options = _corners.where((a) => a != _alignment).toList();
    return options[_random.nextInt(options.length)];
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedAlign(
        alignment: _alignment,
        duration: const Duration(seconds: 3),
        curve: Curves.easeInOut,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    widget.studentName,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.35),
                    ),
                  ),
                  Text(
                    widget.studentMobile,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.35),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
