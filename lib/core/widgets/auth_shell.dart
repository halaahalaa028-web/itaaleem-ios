import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:itaaleem/core/theme/app_palette.dart';
import 'package:itaaleem/core/theme/app_radius.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';

/// Curved bottom edge for the auth screens' gradient header.
class AuthWaveClipper extends CustomClipper<Path> {
  const AuthWaveClipper();

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    return Path()
      ..lineTo(0, h - 36)
      ..quadraticBezierTo(w * 0.25, h, w * 0.5, h - 20)
      ..quadraticBezierTo(w * 0.75, h - 40, w, h - 14)
      ..lineTo(w, 0)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// Shared frame for login / register / forgot-password: a gradient header with
/// a wave edge (icon badge, title, subtitle) and a rounded sheet that overlaps
/// it and holds the form.
///
/// Entrance animation: header fades in, then each of [fields] slides up and
/// fades in 100ms after the previous one, then [action] scales in with
/// [footer]. Wrap the shell in a `Form` if the fields need one.
class AuthShell extends StatefulWidget {
  const AuthShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.fields,
    required this.action,
    this.footer,
    this.onBack,
    this.headerFactor = 0.35,
    this.badgeSize = 90,
  });

  final String title;
  final String subtitle;

  /// Staggered one by one. Keep the count constant for the screen's lifetime.
  final List<Widget> fields;
  final Widget action;
  final Widget? footer;

  /// Shows a transparent app bar with a white back button when set.
  final VoidCallback? onBack;

  /// Header height as a fraction of the screen — raised automatically if the
  /// content would not fit.
  final double headerFactor;

  /// Diameter of the white circle holding the app icon.
  final double badgeSize;

  @override
  State<AuthShell> createState() => _AuthShellState();
}

class _AuthShellState extends State<AuthShell>
    with SingleTickerProviderStateMixin {
  static const _headerMs = 300;
  static const _startMs = 150;
  static const _stepMs = 100;
  static const _itemMs = 400;
  static const _overlap = 28.0;

  late final AnimationController _controller;
  bool _started = false;

  int get _totalMs => _startMs + _stepMs * (widget.fields.length + 1) + _itemMs;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: _totalMs),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Animation<double> _interval(
    int startMs,
    int durationMs, [
    Curve curve = Curves.easeOut,
  ]) {
    final begin = startMs / _totalMs;
    final end = math.min(1.0, (startMs + durationMs) / _totalMs);
    return CurveTween(
      curve: Interval(begin, end, curve: curve),
    ).animate(_controller);
  }

  Widget _slideFade(int index, Widget child) {
    final start = _startMs + _stepMs * index;
    return FadeTransition(
      opacity: _interval(start, _itemMs),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.25),
          end: Offset.zero,
        ).animate(_interval(start, _itemMs, Curves.easeOutCubic)),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isDark = palette.isDark;
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final hasBack = widget.onBack != null;

    final topInset = padding.top + (hasBack ? kToolbarHeight : 16);
    // Cairo's 28px title renders ~53px tall and the subtitle ~28px (more
    // with large system text) — estimate generously; the header's FittedBox
    // scales down whatever still doesn't fit instead of overflowing.
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final contentHeight =
        widget.badgeSize + 12 + (54 + 30) * math.max(1.0, textScale) + 4;
    final headerHeight = math.max(
      size.height * widget.headerFactor,
      topInset + contentHeight + 40,
    );
    final sheetMinHeight = size.height - (headerHeight - _overlap);

    final actionStart = _startMs + _stepMs * widget.fields.length;
    final actionScale = Tween<double>(
      begin: 0.8,
      end: 1,
    ).animate(_interval(actionStart, _itemMs, Curves.easeOutBack));

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: hasBack
            ? AppBar(
                backgroundColor: Colors.transparent,
                foregroundColor: context.palette.onPrimary,
                systemOverlayStyle: SystemUiOverlayStyle.light,
                leading: IconButton(
                  icon: const BackButtonIcon(),
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  onPressed: widget.onBack,
                ),
              )
            : null,
        body: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: headerHeight,
                child: FadeTransition(
                  opacity: _interval(0, _headerMs),
                  child: _Header(
                    title: widget.title,
                    subtitle: widget.subtitle,
                    badgeSize: widget.badgeSize,
                    topInset: topInset,
                    isDark: isDark,
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(top: headerHeight - _overlap),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: sheetMinHeight,
                    minWidth: double.infinity,
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(AppRadius.xxl),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(
                            context,
                          ).colorScheme.shadow.withValues(alpha: 0.12),
                          blurRadius: 24,
                          offset: const Offset(0, -6),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: EdgeInsetsDirectional.fromSTEB(
                        24,
                        32,
                        24,
                        24 + padding.bottom,
                      ),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (var i = 0; i < widget.fields.length; i++)
                                _slideFade(
                                  i,
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: widget.fields[i],
                                  ),
                                ),
                              const SizedBox(height: AppSpacing.sm),
                              FadeTransition(
                                opacity: _interval(actionStart, _itemMs),
                                child: ScaleTransition(
                                  scale: actionScale,
                                  child: widget.action,
                                ),
                              ),
                              if (widget.footer != null) ...[
                                const SizedBox(height: AppSpacing.xl),
                                FadeTransition(
                                  opacity: _interval(actionStart, _itemMs),
                                  child: widget.footer,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.subtitle,
    required this.badgeSize,
    required this.topInset,
    required this.isDark,
  });

  final String title;
  final String subtitle;
  final double badgeSize;
  final double topInset;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: const AuthWaveClipper(),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: isDark
                ? [
                    Theme.of(context).colorScheme.primaryContainer,
                    context.palette.primary,
                  ]
                : [
                    context.palette.primary,
                    Theme.of(context).colorScheme.secondary,
                  ],
          ),
        ),
        child: Padding(
          padding: EdgeInsetsDirectional.only(
            top: topInset,
            bottom: 40,
            start: 24,
            end: 24,
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: badgeSize,
                    height: badgeSize,
                    decoration: BoxDecoration(
                      color: context.palette.onPrimary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(
                            context,
                          ).colorScheme.shadow.withValues(alpha: 0.35),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.school_rounded,
                      size: badgeSize * 0.53,
                      color: context.palette.primary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: context.palette.onPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.palette.onPrimary.withValues(alpha: 0.85),
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

/// Brand-gradient primary button (56 high, 16 radius) used by the auth
/// screens in place of the flat [AppButton.primary].
class AuthGradientButton extends StatelessWidget {
  const AuthGradientButton(
    this.text, {
    super.key,
    required this.onPressed,
    this.loading = false,
  });

  final String text;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final primary = context.palette.primary;

    return Opacity(
      opacity: onPressed == null && !loading ? 0.5 : 1,
      child: SizedBox(
        height: 56,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [primary, Theme.of(context).colorScheme.secondary],
              ),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              boxShadow: enabled
                  ? [
                      BoxShadow(
                        color: primary.withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              onTap: enabled ? onPressed : null,
              child: Center(
                child: loading
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: context.palette.onPrimary,
                        ),
                      )
                    : Text(
                        text,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: context.palette.onPrimary,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Divider plus a "prompt  link" row, e.g. "مفيش حساب؟ سجل حساب جديد".
class AuthFooterLink extends StatelessWidget {
  const AuthFooterLink({
    super.key,
    required this.prompt,
    required this.action,
    required this.onTap,
  });

  final String prompt;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      children: [
        Divider(color: palette.divider, thickness: 1),
        const SizedBox(height: AppSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              prompt,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                color: palette.textSecondary,
              ),
            ),
            TextButton(
              onPressed: onTap,
              style: TextButton.styleFrom(foregroundColor: palette.primary),
              child: Text(
                action,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Brand-gradient block with the same wave bottom edge as [AuthShell]'s
/// header, for the home and account tabs. The wave shaves up to ~40px off the
/// bottom, so keep [child] clear of that. An optional [imageUrl] (e.g. the
/// center's cover) is shown underneath a translucent brand tint.
class GradientWaveHeader extends StatelessWidget {
  const GradientWaveHeader({
    super.key,
    required this.child,
    this.height,
    this.imageUrl,
  });

  final Widget child;
  final double? height;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final isDark = context.palette.isDark;
    final colors = isDark
        ? [
            Theme.of(context).colorScheme.primaryContainer,
            context.palette.primary,
          ]
        : [context.palette.primary, Theme.of(context).colorScheme.secondary];
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;

    return ClipPath(
      clipper: const AuthWaveClipper(),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            if (hasImage)
              Positioned.fill(
                child: CachedNetworkImage(
                  imageUrl: imageUrl!,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => const SizedBox.shrink(),
                  errorWidget: (context, url, error) => const SizedBox.shrink(),
                ),
              ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: hasImage
                        ? [for (final c in colors) c.withValues(alpha: 0.88)]
                        : colors,
                  ),
                ),
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}
