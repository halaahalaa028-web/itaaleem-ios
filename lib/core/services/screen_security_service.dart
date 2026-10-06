import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter/services.dart';

/// A capture-related event reported by the native side.
enum SecurityEvent { screenRecordingStarted, screenRecordingStopped, screenshot }

/// Bridges to the native screen-protection code over one MethodChannel
/// (`MainActivity.kt` / `AppDelegate.swift`):
///
/// * Android — `FLAG_SECURE` (screenshots and recordings come out black).
/// * iOS — screenshots can't be blocked, so capture is *detected*:
///   `UIScreen.isCaptured` (recording / mirroring / AirPlay) and
///   `userDidTakeScreenshotNotification`, pushed back as
///   `onCaptureChanged(bool)` / `onScreenshot`.
///
/// [enable]/[disable] are reference-counted, so a protected screen pushed on
/// top of another one doesn't switch protection off for the screen below when
/// it is popped. On platforms without a native handler every call no-ops.
class ScreenSecurityService {
  ScreenSecurityService._();

  static const _channel = MethodChannel('com.itaaleem.app/screen_security');

  static int _secureCount = 0;
  static bool _listening = false;
  static bool _isCaptured = false;
  static final _events = StreamController<SecurityEvent>.broadcast();

  /// Capture events from the native side (iOS today).
  static Stream<SecurityEvent> get events {
    _ensureListening();
    return _events.stream;
  }

  /// Last known "screen is being recorded/mirrored" state (iOS).
  static bool get isCaptured => _isCaptured;

  static Future<void> enable() async {
    _ensureListening();
    _secureCount++;
    if (_secureCount == 1) await _invoke('enableSecure');
  }

  static Future<void> disable() async {
    if (_secureCount == 0) return;
    _secureCount--;
    if (_secureCount == 0) await _invoke('disableSecure');
  }

  /// Re-applies the flag (e.g. after the app returns from the background).
  static Future<void> reapply() async {
    if (_secureCount > 0) await _invoke('enableSecure');
  }

  /// Asks the native side whether the screen is being captured right now.
  static Future<bool> refreshCaptured() async {
    _ensureListening();
    try {
      final captured = await _channel.invokeMethod<bool>('isCaptured');
      _setCaptured(captured ?? false);
    } on MissingPluginException {
      // No native handler (Android has nothing to report: FLAG_SECURE).
    } on PlatformException catch (e) {
      if (kDebugMode) debugPrint('[ScreenSecurityService] isCaptured: $e');
    }
    return _isCaptured;
  }

  static void _ensureListening() {
    if (_listening) return;
    _listening = true;
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onCaptureChanged':
          _setCaptured(call.arguments == true);
        case 'onScreenshot':
          _log(SecurityEvent.screenshot);
          _events.add(SecurityEvent.screenshot);
      }
      return null;
    });
  }

  static void _setCaptured(bool captured) {
    if (captured == _isCaptured) return;
    _isCaptured = captured;
    final event = captured
        ? SecurityEvent.screenRecordingStarted
        : SecurityEvent.screenRecordingStopped;
    _log(event);
    _events.add(event);
  }

  /// Local log only — there is no security-events endpoint in the API yet.
  static void _log(SecurityEvent event) {
    if (kDebugMode) debugPrint('[ScreenSecurityService] event: ${event.name}');
  }

  static Future<void> _invoke(String method) async {
    try {
      await _channel.invokeMethod<void>(method);
      if (kDebugMode) {
        debugPrint('[ScreenSecurityService] $method: ok');
      }
    } on MissingPluginException catch (e) {
      // Platform has no native handler for this channel — nothing to do.
      if (kDebugMode) {
        debugPrint('[ScreenSecurityService] $method: no native handler ($e)');
      }
    } on PlatformException catch (e) {
      // Best-effort protection; failing to toggle it shouldn't crash playback.
      if (kDebugMode) {
        debugPrint('[ScreenSecurityService] $method: failed ($e)');
      }
    }
  }
}
