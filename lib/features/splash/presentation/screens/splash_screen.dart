import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';
import 'package:itaaleem/features/auth/presentation/providers/auth_controller.dart';
import 'package:itaaleem/features/center/presentation/providers/branding_provider.dart';
import 'package:itaaleem/features/splash/presentation/providers/app_startup.dart';

/// Native-size logo width, so the first Flutter frame lines up exactly with
/// the native launch screen (Android `splash_logo` / iOS `LaunchImage`).
const _logoWidth = 140.0;

/// Dark mode puts the mark on a light tile (its navy reads poorly on a dark
/// background) — the same tile baked into the native night artwork.
const _tileSize = 150.0;
const _tileLogoWidth = 118.0;

/// Branded cold-start screen. It never navigates: the router keeps the app
/// here until [splashReleasedProvider] flips, which this screen does after
/// [appStartupProvider] succeeds (session restored, center loaded,
/// onboarding flags read, at least [minSplashDuration] shown) and its own
/// fade-out has played — so the next page (login or home) fades in over a
/// clean background instead of jumping in.
///
/// Timeline: the logo starts exactly where the native launch screen left it
/// (no blink) and settles in with a soft scale while it glides up; the app
/// name fades in 400ms after the logo; animated dots show progress; when the
/// startup work finishes the joined center's own logo fades in at the
/// bottom. If the startup work times out (no/slow network) the dots give way
/// to a "تعذر الاتصال" message with a retry.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  /// 0–600ms logo, 600–1000ms room for the name, 1000–1500ms name + dots.
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );
  late final AnimationController _dots = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );
  late final AnimationController _exit = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  );

  /// Starts at 1 (the native splash's exact size, so the handoff doesn't
  /// jump), swells slightly and settles back.
  late final Animation<double> _logoScale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 1,
        end: 1.06,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 45,
    ),
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 1.06,
        end: 1,
      ).chain(CurveTween(curve: Curves.easeInOutCubic)),
      weight: 55,
    ),
  ]).animate(CurvedAnimation(parent: _intro, curve: const Interval(0, 0.4)));
  late final Animation<double> _glow = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0, 0.6, curve: Curves.easeOut),
  );
  late final Animation<double> _nameRoom = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.4, 0.67, curve: Curves.easeInOutCubic),
  );
  late final Animation<double> _nameFade = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.67, 1, curve: Curves.easeOutCubic),
  );
  late final Animation<Offset> _nameSlide = Tween<Offset>(
    begin: const Offset(0, 0.25),
    end: Offset.zero,
  ).animate(_nameFade);

  /// Everything fades out (the logo easing up a touch) before the handoff.
  late final Animation<double> _exitFade = Tween<double>(
    begin: 1,
    end: 0,
  ).animate(CurvedAnimation(parent: _exit, curve: Curves.easeOutCubic));
  late final Animation<double> _exitScale = Tween<double>(
    begin: 1,
    end: 1.04,
  ).animate(CurvedAnimation(parent: _exit, curve: Curves.easeOutCubic));

  bool _started = false;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual(appStartupProvider, (previous, next) {
      if (next.hasValue && !next.isLoading) _handOver();
    }, fireImmediately: true);
    // A timed-out startup recovers by itself if the session restore settles
    // late (e.g. the network came back).
    ref.listenManual(authControllerProvider, (previous, next) {
      if (!next.isLoading && ref.read(startupWorkProvider).hasError) {
        ref.invalidate(startupWorkProvider);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_started) return;
    _started = true;
    // Decode the logo before Flutter's first frame is shown (see
    // FirstFrameGate) so the native splash hands straight over to it.
    precacheImage(
      const AssetImage(splashLogoAsset),
      context,
    ).whenComplete(FirstFrameGate.release);
    if (_reduceMotion) {
      _intro.value = 1;
    } else {
      _intro.forward();
      _dots.repeat();
    }
  }

  Future<void> _handOver() async {
    if (_exit.isAnimating || _exit.isCompleted) return;
    if (!_reduceMotion) {
      try {
        // Let the intro finish first if startup was faster than it.
        if (_intro.isAnimating) await _intro.forward().orCancel;
        if (!mounted) return;
        await _exit.forward().orCancel;
      } on TickerCanceled {
        // Disposed mid-animation — the release below still goes through.
      }
    }
    ref.read(splashReleasedProvider.notifier).release();
  }

  @override
  void dispose() {
    _intro.dispose();
    _dots.dispose();
    _exit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Same colors as the native launch window (values/colors.xml,
    // LaunchBackground.colorset).
    final background = isDark ? cs.surfaceContainerLowest : cs.surface;
    final work = ref.watch(startupWorkProvider);
    final failed = work.hasError && !work.isLoading;
    final centerLogo = ref.watch(brandingProvider.select((b) => b.logoUrl));

    return Scaffold(
      backgroundColor: background,
      body: FadeTransition(
        opacity: _exitFade,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // A soft brand-colored glow behind the logo.
            FadeTransition(
              opacity: _glow,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    radius: 0.75,
                    colors: [
                      cs.primary.withValues(alpha: isDark ? 0.16 : 0.08),
                      background.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                // Scales the whole block down on very short screens
                // (landscape phones, split screen) instead of overflowing.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ScaleTransition(
                        scale: _exitScale,
                        child: ScaleTransition(
                          scale: _logoScale,
                          child: _Logo(isDark: isDark),
                        ),
                      ),
                      SizeTransition(
                        sizeFactor: _nameRoom,
                        axisAlignment: -1,
                        child: FadeTransition(
                          opacity: _nameFade,
                          child: SlideTransition(
                            position: _nameSlide,
                            child: Padding(
                              padding: const EdgeInsets.only(
                                top: AppSpacing.lg,
                              ),
                              child: _NameBlock(
                                failed: failed,
                                dots: _dots,
                                onRetry: () => retryStartup(ref),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // The joined center's logo (white-label), once startup is done.
            PositionedDirectional(
              start: 0,
              end: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    switchInCurve: Curves.easeOutCubic,
                    child:
                        work.hasValue &&
                            centerLogo != null &&
                            centerLogo.isNotEmpty
                        ? _CenterLogo(
                            key: ValueKey(centerLogo),
                            url: centerLogo,
                          )
                        : const SizedBox(height: 56),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// App name + tagline, then the loading dots — or the error with a retry.
class _NameBlock extends StatelessWidget {
  const _NameBlock({
    required this.failed,
    required this.dots,
    required this.onRetry,
  });

  final bool failed;
  final Animation<double> dots;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(
          'منصة أونلاين',
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 28,
            fontWeight: FontWeight.w800,
            height: 1.2,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'تعليم بلا حدود',
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: failed
                ? _StartupError(onRetry: onRetry)
                : SizedBox(
                    height: 24,
                    child: Center(
                      child: _LoadingDots(animation: dots, color: cs.primary),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

/// Shown in place of the loading dots when startup timed out.
class _StartupError extends StatelessWidget {
  const _StartupError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 300),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_off_rounded, color: cs.error, size: 32),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'تعذر الاتصال',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'تأكد من اتصالك بالإنترنت ثم حاول مرة أخرى',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 13,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.base),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text(
              'إعادة المحاولة',
              style: TextStyle(fontFamily: 'Cairo'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final image = Image.asset(
      splashLogoAsset,
      width: isDark ? _tileLogoWidth : _logoWidth,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      semanticLabel: 'منصة أونلاين',
    );
    if (!isDark) return image;
    return Container(
      width: _tileSize,
      height: _tileSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: cs.inverseSurface,
        borderRadius: BorderRadius.circular(_tileSize * 0.24),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withValues(alpha: 0.25),
            blurRadius: 32,
            spreadRadius: -4,
          ),
        ],
      ),
      child: image,
    );
  }
}

/// Three dots rising and brightening in a wave.
class _LoadingDots extends StatelessWidget {
  const _LoadingDots({required this.animation, required this.color});

  final Animation<double> animation;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'جارٍ التحميل',
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [for (var i = 0; i < 3; i++) _dot(i)],
        ),
      ),
    );
  }

  Widget _dot(int i) {
    // Each dot peaks a third of a cycle after the previous one.
    final phase = (animation.value - i / 3) % 1;
    final wave = math.sin(phase * math.pi * 2) * 0.5 + 0.5;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Transform.translate(
        offset: Offset(0, -4 * wave),
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.35 + 0.65 * wave),
          ),
        ),
      ),
    );
  }
}

class _CenterLogo extends StatelessWidget {
  const _CenterLogo({super.key, required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 56,
      height: 56,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: cs.surface,
        border: Border.all(color: cs.outlineVariant),
      ),
      child: ClipOval(
        child: CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          fadeInDuration: const Duration(milliseconds: 300),
          placeholder: (context, url) => const SizedBox.shrink(),
          errorWidget: (context, url, error) =>
              Icon(Icons.school_rounded, color: cs.primary),
        ),
      ),
    );
  }
}
