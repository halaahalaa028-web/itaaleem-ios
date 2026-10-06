import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';

/// What to open: a URL (+ any headers a signed CDN URL needs) and, for
/// YouTube's video-only adaptive streams, a separate audio URL.
class PlaybackSource {
  const PlaybackSource({
    required this.url,
    this.headers = const {},
    this.audioUrl,
  });

  final String url;
  final Map<String, String> headers;
  final String? audioUrl;
}

/// Thrown by [PlayerSlot.open] when the source never became playable — the
/// message is media_kit's last error (or "timed out"), for
/// `classifyPlaybackError`.
class SourceOpenException implements Exception {
  const SourceOpenException(this.reason);

  final String reason;

  @override
  String toString() => 'SourceOpenException: $reason';
}

/// One media_kit [Player] with its [VideoController].
///
/// Quality switches never reopen the slot that is on screen: the new source
/// is opened (silent, paused) on a second slot rendered underneath, and only
/// once it has a frame, a duration and — for adaptive YouTube streams — its
/// audio track is it swapped in at the live position. Until then the old
/// quality keeps playing, and a failure just disposes the second slot.
class PlayerSlot {
  PlayerSlot() : player = Player() {
    controller = VideoController(
      player,
      configuration: VideoControllerConfiguration(
        // MediaTek GPUs render a black/garbled surface with hardware
        // acceleration on Android — keep software rendering there.
        enableHardwareAcceleration: !Platform.isAndroid,
      ),
    );
  }

  final Player player;
  late final VideoController controller;

  bool _disposed = false;
  bool get isDisposed => _disposed;

  /// Whether [open] has been called — a slot is opened once, never reused.
  bool opened = false;

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await player.dispose();
  }

  /// The surface for this slot. Keyed by the slot itself, so a slot rendered
  /// underneath (while preparing) keeps its element/texture when it moves on
  /// top after the swap.
  Widget buildVideo() => Video(
    key: ObjectKey(this),
    controller: controller,
    controls: NoVideoControls,
    fit: BoxFit.contain,
  );

  /// Opens [source] paused at [position] and resolves once it's really
  /// playable: first frame decoded, duration known and (adaptive YouTube) the
  /// external audio attached. [silent] keeps the volume at 0 — the caller
  /// restores it when the slot takes over.
  ///
  /// media_kit also reports transient libmpv log lines (a dropped TCP
  /// connection ffmpeg reconnects by itself) on `stream.error`, so an error
  /// only fails the open if the source still isn't ready [errorGrace] later.
  /// Throws [SourceOpenException] on failure or after [timeout].
  Future<void> open(
    PlaybackSource source, {
    Duration position = Duration.zero,
    double rate = 1,
    bool silent = false,
    Duration timeout = const Duration(seconds: 25),
    Duration errorGrace = const Duration(seconds: 4),
  }) async {
    opened = true;
    final done = Completer<void>();
    String? lastError;
    Timer? graceTimer;

    void fail(String reason) {
      if (!done.isCompleted) done.completeError(SourceOpenException(reason));
    }

    final errorSub = player.stream.error.listen((message) {
      lastError = message;
      graceTimer ??= Timer(errorGrace, () => fail(message));
    });
    final timeoutTimer = Timer(timeout, () => fail(lastError ?? 'timed out'));

    Future<void> run() async {
      if (silent) await player.setVolume(0);
      await player.open(
        Media(
          source.url,
          start: position > Duration.zero ? position : null,
          httpHeaders: source.headers.isEmpty ? null : source.headers,
        ),
        play: false,
      );
      if (source.audioUrl != null) {
        await player.setAudioTrack(AudioTrack.uri(source.audioUrl!));
      }
      if (rate != 1) await player.setRate(rate);
      await controller.waitUntilFirstFrameRendered;
      if (player.state.duration <= Duration.zero) {
        await player.stream.duration.firstWhere((d) => d > Duration.zero);
      }
      if (source.audioUrl != null && !_hasAudio(player.state.tracks)) {
        await player.stream.tracks.firstWhere(_hasAudio);
      }
    }

    run().then((_) {
      if (!done.isCompleted) done.complete();
    }, onError: (Object e) => fail(e.toString()));
    try {
      await done.future;
    } finally {
      timeoutTimer.cancel();
      graceTimer?.cancel();
      await errorSub.cancel();
    }
  }

  static bool _hasAudio(Tracks tracks) =>
      tracks.audio.any((t) => t.id != 'auto' && t.id != 'no');

  /// Lands this (prepared, paused) slot on [from]'s live position — seeking
  /// twice if the first seek took long enough for [from] to drift — and
  /// copies its volume. Doesn't start/stop anything; the caller then pauses
  /// [from] and plays this one.
  Future<void> syncTo(PlayerSlot from) async {
    var target = from.player.state.position;
    await player.seek(target);
    final drift = from.player.state.position - target;
    if (drift.abs() > const Duration(milliseconds: 800)) {
      target = from.player.state.position;
      await player.seek(target);
    }
    await player.setVolume(from.player.state.volume);
  }

  /// Resolves `true` once playback has visibly advanced past where it is now
  /// — the proof a freshly swapped-in slot really plays — or `false` after
  /// [timeout].
  Future<bool> waitUntilAdvancing({
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final start = player.state.position;
    try {
      await player.stream.position
          .firstWhere((p) => p > start + const Duration(milliseconds: 400))
          .timeout(timeout);
      return true;
    } catch (_) {
      return player.state.position > start + const Duration(milliseconds: 400);
    }
  }
}

/// Small non-blocking "loading this quality" pill shown over the video while a
/// switch is prepared in the background — the video stays visible and
/// interactive underneath.
class QualitySwitchIndicator extends StatelessWidget {
  const QualitySwitchIndicator({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      label: label,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: scheme.scrim.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: scheme.onPrimary,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: scheme.onPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
