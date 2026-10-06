import 'dart:async';
import 'dart:io' show HandshakeException, SocketException;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';

/// Why a video (or one quality of it) couldn't be played — drives both the
/// recovery strategy (an expired URL is re-requested silently) and the
/// message the student finally sees.
enum PlaybackFailure {
  /// No internet / connection dropped / DNS failure / timed out.
  network,

  /// The signed / YouTube stream URL was rejected (401/403/410) — almost
  /// always because it expired. Recovered by fetching a fresh URL.
  expired,

  /// The video (or this rendition) doesn't exist or can't be played at all.
  unavailable,

  /// Anything else — server error, decoder failure, unknown.
  server;

  /// The Arabic message shown in the error view / toast.
  String get message => switch (this) {
    PlaybackFailure.network => 'تأكد من الاتصال بالإنترنت',
    PlaybackFailure.expired => 'انتهت صلاحية رابط الفيديو، جرّب تاني',
    PlaybackFailure.unavailable => 'الفيديو ده مش متاح للتشغيل حالياً',
    PlaybackFailure.server => 'حصلت مشكلة، جرّب تاني',
  };
}

/// Best-effort classification of whatever a player/manifest call threw (or
/// the text media_kit put on `Player.stream.error`).
PlaybackFailure classifyPlaybackError(Object? error) {
  if (error is SocketException ||
      error is HandshakeException ||
      error is TimeoutException) {
    return PlaybackFailure.network;
  }
  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return PlaybackFailure.network;
      default:
        final status = error.response?.statusCode ?? 0;
        if (status == 401 || status == 403 || status == 410) {
          return PlaybackFailure.expired;
        }
        if (status == 404) return PlaybackFailure.unavailable;
        return PlaybackFailure.server;
    }
  }
  // libmpv's messages usually embed the URL, whose signature/query could
  // contain anything ("403", "expired", ...) — classify the words only.
  final text = error
      .toString()
      .replaceAll(RegExp(r'https?://\S+'), '')
      .toLowerCase();
  const networkHints = [
    'socketexception',
    'failed host lookup',
    'network is unreachable',
    'connection refused',
    'connection reset',
    'connection closed',
    'connection timed out',
    'clientexception',
    'timed out',
    'tcp:',
  ];
  if (networkHints.any(text.contains)) return PlaybackFailure.network;
  if (text.contains('403') ||
      text.contains('401') ||
      text.contains('410') ||
      text.contains('forbidden') ||
      text.contains('expired')) {
    return PlaybackFailure.expired;
  }
  if (text.contains('404') || text.contains('not found')) {
    return PlaybackFailure.unavailable;
  }
  return PlaybackFailure.server;
}

/// Whether the device has no network connection at all (unknown → `false`).
Future<bool> isDeviceOffline() async {
  try {
    final results = await Connectivity().checkConnectivity();
    return results.every((r) => r == ConnectivityResult.none);
  } catch (_) {
    return false;
  }
}

/// [classifyPlaybackError], except that a device with no connectivity at all
/// is always reported as [PlaybackFailure.network] — libmpv's error text for
/// "no internet" is rarely recognisable on its own.
Future<PlaybackFailure> diagnosePlaybackError(Object? error) async {
  if (await isDeviceOffline()) return PlaybackFailure.network;
  return classifyPlaybackError(error);
}
