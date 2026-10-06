import 'package:itaaleem/app/router/app_router.dart';
import 'package:itaaleem/core/network/connectivity_provider.dart';
import 'package:itaaleem/core/widgets/app_bottom_nav.dart';
import 'package:itaaleem/features/admin/presentation/providers/admin_provider.dart';
import 'package:itaaleem/features/center_admin/presentation/screens/center_dashboard_screen.dart';
import 'package:itaaleem/features/home/presentation/providers/content_refresh.dart';
import 'package:itaaleem/features/home/presentation/screens/account_tab.dart';
import 'package:itaaleem/features/home/presentation/screens/home_screen.dart';
import 'package:itaaleem/features/home/presentation/screens/subjects_screen.dart';
import 'package:itaaleem/features/update/presentation/widgets/update_available_banner.dart';
import 'package:itaaleem/features/video/presentation/screens/downloads_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:itaaleem/core/theme/app_palette.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';
/// Main shell: a 4-tab bottom navigation bar (الرئيسية / المواد / التنزيلات /
/// حسابي) backed by a [PageView] so the tabs can also be swiped
/// left/right. Plain local widget state (not go_router nested routes) —
/// simplest fit for four flat, non-deep-linked tabs. Admins (see
/// [isAdminProvider]) get a fifth "الإدارة" tab. Every logged-in student
/// lands here
/// regardless of center membership — [HomeScreen] itself switches between
/// the join-by-code view and the branded home depending on
/// [centerMembershipProvider].
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _currentIndex = 0;

  /// Which tabs have actually been visited — a tab's real widget (and every
  /// provider it watches) is only ever built the first time its index lands
  /// here, instead of every tab's worth of network requests firing the
  /// instant the shell mounts. See [_LazyTab].
  final Set<int> _visitedTabs = {0};

  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
    // Instantiates the watcher so it reloads content when the profile's
    // access flags change. The profile itself is already fetched once on
    // session restore/login, and again on pull-to-refresh — no polling.
    ref.read(subscriptionWatcherProvider);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Tapping a bottom-nav destination animates the [PageView] to it;
  /// [_onPageChanged] (fired either way, including from a manual swipe)
  /// is the single place that actually updates [_currentIndex].
  void _goToTab(int index) {
    // Animating across several pages fires [_onPageChanged] for each one in
    // between, building (and fetching) tabs the student never opened — so
    // only neighbouring tabs slide, farther ones jump straight there.
    if ((index - _currentIndex).abs() > 1) {
      _pageController.jumpToPage(index);
      return;
    }
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
      _visitedTabs.add(index);
    });
  }

  static const _adminTabIndex = 4;

  @override
  Widget build(BuildContext context) {
    final isOnline = ref.watch(connectivityStatusProvider).valueOrNull ?? true;
    final isAdmin = ref.watch(isAdminProvider);
    // Lost admin rights (role changed on a profile refresh) while on the
    // admin tab — fall back to the home tab instead of a dangling index.
    ref.listen(isAdminProvider, (previous, next) {
      if (!next && _currentIndex >= _adminTabIndex) {
        _pageController.jumpToPage(0);
        setState(() => _currentIndex = 0);
      }
    });
    return Scaffold(
      body: Column(
        children: [
          const UpdateAvailableBanner(),
          if (!isOnline)
            Material(
              color: context.palette.warning.withValues(alpha: 0.15),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 6, 8, 6),
                  child: Row(
                    children: [
                      const Icon(Icons.wifi_off_rounded, size: 18),
                      const SizedBox(width: AppSpacing.sm),
                      const Expanded(
                        child: Text(
                          'لا يوجد اتصال بالإنترنت — المحاضرات المحمّلة متاحة',
                          style: TextStyle(fontFamily: 'Cairo', fontSize: 12),
                        ),
                      ),
                      TextButton(
                        onPressed: () => _goToTab(2),
                        child: const Text('التنزيلات'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              children: [
                _LazyTab(
                  visited: _visitedTabs.contains(0),
                  builder: () => HomeScreen(
                    onSubjectsTap: () => _goToTab(1),
                    onNotificationsTap: () => context.push(notificationsPath),
                  ),
                ),
                _LazyTab(
                  visited: _visitedTabs.contains(1),
                  builder: () => const SubjectsScreen(),
                ),
                _LazyTab(
                  visited: _visitedTabs.contains(2),
                  builder: () => const DownloadsScreen(),
                ),
                _LazyTab(
                  visited: _visitedTabs.contains(3),
                  builder: () => const AccountTab(),
                ),
                if (isAdmin)
                  _LazyTab(
                    visited: _visitedTabs.contains(_adminTabIndex),
                    builder: () => const CenterDashboardScreen(),
                  ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: AppBottomNav(
        currentIndex: _currentIndex.clamp(0, isAdmin ? _adminTabIndex : 3),
        onTap: _goToTab,
        items: [
          const AppBottomNavItem(
            icon: Icons.home_outlined,
            selectedIcon: Icons.home_rounded,
            label: 'الرئيسية',
          ),
          const AppBottomNavItem(
            icon: Icons.menu_book_outlined,
            selectedIcon: Icons.menu_book_rounded,
            label: 'المواد',
          ),
          const AppBottomNavItem(
            icon: Icons.download_outlined,
            selectedIcon: Icons.download_rounded,
            label: 'التنزيلات',
          ),
          const AppBottomNavItem(
            icon: Icons.person_outline_rounded,
            selectedIcon: Icons.person_rounded,
            label: 'حسابي',
          ),
          if (isAdmin)
            const AppBottomNavItem(
              icon: Icons.admin_panel_settings_outlined,
              selectedIcon: Icons.admin_panel_settings_rounded,
              label: 'الإدارة',
            ),
        ],
      ),
    );
  }
}

/// Defers building [builder]'s widget (and therefore every provider it
/// watches) until [visited] first turns `true`, then keeps that built
/// widget — and its place in the [PageView]'s keep-alive bucket — for good,
/// so switching tabs later never re-triggers its initial fetches.
class _LazyTab extends StatefulWidget {
  const _LazyTab({required this.visited, required this.builder});

  final bool visited;
  final Widget Function() builder;

  @override
  State<_LazyTab> createState() => _LazyTabState();
}

class _LazyTabState extends State<_LazyTab> with AutomaticKeepAliveClientMixin {
  Widget? _built;

  @override
  bool get wantKeepAlive => widget.visited;

  @override
  void didUpdateWidget(covariant _LazyTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visited != oldWidget.visited) updateKeepAlive();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (widget.visited) _built ??= widget.builder();
    return _built ?? const SizedBox.shrink();
  }
}
