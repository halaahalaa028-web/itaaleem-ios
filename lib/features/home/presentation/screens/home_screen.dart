import 'package:itaaleem/features/home/presentation/providers/content_refresh.dart';
import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:itaaleem/app/router/app_router.dart';
import 'package:itaaleem/app/router/route_args.dart';
import 'package:itaaleem/core/theme/app_radius.dart';
import 'package:itaaleem/core/widgets/app_card.dart';
import 'package:itaaleem/core/widgets/app_progress_bar.dart';
import 'package:itaaleem/core/widgets/auth_shell.dart';
import 'package:itaaleem/core/widgets/empty_state.dart';
import 'package:itaaleem/core/widgets/section_header.dart';
import 'package:itaaleem/core/widgets/student_avatar.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';
import 'package:itaaleem/core/widgets/skeleton_loading.dart';
import 'package:itaaleem/features/auth/presentation/providers/auth_controller.dart';
import 'package:itaaleem/features/center/domain/entities/center_model.dart';
import 'package:itaaleem/features/center/presentation/providers/center_providers.dart';
import 'package:itaaleem/features/center/presentation/screens/center_search_screen.dart';
import 'package:itaaleem/features/center/presentation/widgets/center_reviews_section.dart';
import 'package:itaaleem/features/home/domain/entities/app_banner.dart';
import 'package:itaaleem/features/home/presentation/providers/banners_provider.dart';
import 'package:itaaleem/features/notifications/data/dummy_notifications.dart';
import 'package:itaaleem/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:itaaleem/features/subjects/domain/entities/subject.dart';
import 'package:itaaleem/features/subjects/presentation/providers/subjects_providers.dart';
import 'package:itaaleem/features/subjects/presentation/screens/lesson_video_screen.dart';
import 'package:itaaleem/features/subjects/presentation/widgets/lesson_access.dart';
import 'package:itaaleem/features/subjects/presentation/widgets/subject_icon.dart';
import 'package:flutter/foundation.dart';
import 'package:itaaleem/features/subscriptions/presentation/widgets/subject_lock_gate.dart';
import 'package:flutter/material.dart';
import 'package:itaaleem/core/utils/youtube_utils.dart';
import 'package:itaaleem/features/courses/presentation/widgets/players/player_selection_sheet.dart';
import 'package:itaaleem/features/home/presentation/widgets/home_search_bar.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:itaaleem/features/settings/presentation/providers/settings_providers.dart';
import 'package:itaaleem/core/utils/safe_url.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:itaaleem/core/theme/app_palette.dart';

/// Flip to bring the general "الامتحانات" shortcut back on home.
const _showGeneralExamsShortcut = false;

class _QuickService {
  const _QuickService({
    required this.icon,
    required this.label,
    required this.description,
    required this.onTap,
    this.badge = 0,
  });

  final IconData icon;
  final String label;
  final String description;
  final VoidCallback onTap;
  final int badge;
}

class _DummySubject {
  const _DummySubject({
    required this.icon,
    required this.name,
    required this.lecturesDone,
    required this.lecturesTotal,
  });

  final IconData icon;
  final String name;
  final int lecturesDone;
  final int lecturesTotal;

  double get progress => lecturesDone / lecturesTotal;
}

const _dummySubjects = [
  _DummySubject(
    icon: Icons.calculate_rounded,
    name: 'محاسبة مالية',
    lecturesDone: 15,
    lecturesTotal: 20,
  ),
  _DummySubject(
    icon: Icons.computer_rounded,
    name: 'تكنولوجيا المعلومات',
    lecturesDone: 12,
    lecturesTotal: 20,
  ),
  _DummySubject(
    icon: Icons.functions_rounded,
    name: 'رياضيات تطبيقية',
    lecturesDone: 8,
    lecturesTotal: 20,
  ),
];

class _DummyLecture {
  const _DummyLecture({
    required this.title,
    required this.subject,
    required this.duration,
  });

  final String title;
  final String subject;
  final String duration;
}

const _dummyLectures = [
  _DummyLecture(
    title: 'مقدمة في الدوائر الكهربائية',
    subject: 'كهرباء عامة',
    duration: '45 دقيقة',
  ),
  _DummyLecture(
    title: 'قوانين كيرشوف',
    subject: 'كهرباء عامة',
    duration: '38 دقيقة',
  ),
  _DummyLecture(
    title: 'المحركات الكهربائية',
    subject: 'آلات كهربائية',
    duration: '52 دقيقة',
  ),
  _DummyLecture(
    title: 'أنظمة التحكم الآلي',
    subject: 'تحكم صناعي',
    duration: '41 دقيقة',
  ),
];

String? _gradeNameOf(CenterModel center, int? gradeId) {
  if (gradeId == null) return null;
  for (final grade in center.grades) {
    if (grade.id == gradeId) return grade.name;
  }
  return null;
}

/// "الرئيسية" tab: the join-by-code screen while the student hasn't joined
/// a center yet ([centerMembershipProvider] resolves to `null`), or the
/// branded home once they have — switching automatically the moment
/// membership changes (joining, or leaving via the profile tab), no
/// navigation involved.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({
    required this.onSubjectsTap,
    required this.onNotificationsTap,
    super.key,
  });

  final VoidCallback onSubjectsTap;
  final VoidCallback onNotificationsTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membershipAsync = ref.watch(centerMembershipProvider);
    if (kDebugMode) {
      debugPrint(
        'HomeScreen state: joined=${membershipAsync.valueOrNull?.centerId} '
        'isLoading=${membershipAsync.isLoading} '
        'hasError=${membershipAsync.hasError}',
      );
    }
    if (membershipAsync.valueOrNull == null && !membershipAsync.isLoading) {
      return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('ابحث عن سنترك'),
        ),
        body: const SafeArea(child: CenterSearchBody()),
      );
    }

    return _JoinedHome(
      onSubjectsTap: onSubjectsTap,
      onNotificationsTap: onNotificationsTap,
    );
  }
}

/// The branded home content shown once a student has joined a center.
class _JoinedHome extends ConsumerWidget {
  const _JoinedHome({
    required this.onSubjectsTap,
    required this.onNotificationsTap,
  });

  final VoidCallback onSubjectsTap;
  final VoidCallback onNotificationsTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membership = ref.watch(centerMembershipProvider).valueOrNull;
    final center = ref.watch(joinedCenterProvider);
    final gradeName = (membership != null && center != null)
        ? _gradeNameOf(center, membership.gradeId)
        : null;
    if (kDebugMode) {
      debugPrint(
        '>>> HOME center source: logo=${center?.logo}, cover=${center?.cover}',
      );
    }
    // Only the two fields this screen shows — watching the whole Student
    // rebuilt the entire home on every unrelated profile refresh.
    final isDemo = ref.watch(isDemoSessionProvider);
    final fullName = ref.watch(
      authControllerProvider.select((s) => s.valueOrNull?.fullName),
    );
    final avatarUrl = ref.watch(
      authControllerProvider.select((s) => s.valueOrNull?.avatarUrl),
    );
    final nameParts = fullName?.trim().split(' ') ?? const <String>[];
    final studentName = nameParts.isNotEmpty ? nameParts.first : 'طالب';
    final unreadCount = isDemo
        ? dummyNotifications.where((n) => n.unread).length
        : (ref.watch(unreadNotificationsCountProvider).valueOrNull ?? 0);

    final quickServices = <_QuickService>[
      _QuickService(
        icon: Icons.menu_book_rounded,
        label: 'المواد',
        description: 'كل المواد والمحاضرات',
        onTap: onSubjectsTap,
      ),
      // Exams now live inside each lecture (subject → lecture → exams);
      // the general shortcut is hidden from home, the screen/route remain.
      if (_showGeneralExamsShortcut)
        _QuickService(
          icon: Icons.quiz_rounded,
          label: 'الامتحانات',
          description: 'اختبر مستواك',
          onTap: () => context.push(examsPath),
        ),
      _QuickService(
        icon: Icons.notifications_rounded,
        label: 'الإشعارات',
        description: unreadCount > 0 ? '$unreadCount جديد' : 'لا جديد',
        badge: unreadCount,
        onTap: onNotificationsTap,
      ),
      _QuickService(
        icon: Icons.chat_bubble_rounded,
        label: 'تواصل',
        description: 'كلّم السنتر',
        onTap: () => context.push(chatPath),
      ),
      _QuickService(
        icon: Icons.phone_in_talk_rounded,
        label: 'اتصل بنا',
        description: 'أرقام السنتر',
        onTap: () =>
            _callCenter(context, ref, center?.phoneNumbers ?? const []),
      ),
    ];

    // The header paints under the status bar, so its icons need to be light.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: RefreshIndicator(
          edgeOffset: MediaQuery.paddingOf(context).top,
          onRefresh: () => refreshAll(ref),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(
                  centerCover: center?.cover,
                  studentName: studentName,
                  avatarUrl: avatarUrl,
                  unreadCount: unreadCount,
                  onNotificationsTap: onNotificationsTap,
                ),
                // Always visible, local search over subjects/doctors/lectures.
                if (!isDemo)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.screenHorizontal,
                      AppSpacing.md,
                      AppSpacing.screenHorizontal,
                      0,
                    ),
                    child: HomeSearchBar(),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenHorizontal,
                    AppSpacing.sectionSpacing,
                    AppSpacing.screenHorizontal,
                    0,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                        colors: [
                          HSLColor.fromColor(
                                Theme.of(context).colorScheme.primary,
                              )
                              .withLightness(
                                (HSLColor.fromColor(
                                          Theme.of(context).colorScheme.primary,
                                        ).lightness *
                                        0.7)
                                    .clamp(0.0, 1.0),
                              )
                              .toColor(),
                          Theme.of(context).colorScheme.primary,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'مرحباً $studentName 👋',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      color: context.palette.onPrimary,
                                    ),
                              ),
                              if (gradeName != null) ...[
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  gradeName,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: context.palette.onPrimary
                                            .withValues(alpha: 0.8),
                                      ),
                                ),
                              ],
                              const SizedBox(height: 2),
                              Text(
                                'مستعد تكمل رحلتك التعليمية؟',
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 13,
                                  color: context.palette.onPrimary.withValues(
                                    alpha: 0.9,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: context.palette.onPrimary.withValues(
                              alpha: 0.16,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.school_rounded,
                            size: 30,
                            color: context.palette.onPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _BannersSection(onStartTap: onSubjectsTap, isDemo: isDemo),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenHorizontal,
                    AppSpacing.sectionSpacing,
                    AppSpacing.screenHorizontal,
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionHeader(
                        title: 'الخدمات السريعة',
                        padding: EdgeInsets.only(bottom: AppSpacing.md),
                      ),
                      // Rows sized by their content (not a fixed aspect ratio),
                      // so large text scales / narrow screens can't overflow.
                      for (var i = 0; i < quickServices.length; i += 2)
                        Padding(
                          padding: EdgeInsets.only(top: i == 0 ? 0 : 12),
                          child: IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: _QuickServiceTile(
                                    service: quickServices[i],
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: i + 1 < quickServices.length
                                      ? _QuickServiceTile(
                                          service: quickServices[i + 1],
                                        )
                                      : const SizedBox.shrink(),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenHorizontal,
                    AppSpacing.sectionSpacing,
                    AppSpacing.screenHorizontal,
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionHeader(
                        title: 'موادك الدراسية',
                        onSeeAll: onSubjectsTap,
                        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      ),
                      if (isDemo)
                        for (final subject in _dummySubjects)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _SubjectRow(subject: subject),
                          )
                      else
                        const _RealSubjectsSection(),
                    ],
                  ),
                ),
                if (isDemo) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenHorizontal,
                      AppSpacing.sm,
                      AppSpacing.screenHorizontal,
                      0,
                    ),
                    child: SectionHeader(
                      title: 'آخر المحاضرات',
                      onSeeAll: onSubjectsTap,
                      padding: EdgeInsets.zero,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    height: 200,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                      ),
                      scrollDirection: Axis.horizontal,
                      itemCount: _dummyLectures.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: AppSpacing.md),
                      itemBuilder: (context, index) =>
                          _LectureCard(lecture: _dummyLectures[index]),
                    ),
                  ),
                ] else
                  _RealLecturesSection(onSeeAll: onSubjectsTap),
                if (!isDemo && membership != null)
                  CenterReviewsSection(
                    centerId: membership.centerId,
                    fallbackRating: center?.rating ?? 0,
                  ),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Gradient wave header: student avatar + greeting on one side, the
/// notifications bell on the other, and a search bar overlapping the curve.
/// The bar opens the subjects tab — there's no dedicated search screen.
class _Header extends StatelessWidget {
  const _Header({
    required this.studentName,
    required this.unreadCount,
    required this.onNotificationsTap,
    this.avatarUrl,
    this.centerCover,
  });

  final String studentName;
  final String? avatarUrl;
  final String? centerCover;
  final int unreadCount;
  final VoidCallback onNotificationsTap;

  static const _overlap = 26.0;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;

    return Stack(
      children: [
        Column(
          children: [
            GradientWaveHeader(
              imageUrl: centerCover,
              child: Padding(
                padding: EdgeInsetsDirectional.fromSTEB(
                  20,
                  top + 16,
                  20,
                  _overlap + 40,
                ),
                child: Row(
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: context.palette.onPrimary.withValues(
                            alpha: 0.8,
                          ),
                          width: 2,
                        ),
                      ),
                      child: StudentAvatar(radius: 26, avatarUrl: avatarUrl),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'أهلاً، $studentName',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: context.palette.onPrimary,
                            ),
                          ),
                          Text(
                            'أكمل رحلتك التعليمية',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: context.palette.onPrimary.withValues(
                                    alpha: 0.8,
                                  ),
                                ),
                          ),
                        ],
                      ),
                    ),
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: context.palette.onPrimary.withValues(
                              alpha: 0.18,
                            ),
                            shape: BoxShape.circle,
                            border: Border.fromBorderSide(
                              BorderSide(
                                color: context.palette.onPrimary.withValues(
                                  alpha: 0.4,
                                ),
                              ),
                            ),
                          ),
                          child: IconButton(
                            onPressed: onNotificationsTap,
                            tooltip: 'الإشعارات',
                            icon: Icon(
                              Icons.notifications_none_rounded,
                              color: context.palette.onPrimary,
                            ),
                          ),
                        ),
                        if (unreadCount > 0)
                          PositionedDirectional(
                            top: 2,
                            end: 2,
                            child: Container(
                              constraints: const BoxConstraints(
                                minWidth: 18,
                                minHeight: 18,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.xs,
                              ),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.error,
                                borderRadius: BorderRadius.circular(9),
                                border: Border.all(
                                  color: context.palette.onPrimary,
                                  width: 1.5,
                                ),
                              ),
                              child: Text(
                                unreadCount > 99 ? '99+' : '$unreadCount',
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 10,
                                  height: 1.2,
                                  fontWeight: FontWeight.w700,
                                  color: Theme.of(context).colorScheme.onError,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// `GET /banners`, with the static [_StudyBanner] as a fallback for a demo
/// session, a still-loading/errored call, or a center with no banners set.
class _BannersSection extends ConsumerWidget {
  const _BannersSection({required this.onStartTap, required this.isDemo});

  final VoidCallback onStartTap;
  final bool isDemo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final banners = ref.watch(bannersProvider).valueOrNull ?? const [];
    final Widget child;
    if (banners.isNotEmpty) {
      child = _BannerCarousel(banners: banners, onStartTap: onStartTap);
    } else if (isDemo) {
      child = _StudyBanner(onStartTap: onStartTap);
    } else {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        AppSpacing.sectionSpacing,
        AppSpacing.screenHorizontal,
        0,
      ),
      child: child,
    );
  }
}

/// Horizontal auto-scrolling carousel (every 5 seconds, wraps around) with a
/// dots indicator below — each page shows the banner's image with its title
/// overlaid, and opens [AppBanner.linkUrl] on tap when it has one.
class _BannerCarousel extends StatefulWidget {
  const _BannerCarousel({required this.banners, required this.onStartTap});

  final List<AppBanner> banners;
  final VoidCallback onStartTap;

  @override
  State<_BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<_BannerCarousel> {
  final _pageController = PageController();
  Timer? _timer;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_pageController.hasClients || widget.banners.length < 2) return;
      final next = (_page + 1) % widget.banners.length;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _openLink(String? linkUrl) async {
    if (linkUrl == null || linkUrl.isEmpty) return;
    final uri = Uri.tryParse(linkUrl);
    if (uri == null) return;
    await launchUrlSafely(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 16 / 8,
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.banners.length,
              onPageChanged: (index) => setState(() => _page = index),
              itemBuilder: (context, index) {
                final banner = widget.banners[index];
                return GestureDetector(
                  onTap: () => _openLink(banner.linkUrl),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: banner.imageUrl,
                        memCacheWidth:
                            (MediaQuery.sizeOf(context).width *
                                    MediaQuery.devicePixelRatioOf(context))
                                .round(),
                        fit: BoxFit.cover,
                        placeholder: (context, url) => DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: context.palette.brandGradient,
                          ),
                        ),
                        errorWidget: (context, url, error) => DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: context.palette.brandGradient,
                          ),
                        ),
                      ),
                      if (banner.title != null && banner.title!.isNotEmpty)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(16, 24, 16, 14),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.transparent, Colors.black45],
                              ),
                            ),
                            child: Text(
                              banner.title!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          if (widget.banners.length > 1)
            Container(
              color: context.palette.surface,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < widget.banners.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _page ? 18 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i == _page
                            ? context.palette.primary
                            : context.palette.primaryMuted,
                        borderRadius: BorderRadius.circular(AppRadius.xs),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _StudyBanner extends StatelessWidget {
  const _StudyBanner({required this.onStartTap});

  final VoidCallback onStartTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(gradient: context.palette.brandGradient),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ابدأ مذاكرتك النهارده 🚀',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: context.palette.onPrimary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'تابع محاضراتك وراجع موادك بسهولة',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.palette.onPrimary.withValues(
                            alpha: 0.8,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: onStartTap,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.base,
                              vertical: AppSpacing.sm,
                            ),
                            decoration: BoxDecoration(
                              color: context.palette.onPrimary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'ابدأ الآن',
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: context.palette.primary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          PositionedDirectional(
            top: -20,
            start: -20,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.palette.gold.withValues(alpha: 0.18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickServiceTile extends StatefulWidget {
  const _QuickServiceTile({required this.service});

  final _QuickService service;

  @override
  State<_QuickServiceTile> createState() => _QuickServiceTileState();
}

class _QuickServiceTileState extends State<_QuickServiceTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 100),
    lowerBound: 0.95,
    upperBound: 1.0,
    value: 1.0,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ScaleTransition(
      scale: _controller,
      child: GestureDetector(
        onTapDown: (_) => _controller.reverse(),
        onTapUp: (_) => _controller.forward(),
        onTapCancel: () => _controller.forward(),
        child: AppCard(
          onTap: widget.service.onTap,
          padding: const EdgeInsets.all(AppSpacing.base),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      widget.service.icon,
                      size: 22,
                      color: scheme.primary,
                    ),
                  ),
                  const Spacer(),
                  if (widget.service.badge > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.error,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        widget.service.badge > 99
                            ? '99+'
                            : '${widget.service.badge}',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: scheme.onError,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                widget.service.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                widget.service.description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 11,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubjectRow extends StatelessWidget {
  const _SubjectRow({required this.subject});

  final _DummySubject subject;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: context.palette.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(subject.icon, color: context.palette.primary, size: 22),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subject.name,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${subject.lecturesDone} من ${subject.lecturesTotal} درس',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.palette.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                AppProgressBar(progress: subject.progress),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(
            '${(subject.progress * 100).round()}%',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: context.palette.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _LectureCard extends StatelessWidget {
  const _LectureCard({required this.lecture});

  final _DummyLecture lecture;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: AppCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.lg),
              ),
              child: Container(
                height: 90,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: context.palette.cardGradient,
                ),
                child: Center(
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: context.palette.onPrimary.withValues(alpha: 0.7),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.play_arrow_rounded,
                      color: context.palette.primary,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lecture.subject,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 10,
                      color: context.palette.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    lecture.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 12,
                        color: context.palette.textTertiary,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        lecture.duration,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 10,
                          color: context.palette.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Real-data "موادك الدراسية": the first 3 subjects from `GET /subjects`.
class _RealSubjectsSection extends ConsumerWidget {
  const _RealSubjectsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjectsAsync = ref.watch(subjectsListProvider);
    ref.watch(prefetchFirstSubjectProvider);
    if (kDebugMode && subjectsAsync.isLoading) {
      debugPrint('Loading subjects...');
    }

    return subjectsAsync.when(
      loading: () => const SkeletonList(count: 3, itemHeight: 74),
      error: (error, _) {
        if (kDebugMode) debugPrint('Subjects load failed: $error');
        return _InlineRetry(
          onRetry: () => ref.invalidate(subjectsListProvider),
        );
      },
      data: (subjects) => subjects.isEmpty
          ? const EmptyState(
              message: 'مفيش مواد متاحة حالياً',
              verticalPadding: AppSpacing.md,
            )
          : Column(
              children: [
                for (final subject in subjects.take(3))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _RealSubjectRow(subject: subject),
                  ),
              ],
            ),
    );
  }
}

class _RealSubjectRow extends StatelessWidget {
  const _RealSubjectRow({required this.subject});

  final Subject subject;

  @override
  Widget build(BuildContext context) {
    return SubjectLockGate(
      subjectId: subject.id,
      subjectName: subject.name,
      child: _card(context),
    );
  }

  Widget _card(BuildContext context) {
    return AppCard(
      onTap: () => context.push('/subject-detail/${subject.id}'),
      child: Row(
        children: [
          SubjectIcon(
            iconUrl: subject.iconUrl,
            size: 48,
            iconSize: 22,
            seed: subject.id,
            name: subject.name,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subject.name,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${subject.lessonsCount} محاضرة',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.palette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_left_rounded, color: context.palette.textTertiary),
        ],
      ),
    );
  }
}

/// Real-data "آخر المحاضرات": the first subject's lessons.
class _RealLecturesSection extends ConsumerWidget {
  const _RealLecturesSection({required this.onSeeAll});

  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lessonsAsync = ref.watch(homeLessonsProvider);

    // Empty or failed -> the whole section (header included) is hidden.
    final lessons = lessonsAsync.valueOrNull;
    if (lessonsAsync.hasValue && (lessons == null || lessons.isEmpty)) {
      return const SizedBox.shrink();
    }
    if (lessonsAsync.hasError) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenHorizontal,
            AppSpacing.sm,
            AppSpacing.screenHorizontal,
            0,
          ),
          child: SectionHeader(
            title: 'آخر المحاضرات',
            onSeeAll: onSeeAll,
            padding: EdgeInsets.zero,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (lessons == null)
          const SizedBox(
            height: 200,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: SkeletonBox(height: 200, borderRadius: AppRadius.lg),
            ),
          )
        else
          SizedBox(
            height: 210,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              scrollDirection: Axis.horizontal,
              itemCount: lessons.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(width: AppSpacing.md),
              itemBuilder: (context, index) =>
                  _RealLectureCard(lesson: lessons[index]),
            ),
          ),
      ],
    );
  }
}

class _RealLectureCard extends ConsumerWidget {
  const _RealLectureCard({required this.lesson});

  final SubjectLesson lesson;

  /// Plays [LessonVideoScreen]/[LessonPdfScreen] directly off
  /// `SubjectLesson.videoUrl`/`pdfUrl` — deliberately not `/lectures/:id`,
  /// which fetches from the unrelated "courses" content model's own id
  /// space (see [LessonVideoScreen]'s doc comment).
  Future<void> _open(BuildContext context, {required bool locked}) async {
    if (locked) {
      showPaidContentSheet(context, lessonId: lesson.id);
      return;
    }
    if (lesson.canPlayVideo) {
      YoutubePlayerKind? playerKind;
      if (looksLikeYouTube(lesson.videoUrl)) {
        playerKind = await pickYoutubePlayer(context);
        if (playerKind == null || !context.mounted) return;
      }
      context.push<void>(
        lessonVideoPath,
        extra: LessonVideoArgs(
          title: lesson.title,
          videoUrl: lesson.videoUrl,
          lessonId: lesson.id,
          playerKind: playerKind,
        ),
      );
    } else if (lesson.hasPdf) {
      context.push<void>(
        lessonPdfPath,
        extra: LessonPdfArgs(
          title: lesson.title,
          pdfUrl: lesson.pdfUrl,
          downloadable: lesson.isDownloadable,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locked = isLessonLocked(ref, lesson);
    return SizedBox(
      width: 200,
      child: AppCard(
        padding: EdgeInsets.zero,
        onTap: (lesson.hasVideo || lesson.hasPdf)
            ? () => _open(context, locked: locked)
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _LectureThumbnail(lesson: lesson),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    lesson.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (lesson.isFree) ...[
                    const SizedBox(height: 6),
                    const FreeLessonBadge(),
                  ] else if (locked) ...[
                    const SizedBox(height: 6),
                    Icon(
                      Icons.lock_rounded,
                      size: 14,
                      color: context.palette.textTertiary,
                    ),
                  ],
                  if (lesson.durationMinutes != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 12,
                          color: context.palette.textTertiary,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          '${lesson.durationMinutes} دقيقة',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 10,
                            color: context.palette.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The lecture's `thumbnail_url` filling the card's top, or a play/pdf/lock
/// icon over the primary gradient when there's none (or it fails to load).
class _LectureThumbnail extends StatelessWidget {
  const _LectureThumbnail({required this.lesson});

  final SubjectLesson lesson;

  @override
  Widget build(BuildContext context) {
    final url = lesson.thumbnailUrl;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppRadius.lg),
      ),
      child: SizedBox(
        height: 90,
        width: double.infinity,
        child: (url == null || url.isEmpty)
            ? _fallback(context)
            : CachedNetworkImage(
                imageUrl: url,
                memCacheWidth:
                    (MediaQuery.sizeOf(context).width *
                            MediaQuery.devicePixelRatioOf(context))
                        .round(),
                fit: BoxFit.cover,
                placeholder: (context, url) => _fallback(context),
                errorWidget: (context, url, error) => _fallback(context),
              ),
      ),
    );
  }

  Widget _fallback(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            context.palette.primary,
            Theme.of(context).colorScheme.secondary,
          ],
        ),
      ),
      child: Center(
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: context.palette.onPrimary.withValues(alpha: 0.7),
            shape: BoxShape.circle,
          ),
          child: Icon(
            lesson.hasVideo
                ? Icons.play_arrow_rounded
                : lesson.hasPdf
                ? Icons.picture_as_pdf_rounded
                : Icons.lock_clock_rounded,
            color: context.palette.gold,
            size: 24,
          ),
        ),
      ),
    );
  }
}

class _InlineRetry extends StatelessWidget {
  const _InlineRetry({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'تعذر تحميل البيانات',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.palette.textSecondary,
            ),
          ),
        ),
        TextButton(onPressed: onRetry, child: const Text('إعادة المحاولة')),
      ],
    );
  }
}

/// "اتصل بنا": one number -> dialer straight away, several -> pick from a
/// bottom sheet, none (center or support settings) -> a clear message.
Future<void> _callCenter(
  BuildContext context,
  WidgetRef ref,
  List<String> centerPhones,
) async {
  final support = ref.read(appSettingsProvider).valueOrNull?.supportPhone;
  final phones = {
    ...centerPhones.map((p) => p.trim()).where((p) => p.isNotEmpty),
    if (support != null && support.trim().isNotEmpty) support.trim(),
  }.toList();

  Future<void> dial(String phone) =>
      launchUrlSafely(Uri(scheme: 'tel', path: phone.replaceAll(' ', '')));

  if (phones.isEmpty) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('لا توجد أرقام متاحة')));
    return;
  }
  if (phones.length == 1) {
    await dial(phones.first);
    return;
  }
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'اختر رقم للاتصال',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          for (final phone in phones)
            ListTile(
              leading: Icon(Icons.call_rounded, color: context.palette.success),
              title: Text(phone, textDirection: TextDirection.ltr),
              onTap: () {
                Navigator.of(sheetContext).pop();
                dial(phone);
              },
            ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    ),
  );
}
