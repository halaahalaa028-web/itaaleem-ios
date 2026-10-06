import 'dart:math' as math;

import 'package:itaaleem/core/widgets/auth_shell.dart';
import 'package:itaaleem/features/onboarding/presentation/providers/onboarding_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:itaaleem/core/theme/app_palette.dart';
import 'package:itaaleem/core/theme/app_radius.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';

class _OnboardingPageData {
  const _OnboardingPageData({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;
}

const _pages = [
  _OnboardingPageData(
    icon: Icons.search_rounded,
    title: 'ابحث عن سنترك',
    description: 'دوّر على السنتر أو المدرس بالاسم أو الكود وانضم بضغطة واحدة',
  ),
  _OnboardingPageData(
    icon: Icons.play_circle_outline_rounded,
    title: 'تعلّم في أي وقت',
    description: 'شاهد المحاضرات، حل الامتحانات، وتابع تقدمك خطوة بخطوة',
  ),
  _OnboardingPageData(
    icon: Icons.chat_bubble_outline_rounded,
    title: 'تواصل مع مدرسك',
    description: 'تواصل مباشرة مع المدرس، شوف أرقام السنتر وصفحاته',
  ),
];

/// Shown once, on first launch, right after the splash screen and ahead of
/// [PermissionsOnboardingScreen] — a 3-page feature intro. "تخطي"/"ابدأ
/// الآن" both just mark the flow as seen; [AppRouter]'s redirect callback
/// takes it from there (on to permissions, then login/home), same pattern
/// as [PermissionsOnboardingScreen]'s "متابعة".
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _page = 0;
  bool _finishing = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (_finishing) return;
    setState(() => _finishing = true);
    await ref.read(onboardingSeenProvider.notifier).markSeen();
  }

  void _next() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _pages.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                const SizedBox(height: AppSpacing.xxxl),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _pages.length,
                    onPageChanged: (index) => setState(() => _page = index),
                    itemBuilder: (context, index) =>
                        _OnboardingPage(data: _pages[index]),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_pages.length, (index) {
                    final active = index == _page;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                      width: active ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: active
                            ? context.palette.primary
                            : context.palette.primaryBorder,
                        borderRadius: BorderRadius.circular(AppRadius.xs),
                      ),
                    );
                  }),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                  child: AuthGradientButton(
                    isLast ? 'ابدأ الآن' : 'التالي',
                    onPressed: isLast ? (_finishing ? null : _finish) : _next,
                    loading: isLast && _finishing,
                  ),
                ),
              ],
            ),
            if (!isLast)
              PositionedDirectional(
                top: 4,
                start: 8,
                child: TextButton(
                  onPressed: _finishing ? null : _finish,
                  style: TextButton.styleFrom(
                    foregroundColor: context.palette.textTertiary,
                  ),
                  child: const Text('تخطي'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.data});

  final _OnboardingPageData data;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Top ~50%: decorative gradient circle with the icon on top.
        Expanded(flex: 5, child: _Illustration(icon: data.icon)),
        Expanded(
          flex: 4,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
            child: Column(
              children: [
                const SizedBox(height: AppSpacing.sm),
                Text(
                  data.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  data.description,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    color: context.palette.textSecondary,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Illustration extends StatelessWidget {
  const _Illustration({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(
          constraints.maxWidth * 0.8,
          constraints.maxHeight,
        );
        return Center(
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        palette.primarySurface,
                        palette.primarySurface.withValues(alpha: 0.2),
                      ],
                    ),
                  ),
                  child: SizedBox.square(dimension: size),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: palette.surface.withValues(alpha: 0.7),
                  ),
                  child: SizedBox.square(dimension: size * 0.58),
                ),
                Icon(icon, size: 80, color: palette.primary),
              ],
            ),
          ),
        );
      },
    );
  }
}
