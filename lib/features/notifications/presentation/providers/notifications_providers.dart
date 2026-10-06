import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:itaaleem/core/providers/cache_for.dart';
import 'package:itaaleem/core/services/notification_history_service.dart';
import 'package:itaaleem/features/notifications/data/datasources/notifications_remote_data_source.dart';
import 'package:itaaleem/features/notifications/data/models/app_notification_mapper.dart';
import 'package:itaaleem/features/notifications/domain/entities/app_notification.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Loaded notifications plus pagination bookkeeping.
class NotificationsState {
  const NotificationsState({
    required this.items,
    this.page = 1,
    this.hasMore = false,
    this.isLoadingMore = false,
  });

  final List<AppNotification> items;
  final int page;
  final bool hasMore;
  final bool isLoadingMore;

  int get unreadCount => items.where((n) => !n.isRead).length;

  NotificationsState copyWith({
    List<AppNotification>? items,
    int? page,
    bool? hasMore,
    bool? isLoadingMore,
  }) => NotificationsState(
    items: items ?? this.items,
    page: page ?? this.page,
    hasMore: hasMore ?? this.hasMore,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
  );
}

/// `GET /notifications` (paginated), merged with pushes recorded on-device
/// that the server list doesn't contain — so a push the student received
/// always shows up, even when the backend doesn't persist it. Mark-as-read /
/// delete are optimistic. Real accounts only — a demo session renders
/// `dummyNotifications` directly instead.
class NotificationsController
    extends AutoDisposeAsyncNotifier<NotificationsState> {
  NotificationsRemoteDataSource get _remote =>
      ref.read(notificationsRemoteDataSourceProvider);

  @override
  Future<NotificationsState> build() async {
    _listenForPushes();
    // Changes often, so only kept for a minute after leaving the screen.
    return ref.cached(_load, duration: const Duration(minutes: 1));
  }

  Future<NotificationsState> _load() async {
    final page = await _remote.getNotifications();
    final items = _merge(page.items, await _localItems());
    return NotificationsState(
      items: items,
      page: page.page,
      hasMore: page.hasMore,
    );
  }

  /// A push arriving while the list is open reloads it (and the badge).
  void _listenForPushes() {
    if (Firebase.apps.isEmpty) return;
    final sub = FirebaseMessaging.onMessage.listen((_) {
      // Give `NotificationService` a moment to save it to local history.
      Future<void>.delayed(const Duration(milliseconds: 500), () {
        ref.invalidate(remoteUnreadCountProvider);
        refresh();
      });
    });
    ref.onDispose(sub.cancel);
  }

  Future<List<AppNotification>> _localItems() async {
    try {
      final records = await ref
          .read(notificationHistoryServiceProvider)
          .getAll();
      return [
        for (final r in records)
          AppNotification(
            id: r.id,
            title: r.title,
            body: r.body,
            type: appNotificationTypeFrom('${r.title} ${r.body ?? ''}'),
            createdAt: r.receivedAt,
            // Already seen as a system notification.
            isRead: true,
            isLocal: true,
          ),
      ];
    } catch (_) {
      return const [];
    }
  }

  List<AppNotification> _merge(
    List<AppNotification> server,
    List<AppNotification> local,
  ) {
    final serverKeys = {for (final n in server) '${n.title}|${n.body}'};
    final extra = local.where(
      (n) => !serverKeys.contains('${n.title}|${n.body}'),
    );
    return [...server, ...extra]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Pull-to-refresh: reloads page 1, keeping the current list on screen.
  Future<void> refresh() async {
    final next = await AsyncValue.guard(_load);
    // A refresh failure with data already shown keeps that data.
    if (next.hasError && state.hasValue) {
      Error.throwWithStackTrace(next.error!, next.stackTrace!);
    }
    state = next;
    ref.invalidate(remoteUnreadCountProvider);
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.isLoadingMore) return;
    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final next = await _remote.getNotifications(page: current.page + 1);
      final seen = {for (final n in current.items) n.id};
      state = AsyncData(
        current.copyWith(
          items: [
            ...current.items,
            ...next.items.where((n) => !seen.contains(n.id)),
          ],
          page: next.page,
          hasMore: next.hasMore && next.items.isNotEmpty,
          isLoadingMore: false,
        ),
      );
    } catch (_) {
      state = AsyncData(current.copyWith(isLoadingMore: false));
      rethrow;
    }
  }

  Future<void> markAsRead(String id) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final index = current.items.indexWhere((n) => n.id == id);
    if (index == -1 || current.items[index].isRead) return;

    final updated = [...current.items];
    updated[index] = updated[index].copyWith(isRead: true);
    state = AsyncData(current.copyWith(items: updated));
    if (updated[index].isLocal) return;
    try {
      await _remote.markAsRead(id);
    } catch (_) {
      // Left optimistically read — a low-stakes flag; the next reload
      // reflects the server truth.
    }
    ref.invalidate(remoteUnreadCountProvider);
  }

  Future<void> markAllAsRead() async {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(
        items: [for (final n in current.items) n.copyWith(isRead: true)],
      ),
    );
    try {
      await _remote.markAllAsRead();
    } catch (_) {
      // Server refused: put back what was really unread, so the list and
      // badge don't lie.
      state = AsyncData(current);
      rethrow;
    } finally {
      ref.invalidate(remoteUnreadCountProvider);
    }
  }

  /// Removes optimistically; restores the item and rethrows on failure.
  Future<void> delete(String id) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final item = current.items.where((n) => n.id == id).firstOrNull;
    if (item == null) return;
    state = AsyncData(
      current.copyWith(items: current.items.where((n) => n.id != id).toList()),
    );
    try {
      if (item.isLocal) {
        await ref.read(notificationHistoryServiceProvider).remove(id);
      } else {
        await _remote.delete(id);
        ref.invalidate(remoteUnreadCountProvider);
      }
    } catch (_) {
      final latest = state.valueOrNull ?? current;
      state = AsyncData(
        latest.copyWith(
          items: [...latest.items, item]
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
        ),
      );
      rethrow;
    }
  }
}

final notificationsControllerProvider =
    AsyncNotifierProvider.autoDispose<
      NotificationsController,
      NotificationsState
    >(NotificationsController.new);

/// Alias matching the feature's documented name.
final notificationsProvider = notificationsControllerProvider;

/// `GET /notifications/unread-count` — a cheap count that doesn't need the
/// whole list loaded (the home badge reads this).
final remoteUnreadCountProvider = FutureProvider.autoDispose<int>((ref) {
  if (Firebase.apps.isNotEmpty) {
    // A new push bumps the badge without waiting for a screen revisit.
    final sub = FirebaseMessaging.onMessage.listen((_) => ref.invalidateSelf());
    ref.onDispose(sub.cancel);
  }
  return ref.cached(
    () => ref.read(notificationsRemoteDataSourceProvider).getUnreadCount(),
    duration: const Duration(minutes: 1),
  );
});

/// Drives the unread badge: the server's count (re-fetched after every
/// read / delete), falling back to counting the loaded list if that endpoint
/// isn't available.
final unreadNotificationsCountProvider = Provider.autoDispose<AsyncValue<int>>((
  ref,
) {
  final remote = ref.watch(remoteUnreadCountProvider);
  if (remote.hasValue) return remote;
  final list = ref.watch(notificationsControllerProvider);
  if (remote.hasError && list.hasValue) {
    return AsyncData(list.requireValue.unreadCount);
  }
  return remote;
});

/// Alias matching the feature's documented name.
final unreadCountProvider = unreadNotificationsCountProvider;
