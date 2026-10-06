import 'dart:async';

import 'package:itaaleem/core/services/notification_history_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter/widgets.dart' show WidgetsFlutterBinding;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Runs in a separate isolate when a push arrives while the app is
/// backgrounded/killed, so it must re-initialize Firebase itself. The
/// system tray already shows the notification automatically for any
/// message carrying a `notification` payload — nothing else to do here
/// besides logging it to local history, but Firebase requires a registered
/// handler regardless.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await _saveMessageToHistory(message);
}

/// Persists a push to local history (`NotificationHistoryService`) so
/// [NotificationsScreen] has something to show — the backend has no
/// `GET /notifications` endpoint yet. Shared by the background isolate
/// handler above and [NotificationService.bootstrap]'s foreground/tap
/// listeners below, so every push the app's Dart code ever observes ends up
/// recorded exactly once (de-duped by `messageId` in
/// [NotificationHistoryService.add]).
///
/// Caveat inherent to FCM on Android: a "display" push (one with a
/// `notification` payload, no `data`) that arrives while the app is fully
/// terminated is shown by the OS straight from the system tray without
/// running any Dart code — it's only recorded here if/when the user taps
/// it (via `getInitialMessage`). Pushes with a `data` payload, or any push
/// received while the app is foregrounded/backgrounded (not killed), are
/// always recorded on arrival.
Future<void> _saveMessageToHistory(RemoteMessage message) async {
  final notification = message.notification;
  final title = notification?.title ?? message.data['title'] as String?;
  final body = notification?.body ?? message.data['body'] as String?;
  if (title == null || title.isEmpty) return;
  try {
    await NotificationHistoryService().add(
      PushNotificationRecord(
        id: message.messageId ?? DateTime.now().microsecondsSinceEpoch.toString(),
        title: title,
        body: body,
        receivedAt: message.sentTime ?? DateTime.now(),
      ),
    );
  } catch (e) {
    if (kDebugMode) {
      debugPrint('[NotificationService] failed to save push to history: $e');
    }
  }
}

/// Wraps Firebase Cloud Messaging setup and lookups. Every operation is
/// guarded so the app behaves identically whether or not
/// `android/app/google-services.json` has been configured yet — see
/// [bootstrap].
class NotificationService {
  /// Whether `Firebase.initializeApp()` has succeeded, i.e. whether
  /// `google-services.json` is present and valid. Checked before every FCM
  /// call instead of caching a local flag, since [Firebase.apps] is the
  /// actual source of truth for the (process-global) default app.
  static bool get isConfigured => Firebase.apps.isNotEmpty;

  /// Call once, before `runApp`. Safe to call even with no Firebase project
  /// configured yet — logs and returns quietly instead of throwing, so a
  /// missing `google-services.json` never breaks the app.
  static Future<void> bootstrap() => _ready ??= _bootstrap();

  static Future<void>? _ready;

  static Future<void> _bootstrap() async {
    try {
      await Firebase.initializeApp();
      if (kDebugMode) debugPrint('FIREBASE INIT: success');
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('FIREBASE INIT: fail');
        debugPrint('[NotificationService] Firebase init error: $e\n$stackTrace');
      }
      return;
    }

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    // Permission request + token registration are [FcmService]'s job now —
    // deferred until a real (non-demo) session exists (see `App`'s
    // `authControllerProvider` listener), not run unconditionally here at
    // cold start before that's even known.

    // Records every push the app's Dart code observes: arriving while
    // foregrounded, tapped open from the background, or (once) tapped open
    // from fully terminated — see [_saveMessageToHistory]'s doc for the one
    // case FCM never hands to Dart at all.
    FirebaseMessaging.onMessage.listen(_saveMessageToHistory);
    FirebaseMessaging.onMessageOpenedApp.listen(_saveMessageToHistory);
    // Not awaited: this only records a history entry, so it must not hold up
    // `runApp` (first frame) on a platform-channel round trip.
    unawaited(_recordInitialMessage());
  }

  static Future<void> _recordInitialMessage() async {
    try {
      final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) await _saveMessageToHistory(initialMessage);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[NotificationService] getInitialMessage failed: $e');
      }
    }
  }

  /// The device's current FCM registration token, sent as `fcm_token` on
  /// `POST /login` so the backend can target this device from the very
  /// first request — [FcmService] owns every other token touchpoint
  /// (refresh, re-registration at app start, deletion on logout). Returns
  /// `null` (never throws) if Firebase isn't configured or the lookup
  /// fails.
  Future<String?> getToken() async {
    try {
      await _ready;
    } catch (_) {}
    if (!isConfigured) return null;
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[NotificationService] getToken failed: $e');
      }
      return null;
    }
  }
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});
