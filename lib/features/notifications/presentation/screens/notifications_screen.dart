import 'package:itaaleem/app/router/app_router.dart';
import 'package:itaaleem/core/error/failure.dart';
import 'package:itaaleem/core/theme/app_radius.dart';
import 'package:itaaleem/core/widgets/app_card.dart';
import 'package:itaaleem/core/widgets/app_empty_state.dart';
import 'package:itaaleem/core/widgets/app_error_state.dart';
import 'package:itaaleem/core/widgets/app_shimmer.dart';
import 'package:itaaleem/core/widgets/app_toast.dart';
import 'package:itaaleem/features/auth/presentation/providers/auth_controller.dart';
import 'package:itaaleem/features/notifications/data/dummy_notifications.dart';
import 'package:itaaleem/features/notifications/domain/entities/app_notification.dart';
import 'package:itaaleem/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:flutter/material.dart';
import 'package:itaaleem/core/widgets/fade_slide_in.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:itaaleem/core/theme/app_palette.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';

const _tabs = <String, NotificationCategory?>{
  'الكل': null,
  'محاضرات': NotificationCategory.lecture,
  'امتحانات': NotificationCategory.exam,
  'إعلانات': NotificationCategory.announcement,
};

const _realTabs = <String, AppNotificationType?>{
  'الكل': null,
  'محاضرات': AppNotificationType.lecture,
  'امتحانات': AppNotificationType.exam,
  'إعلانات': AppNotificationType.announcement,
};

String _timeAgo(DateTime dateTime) {
  final diff = DateTime.now().difference(dateTime);
  if (diff.isNegative || diff.inMinutes < 1) return 'الآن';
  if (diff.inMinutes == 1) return 'منذ دقيقة';
  if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقائق';
  if (diff.inHours == 1) return 'منذ ساعة';
  if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعات';
  if (diff.inDays == 1) return 'أمس';
  if (diff.inDays < 7) return 'منذ ${diff.inDays} أيام';
  if (diff.inDays < 30) return 'منذ ${(diff.inDays / 7).floor()} أسبوع';
  return '${dateTime.year}/${dateTime.month}/${dateTime.day}';
}

IconData _iconFor(AppNotificationType type) => switch (type) {
  AppNotificationType.lecture => Icons.play_circle_fill_rounded,
  AppNotificationType.exam => Icons.edit_note_rounded,
  AppNotificationType.assignment => Icons.assignment_rounded,
  AppNotificationType.announcement => Icons.campaign_rounded,
  AppNotificationType.other => Icons.notifications_rounded,
};

Color _iconBackgroundFor(BuildContext context, AppNotificationType type) {
  final scheme = Theme.of(context).colorScheme;
  return switch (type) {
    AppNotificationType.lecture => scheme.primaryContainer,
    AppNotificationType.exam => scheme.tertiaryContainer,
    AppNotificationType.assignment => scheme.secondaryContainer,
    AppNotificationType.announcement => scheme.secondaryContainer,
    AppNotificationType.other => scheme.surfaceContainerHighest,
  };
}

Color _iconColorFor(BuildContext context, AppNotificationType type) {
  final scheme = Theme.of(context).colorScheme;
  return switch (type) {
    AppNotificationType.lecture => scheme.onPrimaryContainer,
    AppNotificationType.exam => scheme.onTertiaryContainer,
    AppNotificationType.assignment => scheme.onSecondaryContainer,
    AppNotificationType.announcement => scheme.onSecondaryContainer,
    AppNotificationType.other => scheme.primary,
  };
}

/// "الإشعارات" tab. A demo ("دخول تجريبي") session renders
/// [dummyNotifications] exactly as before; a real session loads
/// `GET /notifications` (merged with on-device push history).
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDemo = ref.watch(isDemoSessionProvider);
    final hasUnread =
        !isDemo &&
        (ref.watch(notificationsControllerProvider).valueOrNull?.unreadCount ??
                0) >
            0;
    final labels = isDemo ? _tabs.keys : _realTabs.keys;

    return DefaultTabController(
      length: labels.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الإشعارات'),
          actions: hasUnread
              ? [
                  TextButton(
                    onPressed: () async {
                      try {
                        await ref
                            .read(notificationsControllerProvider.notifier)
                            .markAllAsRead();
                        if (context.mounted) {
                          AppToast.showSuccess(context, 'تم تحديد الكل كمقروء');
                        }
                      } catch (e) {
                        if (context.mounted) {
                          AppToast.showError(context, failureOf(e).message);
                        }
                      }
                    },
                    child: const Text('تحديد الكل كمقروء'),
                  ),
                ]
              : null,
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [for (final label in labels) Tab(text: label)],
          ),
        ),
        body: isDemo
            ? TabBarView(
                children: [
                  for (final category in _tabs.values)
                    _DemoNotificationList(category: category),
                ],
              )
            : TabBarView(
                children: [
                  for (final type in _realTabs.values)
                    _RealNotificationList(type: type),
                ],
              ),
      ),
    );
  }
}

class _RealNotificationList extends ConsumerStatefulWidget {
  const _RealNotificationList({required this.type});

  final AppNotificationType? type;

  @override
  ConsumerState<_RealNotificationList> createState() =>
      _RealNotificationListState();
}

class _RealNotificationListState extends ConsumerState<_RealNotificationList> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final position = _scrollController.position;
    if (position.pixels < position.maxScrollExtent - 300) return;
    ref.read(notificationsControllerProvider.notifier).loadMore().catchError((
      Object e,
    ) {
      if (mounted) AppToast.showError(context, failureOf(e).message);
    });
  }

  Future<void> _refresh() async {
    try {
      await ref.read(notificationsControllerProvider.notifier).refresh();
    } catch (e) {
      if (mounted) AppToast.showError(context, failureOf(e).message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(notificationsControllerProvider);

    return notificationsAsync.when(
      skipLoadingOnRefresh: true,
      skipLoadingOnReload: true,
      loading: () => const _NotificationsShimmer(),
      error: (error, _) => AppErrorState(
        message: failureOf(error).message,
        onRetry: () => ref.invalidate(notificationsControllerProvider),
      ),
      data: (state) {
        final type = widget.type;
        final items = type == null
            ? state.items
            : state.items.where((n) => n.type == type).toList();
        return RefreshIndicator(
          onRefresh: _refresh,
          child: items.isEmpty
              ? LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: const Center(child: _EmptyState()),
                    ),
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(AppSpacing.base),
                  itemCount: items.length + (state.hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index >= items.length) {
                      return const _ShimmerCard();
                    }
                    final item = items[index];
                    return _CenteredWidth(
                      key: ValueKey(item.id),
                      child: FadeSlideIn.staggered(
                        index: index < 10 ? index : 0,
                        child: _RealNotificationCard(item: item),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}

/// Caps card width on tablets / landscape so lines stay readable.
class _CenteredWidth extends StatelessWidget {
  const _CenteredWidth({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: child,
      ),
    );
  }
}

class _NotificationsShimmer extends StatelessWidget {
  const _NotificationsShimmer();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.base),
      itemCount: 7,
      itemBuilder: (_, _) => const _ShimmerCard(),
    );
  }
}

class _ShimmerCard extends StatelessWidget {
  const _ShimmerCard();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.listItemSpacing),
      child: _CenteredWidth(
        child: AppShimmer(
          child: AppCard(
            padding: EdgeInsets.all(AppSpacing.cardPadding),
            child: Row(
              children: [
                ShimmerBlock(width: 40, height: 40, radius: 20),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerBlock(width: 160, height: 12),
                      SizedBox(height: AppSpacing.sm),
                      ShimmerBlock(height: 10),
                      SizedBox(height: AppSpacing.sm),
                      ShimmerBlock(width: 60, height: 8),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RealNotificationCard extends ConsumerWidget {
  const _RealNotificationCard({required this.item});

  final AppNotification item;

  /// Marks it read, then opens what it's about (if the app has a screen
  /// for it).
  void _open(BuildContext context, WidgetRef ref) {
    ref.read(notificationsControllerProvider.notifier).markAsRead(item.id);
    final id = item.targetId;
    switch (item.type) {
      case AppNotificationType.lecture when id != null:
        context.push('/lectures/$id');
      case AppNotificationType.exam when id != null:
        context.push('/exams/$id');
      case AppNotificationType.exam:
        context.push(examsPath);
      default:
        break;
    }
  }

  Future<bool> _delete(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(notificationsControllerProvider.notifier).delete(item.id);
      return true;
    } catch (_) {
      if (context.mounted) AppToast.showError(context, 'تعذّر حذف الإشعار');
      return false;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.listItemSpacing),
      child: Dismissible(
        key: ValueKey('dismiss-${item.id}'),
        direction: DismissDirection.endToStart,
        confirmDismiss: (_) => _delete(context, ref),
        background: Container(
          alignment: AlignmentDirectional.centerEnd,
          padding: const EdgeInsetsDirectional.only(end: AppSpacing.xl),
          decoration: BoxDecoration(
            color: scheme.errorContainer,
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: Icon(
            Icons.delete_outline_rounded,
            color: scheme.onErrorContainer,
          ),
        ),
        child: AppCard(
          padding: const EdgeInsets.all(AppSpacing.cardPadding),
          color: item.isRead
              ? null
              : scheme.primaryContainer.withValues(alpha: 0.35),
          borderColor: item.isRead
              ? null
              : scheme.primary.withValues(alpha: 0.3),
          onTap: () => _open(context, ref),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _iconBackgroundFor(context, item.type),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _iconFor(item.type),
                  size: 20,
                  color: _iconColorFor(context, item.type),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: item.isRead
                            ? FontWeight.w600
                            : FontWeight.w800,
                        color: scheme.onSurface,
                      ),
                    ),
                    if (item.body != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.body!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      _timeAgo(item.createdAt),
                      style: textTheme.labelSmall?.copyWith(
                        color: scheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              if (!item.isRead)
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsetsDirectional.only(start: 8, top: 4),
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DemoNotificationList extends StatelessWidget {
  const _DemoNotificationList({required this.category});

  final NotificationCategory? category;

  @override
  Widget build(BuildContext context) {
    final items = category == null
        ? dummyNotifications
        : dummyNotifications.where((n) => n.category == category).toList();

    if (items.isEmpty) {
      return const _EmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.base),
      itemCount: items.length,
      itemBuilder: (context, index) => KeyedSubtree(
        key: ValueKey(index),
        child: FadeSlideIn.staggered(
          index: index,
          child: _DemoNotificationCard(item: items[index]),
        ),
      ),
    );
  }
}

class _DemoNotificationCard extends StatelessWidget {
  const _DemoNotificationCard({required this.item});

  final DummyNotification item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.listItemSpacing),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        color: item.unread
            ? context.palette.primary.withValues(alpha: 0.03)
            : null,
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _iconBackgroundFor(context, switch (item.category) {
                  NotificationCategory.lecture => AppNotificationType.lecture,
                  NotificationCategory.exam => AppNotificationType.exam,
                  NotificationCategory.announcement =>
                    AppNotificationType.announcement,
                }),
                shape: BoxShape.circle,
              ),
              child: Icon(item.icon, size: 20, color: context.palette.primary),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    item.time,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11,
                      color: context.palette.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            if (item.unread)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsetsDirectional.only(start: 8),
                decoration: BoxDecoration(
                  color: context.palette.primary,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const AppEmptyState(
      icon: Icons.notifications_none_rounded,
      title: 'مفيش إشعارات',
      subtitle: 'هتلاقي هنا كل جديد عن المحاضرات والامتحانات',
    );
  }
}
