/// A read-only window into "however this provider's player tracks
/// playback," so the screen hosting the player can run one shared 15-second
/// progress timer without knowing which concrete player produced it.
///
/// WebView-embedded providers (Bunny/Vimeo) have no JS bridge here, so their
/// handle only approximates position via elapsed wall-clock time — that's
/// the most that's available for those without a provider-specific
/// postMessage integration.
abstract class LecturePlaybackHandle {
  Duration get position;

  Duration? get duration;

  double get watchPercentage {
    final total = duration;
    if (total == null || total.inMilliseconds <= 0) return 0;
    final pct = position.inMilliseconds / total.inMilliseconds * 100;
    return pct.clamp(0, 100);
  }

  bool get isCompleted => watchPercentage >= 90;

  /// Set by the screen hosting the player (never by the player itself); the
  /// player calls this whenever playback pauses, so progress can be
  /// reported immediately instead of waiting for the next 15-second tick.
  /// Left null (never called) by players that can't detect pause — see the
  /// class doc above.
  void Function()? onPause;
}
