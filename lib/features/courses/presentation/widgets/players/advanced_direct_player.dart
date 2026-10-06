import 'package:itaaleem/core/services/screen_security_service.dart';
import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:itaaleem/core/widgets/app_toast.dart';
import 'package:itaaleem/features/courses/domain/entities/lecture_details.dart';
import 'package:itaaleem/features/courses/presentation/widgets/players/lecture_playback_handle.dart';
import 'package:itaaleem/features/courses/presentation/widgets/players/playback_failure.dart';
import 'package:itaaleem/features/courses/presentation/widgets/players/playback_progress_reporter.dart';
import 'package:itaaleem/features/courses/presentation/widgets/players/playback_quality_prefs.dart';
import 'package:itaaleem/features/courses/presentation/widgets/players/playback_speed_prefs.dart';
import 'package:itaaleem/features/courses/presentation/widgets/players/player_settings_sheet.dart';
import 'package:itaaleem/features/courses/presentation/widgets/players/player_slot.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';

/// "المشغل الأساسي" — media_kit-backed player for direct/HLS lecture video
/// URLs (`provider == 'private_server'`, and any other provider that hands
/// back a directly playable `video_url`, `.m3u8` included since libmpv plays
/// HLS the same as any other stream).
///
/// Quality comes from one of two places:
///  * [qualities] — separate signed URLs per rendition from
///    `GET /lectures/{id}/playback`. "تلقائي" is [videoUrl]; picking another
///    one opens it on a second [PlayerSlot] underneath while the current one
///    keeps playing, then swaps it in at the live position. A rendition that
///    won't open gets one retry with freshly signed URLs ([onRefreshSource]),
///    then the next lower one is tried; if nothing works the current one just
///    carries on and a toast says so.
///  * otherwise the source's own video tracks (HLS variants) — switched in
///    place by libmpv, verified, and reverted if playback doesn't resume.
/// Repeated stalls step an explicitly picked quality down automatically.
///
/// Also: playback speed, edge-to-edge brightness/volume drag gestures,
/// double-tap ±10s seek, horizontal drag-to-scrub, wakelock while mounted,
/// and fullscreen.
///
/// A stream that dies mid-playback (signed URL expired, connection dropped)
/// is brought back at the same position with a fresh URL. Only if opening
/// fails or recovery is impossible does [onError] fire (once), so the hosting
/// [LecturePlayerChooser] can show its error view.
class AdvancedDirectPlayer extends StatefulWidget {
  const AdvancedDirectPlayer({
    super.key,
    required this.videoUrl,
    required this.startAt,
    required this.onReady,
    required this.onEnded,
    required this.onFullscreenChanged,
    required this.onError,
    this.thumbnailUrl,
    this.headers = const {},
    this.qualities = const [],
    this.expiresAt,
    this.onRefreshSource,
    this.progressReporter,
  });

  final String videoUrl;
  final Duration startAt;
  final String? thumbnailUrl;
  final ValueChanged<LecturePlaybackHandle> onReady;
  final VoidCallback onEnded;
  final ValueChanged<bool> onFullscreenChanged;
  final ValueChanged<PlaybackFailure> onError;

  /// Extra headers a signed CDN URL may require (e.g. from
  /// `GET /lectures/{id}/playback`) — passed straight to media_kit's
  /// `Media(..., httpHeaders: ...)`.
  final Map<String, String> headers;

  /// Per-quality signed URLs offered by the server (may be empty).
  final List<PlaybackQuality> qualities;

  /// When the signed URLs stop working, if the server said — a switch close
  /// to it fetches fresh ones first.
  final DateTime? expiresAt;

  /// Fetches freshly signed URLs (`null` when there's nothing to refresh,
  /// e.g. a local offline copy or a demo URL).
  final Future<LecturePlaybackInfo?> Function()? onRefreshSource;

  /// Optional throttled progress reporter — when provided, this player
  /// reports playback position every 15s, on pause, on completion, and on
  /// dispose. Created by the hosting widget (which has access to Dio).
  final ProgressReporter? progressReporter;

  @override
  State<AdvancedDirectPlayer> createState() => _AdvancedDirectPlayerState();
}

enum _DragAxis { none, horizontal, vertical }

/// One server-provided rendition (or "تلقائي" = the main URL, height 0).
class _ServerQuality {
  const _ServerQuality({
    required this.label,
    required this.url,
    required this.height,
  });

  final String label;
  final String url;
  final int height;
}

class _AdvancedDirectPlayerState extends State<AdvancedDirectPlayer> {
  /// The slot on screen; [_pendingSlot] is a quality being prepared
  /// underneath; [_retiringSlot] the previous one right after a swap, kept
  /// until the new one has proven it plays.
  PlayerSlot _slot = PlayerSlot();
  PlayerSlot? _pendingSlot;
  PlayerSlot? _retiringSlot;
  Player get _player => _slot.player;

  final _handle = _MediaKitHandle();
  final _subscriptions = <StreamSubscription<Object?>>[];

  Duration _buffered = Duration.zero;
  bool _loading = true;
  bool _buffering = false;
  bool _isPlaying = false;
  bool _muted = false;
  double _playbackRate = 1;
  bool _isFullscreen = false;
  bool _showControls = true;
  Timer? _hideControlsTimer;
  bool _readyReported = false;
  bool _endedFired = false;
  bool _erroredOut = false;

  // Track-based quality (the source's own renditions).
  List<VideoTrack> _videoTracks = const [];
  VideoTrack? _currentVideoTrack;
  int? _savedQualityHeight;
  bool _qualityApplied = false;

  // Server-provided renditions — see AdvancedDirectPlayer.qualities.
  late String _mainUrl = widget.videoUrl;
  late Map<String, String> _headers = widget.headers;
  late DateTime? _expiresAt = widget.expiresAt;
  late List<_ServerQuality> _serverQualities = _parseQualities(
    widget.qualities,
  );
  String _currentSource = _autoLabel;

  /// Text of the small "loading" pill while a quality is prepared / a track
  /// switch is verified / a dead stream is brought back; `null` when idle.
  String? _switchingLabel;

  /// The picker label being switched to — marked in the settings sheet.
  String? _switchTarget;
  int _switchGen = 0;
  bool _recovering = false;
  Object? _lastFailure;

  final _stallTimes = <DateTime>[];
  DateTime _lastSeekAt = DateTime.fromMillisecondsSinceEpoch(0);

  /// "Playing but the position is frozen" watchdog — catches streams that die
  /// without a clear error (expired signed URL, dropped connection).
  Timer? _watchdog;
  Duration _watchPosition = Duration.zero;
  int _stalledTicks = 0;
  DateTime? _lastErrorAt;

  // Chains seek requests so a burst of drag/double-tap seeks runs
  // pause→seek→resume one at a time instead of overlapping — media_kit
  // doesn't flush the platform audio buffer on seek, so two in-flight seeks
  // is what causes the old and new audio to play at once.
  Future<void> _seekQueue = Future.value();

  // Vertical (brightness/volume) + horizontal (seek) drag gesture state.
  _DragAxis _dragAxis = _DragAxis.none;
  double _dragStartGlobalX = 0;
  double _dragStartGlobalY = 0;
  int _seekBaseSeconds = 0;
  double? _dragSeconds;
  double _brightnessAtDragStart = 0.5;
  double _volumeAtDragStart = 0.5;
  double _currentBrightness = 0.5;
  double _currentVolume = 0.5;
  bool _showBrightnessOverlay = false;
  bool _showVolumeOverlay = false;
  Timer? _overlayHideTimer;

  String? _seekBubbleText;
  Timer? _seekBubbleTimer;

  static const _autoLabel = 'تلقائي';
  static const _qualityUnavailableMessage = 'الجودة مش متاحة حالياً';

  /// Pauses (never resumes) when iOS screen recording / mirroring starts.
  StreamSubscription<SecurityEvent>? _captureEvents;

  @override
  void initState() {
    super.initState();
    _captureEvents = ScreenSecurityService.events.listen((event) {
      if (event == SecurityEvent.screenRecordingStarted && mounted) {
        _player.pause();
      }
    });
    if (kDebugMode) {
      debugPrint(
        '[AdvancedDirectPlayer] initState — mounting for ${widget.videoUrl}',
      );
    }
    WakelockPlus.enable();
    _initBrightnessAndVolume();
    _loadSavedSpeed();
    _bindStreams();
    _watchdog = Timer.periodic(const Duration(seconds: 2), (_) => _watch());
    _load();
    _scheduleAutoHide();
  }

  /// Valid renditions, tallest first, one per label.
  static List<_ServerQuality> _parseQualities(List<PlaybackQuality> raw) {
    final byLabel = <String, _ServerQuality>{};
    for (final q in raw) {
      final label = q.label.trim();
      if (label.isEmpty || q.url.isEmpty || label == _autoLabel) continue;
      final digits = RegExp(r'(\d{3,4})').firstMatch(label)?.group(1);
      byLabel[label] = _ServerQuality(
        label: label,
        url: q.url,
        height: int.tryParse(digits ?? '') ?? 0,
      );
    }
    return byLabel.values.toList()
      ..sort((a, b) => b.height.compareTo(a.height));
  }

  bool get _serverMode => _serverQualities.isNotEmpty;

  _ServerQuality? _serverQuality(String label) =>
      _serverQualities.where((q) => q.label == label).firstOrNull;

  PlaybackSource _sourceFor(String label) => PlaybackSource(
    url: _serverQuality(label)?.url ?? _mainUrl,
    headers: _headers,
  );

  /// Once tracks arrive, selects the one closest to the saved height.
  void _applyQualityPreference() {
    if (_serverMode || _qualityApplied || _savedQualityHeight == null) return;
    final height = _savedQualityHeight!;
    if (height <= 0) return; // 0 = "تلقائي" legacy
    final usable = _videoTracks
        .where((t) => t.id != 'auto' && t.id != 'no' && t.h != null && t.h! > 0)
        .toList();
    if (usable.isEmpty) return;
    _qualityApplied = true;
    // Find exact match or closest lower, then closest higher.
    usable.sort(
      (a, b) => (a.h! - height).abs().compareTo((b.h! - height).abs()),
    );
    final best = usable.first;
    if (kDebugMode) {
      debugPrint(
        '[AdvancedDirectPlayer] applying saved quality ${height}p → ${best.h}p',
      );
    }
    _player.setVideoTrack(best);
    PlaybackQualityPrefs.save(best.h!);
  }

  Future<void> _loadSavedSpeed() async {
    final saved = await PlaybackSpeedPrefs.load();
    if (!mounted || saved == _playbackRate) return;
    setState(() => _playbackRate = saved);
    _player.setRate(saved);
  }

  Future<void> _initBrightnessAndVolume() async {
    try {
      _currentBrightness = await ScreenBrightness.instance.application;
    } catch (_) {
      // Best-effort — gesture still works relative to a 0.5 baseline.
    }
    try {
      _currentVolume = await VolumeController.instance.getVolume();
    } catch (_) {}
    if (mounted) setState(() {});
  }

  /// (Re)subscribes to the slot on screen. [playing] seeds [_isPlaying] on a
  /// swap so the outgoing slot's pause isn't reported as the student's.
  void _bindStreams({bool? playing}) {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
    final player = _player;
    _isPlaying = playing ?? player.state.playing;
    _buffering = player.state.buffering;
    if (player.state.duration > Duration.zero) {
      _handle.duration = player.state.duration;
    }
    if (!_serverMode) {
      _videoTracks = player.state.tracks.video;
      _currentVideoTrack = player.state.track.video;
    }
    _subscriptions.addAll([
      player.stream.position.listen((position) {
        _handle.position = position;
        final dur = _handle.duration;
        if (dur != null && dur > Duration.zero) {
          widget.progressReporter?.onPositionChanged(position, dur);
        }
        if (mounted && _dragAxis != _DragAxis.horizontal) setState(() {});
      }),
      player.stream.buffer.listen((buffer) {
        if (mounted) setState(() => _buffered = buffer);
      }),
      player.stream.duration.listen((duration) {
        _handle.duration = duration > Duration.zero ? duration : null;
        if (mounted) setState(() {});
      }),
      player.stream.playing.listen((playing) {
        final wasPlaying = _isPlaying;
        _isPlaying = playing;
        if (wasPlaying && !playing) {
          _handle.onPause?.call();
          widget.progressReporter?.flush();
        }
        if (mounted) setState(() {});
      }),
      player.stream.buffering.listen((buffering) {
        if (mounted) setState(() => _buffering = buffering);
        if (buffering) _onStall();
      }),
      player.stream.completed.listen((completed) {
        if (!completed || _endedFired || _loading) return;
        // libmpv reports a stream that died mid-video (expired signed URL,
        // dropped connection) as "end of file" too — recover instead.
        final dur = _handle.duration;
        final nearEnd =
            dur == null || _handle.position >= dur - const Duration(seconds: 5);
        if (!nearEnd) {
          if (kDebugMode) {
            debugPrint('[AdvancedDirectPlayer] premature EOF — recovering');
          }
          _recover();
          return;
        }
        _endedFired = true;
        if (dur != null) widget.progressReporter?.reportCompleted(dur);
        widget.onEnded();
      }),
      player.stream.tracks.listen((tracks) {
        if (mounted && !_serverMode) {
          setState(() => _videoTracks = tracks.video);
          _applyQualityPreference();
        }
      }),
      player.stream.track.listen((track) {
        if (mounted) setState(() => _currentVideoTrack = track.video);
      }),
      player.stream.error.listen((message) {
        if (kDebugMode) {
          debugPrint('[AdvancedDirectPlayer] player error: $message');
        }
        // libmpv also reports transient, self-healing network hiccups here —
        // an error only shortens the watchdog's patience (see _watch).
        _lastErrorAt = DateTime.now();
        _lastFailure = message;
      }),
    ]);
  }

  /// Every 2s: if the slot on screen is meant to be playing but its position
  /// hasn't moved for 20s (6s after an error), bring it back — [_recover].
  void _watch() {
    if (!mounted ||
        _loading ||
        _erroredOut ||
        _recovering ||
        _switchingLabel != null) {
      _stalledTicks = 0;
      return;
    }
    final state = _player.state;
    if (!state.playing || state.completed || _dragAxis != _DragAxis.none) {
      _stalledTicks = 0;
      _watchPosition = state.position;
      return;
    }
    if (state.position != _watchPosition) {
      _watchPosition = state.position;
      _stalledTicks = 0;
      return;
    }
    _stalledTicks++;
    final errorAt = _lastErrorAt;
    final recentError =
        errorAt != null &&
        DateTime.now().difference(errorAt) < const Duration(seconds: 30);
    if (_stalledTicks >= (recentError ? 3 : 10)) {
      _stalledTicks = 0;
      _recover();
    }
  }

  /// Opens the remembered quality (server renditions: the closest saved
  /// height; track mode applies it once tracks arrive), falling back to the
  /// main URL. Gives each source 30s — no first frame by then (black screen,
  /// stalled stream) counts as a failure for [LecturePlayerChooser].
  Future<void> _load() async {
    _savedQualityHeight = await PlaybackQualityPrefs.load();
    if (!mounted) return;
    var label = _autoLabel;
    final saved = _savedQualityHeight;
    if (_serverMode && saved != null && saved > 0) {
      final sorted = [..._serverQualities]
        ..sort(
          (a, b) =>
              (a.height - saved).abs().compareTo((b.height - saved).abs()),
        );
      label = sorted.first.label;
    }
    var opened = await _openOnScreen(label);
    if (!opened && label != _autoLabel && mounted) {
      label = _autoLabel;
      opened = await _openOnScreen(label);
    }
    if (!mounted) return;
    if (!opened) {
      if (kDebugMode) {
        debugPrint(
          '[AdvancedDirectPlayer] failed to open ${widget.videoUrl}: '
          '$_lastFailure',
        );
      }
      _fail(_lastFailure);
      return;
    }
    _currentSource = label;
    setState(() => _loading = false);
    await _player.play();
    _applyQualityPreference();
    if (kDebugMode) {
      debugPrint(
        '[AdvancedDirectPlayer] loaded — controls now visible for ${widget.videoUrl}',
      );
    }
    if (!_readyReported && mounted) {
      _readyReported = true;
      widget.onReady(_handle);
    }
  }

  /// Opens [label]'s source on the slot on screen (behind the loading
  /// overlay) — on a fresh slot if an earlier attempt already used this one.
  Future<bool> _openOnScreen(String label) async {
    if (_slot.opened) {
      final old = _slot;
      setState(() => _slot = PlayerSlot());
      _bindStreams();
      old.dispose();
    }
    try {
      await _slot.open(
        _sourceFor(label),
        position: widget.startAt,
        rate: _playbackRate,
        timeout: const Duration(seconds: 30),
      );
      return true;
    } catch (e) {
      _lastFailure = e;
      return false;
    }
  }

  /// Hands off to [LecturePlayerChooser] (fresh URL / error view) — once.
  Future<void> _fail(Object? error) async {
    if (_erroredOut || !mounted) return;
    _erroredOut = true;
    _switchGen++;
    _discardPending();
    final kind = await diagnosePlaybackError(error);
    if (!mounted) return;
    // Leave fullscreen before handing off: onError swaps this player out, and
    // the parent would otherwise stay in its app-bar-less fullscreen layout —
    // a black screen with nothing to tap.
    if (_isFullscreen) _exitFullscreen();
    widget.onError(kind);
  }

  /// Fetches freshly signed URLs; `false` if there's no refresher or it
  /// failed (the old ones are kept).
  Future<bool> _refreshSource() async {
    final refresh = widget.onRefreshSource;
    if (refresh == null) return false;
    try {
      final info = await refresh();
      if (info == null || info.url.isEmpty) return false;
      _mainUrl = info.url;
      _headers = info.headers;
      _expiresAt = info.expiresAt;
      final qualities = _parseQualities(info.qualities);
      if (qualities.isNotEmpty || !_serverMode) _serverQualities = qualities;
      if (kDebugMode) debugPrint('[AdvancedDirectPlayer] signed URL refreshed');
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[AdvancedDirectPlayer] refresh failed: $e');
      return false;
    }
  }

  bool get _sourceExpiring {
    final expiresAt = _expiresAt;
    return expiresAt != null &&
        expiresAt.difference(DateTime.now()) < const Duration(minutes: 2);
  }

  /// [target], then every lower server rendition — when switching up only
  /// those still above the current one (it keeps playing anyway).
  List<String> _fallbackLabels(String target) {
    final targetHeight = _serverQuality(target)?.height;
    if (targetHeight == null) return [target]; // "تلقائي"
    final currentHeight = _serverQuality(_currentSource)?.height;
    final switchingUp = currentHeight != null && targetHeight > currentHeight;
    return [
      target,
      for (final q in _serverQualities)
        if (q.label != target &&
            q.label != _currentSource &&
            q.height < targetHeight &&
            (!switchingUp || q.height > currentHeight))
          q.label,
    ];
  }

  /// Opens the first of [labels] that works on a new, silent slot underneath
  /// the one on screen, at the live position. A failure gets one retry of
  /// the same rendition with freshly signed URLs (unless [refreshed]). `null`
  /// if nothing opened or a newer switch superseded this one ([gen]).
  Future<(PlayerSlot, String)?> _prepareWithFallback(
    List<String> labels,
    int gen, {
    bool refreshed = false,
  }) async {
    for (var i = 0; i < labels.length; i++) {
      if (!mounted || gen != _switchGen) return null;
      if (_sourceExpiring && !refreshed) {
        refreshed = true;
        await _refreshSource();
        if (!mounted || gen != _switchGen) return null;
      }
      final label = labels[i];
      if (label != _autoLabel && _serverQuality(label) == null) continue;
      final slot = PlayerSlot();
      setState(() => _pendingSlot = slot);
      try {
        await slot.open(
          _sourceFor(label),
          position: _handle.position,
          rate: _playbackRate,
          silent: true,
          timeout: const Duration(seconds: 20),
        );
        if (!mounted || gen != _switchGen) {
          _dropPending(slot);
          return null;
        }
        return (slot, label);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[AdvancedDirectPlayer] $label unavailable: $e');
        }
        _lastFailure = e;
        _dropPending(slot);
        if (!mounted || gen != _switchGen) return null;
        if (await isDeviceOffline()) return null;
        if (!refreshed) {
          refreshed = true;
          if (await _refreshSource()) i--; // same rendition, fresh URL
        }
      }
    }
    return null;
  }

  void _dropPending(PlayerSlot slot) {
    if (identical(_pendingSlot, slot) && mounted) {
      setState(() => _pendingSlot = null);
    }
    slot.dispose();
  }

  void _discardPending() {
    final pending = _pendingSlot;
    if (pending == null) return;
    _pendingSlot = null;
    pending.dispose();
  }

  /// Hands playback from the slot on screen to [next] (showing [label]) at
  /// the live position, speed and volume. When it was playing ([forcePlay]:
  /// or should be), the new one must visibly advance; if it doesn't, the old
  /// one takes back over when [canRevert] — `false` is returned either way.
  Future<bool> _swapTo(
    PlayerSlot next,
    String label, {
    required bool canRevert,
    bool forcePlay = false,
  }) async {
    final old = _slot;
    final previous = _currentSource;
    final wasPlaying = forcePlay || old.player.state.playing;
    await next.syncTo(old);
    if (!mounted || next.isDisposed) return false;
    setState(() {
      _pendingSlot = null;
      _retiringSlot = old;
      _slot = next;
      _currentSource = label;
      _switchingLabel = null;
      _switchTarget = null;
      _qualityApplied = false;
    });
    _bindStreams(playing: wasPlaying);
    await old.player.pause();
    if (wasPlaying) await next.player.play();
    final ok = !wasPlaying || await next.waitUntilAdvancing();
    if (!mounted) return false;
    if (ok || !canRevert || old.isDisposed) {
      _retiringSlot = null;
      old.dispose();
      return ok;
    }
    await old.syncTo(next);
    await next.player.pause();
    if (!mounted) return false;
    setState(() {
      _retiringSlot = null;
      _slot = old;
      _currentSource = previous;
    });
    _bindStreams(playing: true);
    await old.player.play();
    next.dispose();
    return false;
  }

  /// Server renditions: prepares [label] in the background (falling back
  /// through lower ones) while the current one keeps playing, then swaps it
  /// in. Only a choice that really landed is remembered (not [auto] ones).
  Future<void> _switchSource(String label, {bool auto = false}) async {
    if (_loading || _erroredOut || _recovering) return;
    if (label == _currentSource) {
      if (_switchingLabel != null) {
        _switchGen++;
        _discardPending();
        setState(() {
          _switchingLabel = null;
          _switchTarget = null;
        });
      }
      return;
    }
    final gen = ++_switchGen;
    _discardPending();
    setState(() {
      _switchingLabel = 'جاري تحميل $label...';
      _switchTarget = label;
    });
    try {
      final prepared = await _prepareWithFallback(_fallbackLabels(label), gen);
      if (!mounted || gen != _switchGen) {
        if (prepared != null) _dropPending(prepared.$1);
        return;
      }
      if (prepared == null) {
        setState(() {
          _switchingLabel = null;
          _switchTarget = null;
        });
        final offline = await isDeviceOffline();
        if (!mounted) return;
        AppToast.showError(
          context,
          offline
              ? PlaybackFailure.network.message
              : _qualityUnavailableMessage,
        );
        return;
      }
      final (slot, landed) = prepared;
      final ok = await _swapTo(slot, landed, canRevert: true);
      if (!mounted) return;
      if (!ok) {
        AppToast.showError(context, _qualityUnavailableMessage);
        return;
      }
      if (auto) {
        AppToast.showError(
          context,
          'الإنترنت ضعيف، تم تقليل الجودة إلى $landed',
        );
      } else if (landed == label) {
        await PlaybackQualityPrefs.save(_serverQuality(landed)?.height ?? 0);
      } else {
        AppToast.showError(
          context,
          'جودة $label مش متاحة حالياً، تم التشغيل بجودة $landed',
        );
      }
    } catch (e) {
      // Only reachable when torn down mid-switch (a player disposed under
      // an await).
      if (kDebugMode) debugPrint('[AdvancedDirectPlayer] switch aborted: $e');
      if (mounted && gen == _switchGen) {
        setState(() {
          _switchingLabel = null;
          _switchTarget = null;
        });
      }
    }
  }

  /// The stream on screen stopped (expired signed URL, dropped connection,
  /// premature EOF): with fresh URLs, brings the same quality — or the next
  /// lower one that works — back at the same position on a new slot. Only if
  /// nothing plays is [onError] fired.
  Future<void> _recover() async {
    if (_recovering || _loading || _erroredOut || !mounted) return;
    _recovering = true;
    final gen = ++_switchGen;
    _discardPending();
    setState(() {
      _switchingLabel = 'جاري إعادة الاتصال...';
      _switchTarget = null;
    });
    try {
      final refreshed = await _refreshSource();
      if (!mounted || gen != _switchGen) return;
      final current = _currentSource;
      final labels = [
        current,
        if (_serverMode)
          for (final q in _serverQualities)
            if (q.label != current &&
                q.height < (_serverQuality(current)?.height ?? 0))
              q.label,
      ];
      final prepared = await _prepareWithFallback(
        labels,
        gen,
        refreshed: refreshed,
      );
      if (!mounted || gen != _switchGen) {
        if (prepared != null) _dropPending(prepared.$1);
        return;
      }
      if (prepared != null) {
        final (slot, landed) = prepared;
        if (await _swapTo(slot, landed, canRevert: false, forcePlay: true)) {
          _applyQualityPreference();
          return;
        }
      }
      if (mounted) _fail(_lastFailure);
    } catch (e) {
      if (kDebugMode) debugPrint('[AdvancedDirectPlayer] recovery aborted: $e');
    } finally {
      _recovering = false;
      if (mounted && _switchingLabel != null && gen == _switchGen) {
        setState(() => _switchingLabel = null);
      }
    }
  }

  /// Three buffering stalls inside 90s while playing an explicitly picked
  /// quality mean the connection can't keep up: step one quality down.
  /// "تلقائي" is left to the source.
  void _onStall() {
    if (_loading || _erroredOut || _recovering || _switchingLabel != null) {
      return;
    }
    if (!_isPlaying || _handle.position < const Duration(seconds: 3)) return;
    final now = DateTime.now();
    if (now.difference(_lastSeekAt) < const Duration(seconds: 3)) return;
    _stallTimes
      ..add(now)
      ..removeWhere((t) => now.difference(t) > const Duration(seconds: 90));
    if (_stallTimes.length < 3) return;
    _stallTimes.clear();
    if (_serverMode) {
      final current = _serverQuality(_currentSource);
      if (current == null) return;
      final lower = _serverQualities
          .where((q) => q.height < current.height)
          .firstOrNull;
      if (lower != null) _switchSource(lower.label, auto: true);
      return;
    }
    final current = _currentVideoTrack;
    final currentHeight = current?.h;
    if (current == null || current.id == 'auto' || currentHeight == null) {
      return;
    }
    final lower =
        _videoTracks
            .where((t) => t.h != null && t.h! > 0 && t.h! < currentHeight)
            .toList()
          ..sort((a, b) => b.h!.compareTo(a.h!));
    if (lower.isNotEmpty) _setVideoTrack(lower.first, auto: true);
  }

  @override
  void dispose() {
    _captureEvents?.cancel();
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _watchdog?.cancel();
    _hideControlsTimer?.cancel();
    _overlayHideTimer?.cancel();
    _seekBubbleTimer?.cancel();
    // Flush progress before tearing down — fire-and-forget; dispose must
    // not block on network. Only flushed, not disposed: the reporter belongs
    // to the host, and a remount (fresh signed URL / retry) keeps using it.
    widget.progressReporter?.flush();
    // Always restore, so leaving can never strand the app in landscape.
    _restoreSystemChrome();
    WakelockPlus.disable();
    ScreenBrightness.instance.resetApplicationScreenBrightness().catchError(
      (_) {},
    );
    _switchGen++;
    _pendingSlot?.dispose();
    _retiringSlot?.dispose();
    _slot.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    _player.playOrPause();
    _bumpControls();
  }

  Future<void> _seekTo(Duration position) {
    final total = _handle.duration;
    var target = position;
    if (target < Duration.zero) target = Duration.zero;
    if (total != null && target > total) target = total;
    // Queue behind any seek already in flight rather than firing
    // concurrently — see _seekQueue.
    _seekQueue = _seekQueue.then((_) => _performSeek(target));
    return _seekQueue;
  }

  Future<void> _performSeek(Duration target) async {
    if (!mounted) return;
    _lastSeekAt = DateTime.now();
    final player = _player;
    final wasPlaying = _isPlaying;
    await player.pause();
    await player.seek(target);
    if (wasPlaying && mounted && identical(player, _player)) {
      await player.play();
    }
  }

  void _seekBy(Duration delta) {
    _seekTo(_handle.position + delta);
    _bumpControls();
  }

  void _toggleMute() {
    setState(() => _muted = !_muted);
    _player.setVolume(_muted ? 0 : 100);
    _bumpControls();
  }

  void _setPlaybackRate(double rate) {
    setState(() => _playbackRate = rate);
    _player.setRate(rate);
    _pendingSlot?.player.setRate(rate);
    PlaybackSpeedPrefs.save(rate);
    _bumpControls();
  }

  /// Track mode: libmpv switches the rendition in place. If playback doesn't
  /// resume within 15s, the previous track comes back and a toast says so.
  /// The choice is remembered only once it worked (and not for [auto]).
  Future<void> _setVideoTrack(VideoTrack track, {bool auto = false}) async {
    if (_loading || _erroredOut || _recovering) return;
    final previous = _currentVideoTrack ?? VideoTrack.auto();
    _bumpControls();
    if (previous.id == track.id) return;
    final label = _trackLabel(track);
    final gen = ++_switchGen;
    setState(() {
      _switchingLabel = 'جاري تحميل $label...';
      _switchTarget = label;
    });
    final wasPlaying = _player.state.playing;
    try {
      await _player.setVideoTrack(track);
      final ok =
          !wasPlaying ||
          await _slot.waitUntilAdvancing(timeout: const Duration(seconds: 15));
      if (!mounted || gen != _switchGen) return;
      setState(() {
        _switchingLabel = null;
        _switchTarget = null;
      });
      if (ok) {
        if (auto) {
          AppToast.showError(
            context,
            'الإنترنت ضعيف، تم تقليل الجودة إلى $label',
          );
        } else if (track.h != null && track.h! > 0) {
          // Persist the student's manual quality choice for next time.
          await PlaybackQualityPrefs.save(track.h!);
        } else if (track.id == 'auto') {
          await PlaybackQualityPrefs.save(0); // 0 = "تلقائي"
        }
        return;
      }
      await _player.setVideoTrack(previous);
      if (mounted) AppToast.showError(context, _qualityUnavailableMessage);
    } catch (e) {
      if (kDebugMode) debugPrint('[AdvancedDirectPlayer] track switch: $e');
      if (mounted && gen == _switchGen) {
        setState(() {
          _switchingLabel = null;
          _switchTarget = null;
        });
      }
    }
  }

  void _enterFullscreen() {
    setState(() => _isFullscreen = true);
    widget.onFullscreenChanged(true);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _exitFullscreen() {
    setState(() => _isFullscreen = false);
    widget.onFullscreenChanged(false);
    _restoreSystemChrome();
  }

  void _restoreSystemChrome() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  void _toggleFullscreen() {
    _isFullscreen ? _exitFullscreen() : _enterFullscreen();
  }

  void _bumpControls() {
    setState(() => _showControls = true);
    _scheduleAutoHide();
  }

  void _toggleControlsVisibility() {
    if (_showControls) {
      _hideControlsTimer?.cancel();
      setState(() => _showControls = false);
    } else {
      _bumpControls();
    }
  }

  void _scheduleAutoHide() {
    _hideControlsTimer?.cancel();
    // Unconditional — gating this on _isPlaying left the controls stuck
    // visible forever whenever the auto-hide timer landed while playback
    // was still buffering (same bug fixed in YoutubeMediaKitPlayer).
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _flashSeekBubble(String text) {
    _seekBubbleTimer?.cancel();
    setState(() => _seekBubbleText = text);
    _seekBubbleTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _seekBubbleText = null);
    });
  }

  void _hideOverlaysSoon() {
    _overlayHideTimer?.cancel();
    _overlayHideTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _showBrightnessOverlay = false;
          _showVolumeOverlay = false;
        });
      }
    });
  }

  // --- Gestures ---------------------------------------------------------

  void _onPanStart(DragStartDetails details) {
    _dragAxis = _DragAxis.none;
    _dragStartGlobalX = details.globalPosition.dx;
    _dragStartGlobalY = details.globalPosition.dy;
    _brightnessAtDragStart = _currentBrightness;
    _volumeAtDragStart = _currentVolume;
    _seekBaseSeconds = _handle.position.inSeconds;
  }

  void _onPanUpdate(DragUpdateDetails details, BoxConstraints constraints) {
    final dx = details.globalPosition.dx - _dragStartGlobalX;
    final dy = details.globalPosition.dy - _dragStartGlobalY;

    if (_dragAxis == _DragAxis.none) {
      if (dx.abs() < 12 && dy.abs() < 12) return;
      _dragAxis = dx.abs() > dy.abs()
          ? _DragAxis.horizontal
          : _DragAxis.vertical;
    }

    if (_dragAxis == _DragAxis.horizontal) {
      final totalSeconds = _handle.duration?.inSeconds ?? 0;
      final secondsPerPixel = totalSeconds > 0
          ? (totalSeconds / constraints.maxWidth).clamp(0.05, 2.0)
          : 0.3;
      var target = _seekBaseSeconds + dx * secondsPerPixel;
      if (target < 0) target = 0;
      if (totalSeconds > 0 && target > totalSeconds) {
        target = totalSeconds.toDouble();
      }
      setState(() => _dragSeconds = target);
    } else {
      final isLeftHalf = _dragStartGlobalX < constraints.maxWidth / 2;
      final fraction = -dy / constraints.maxHeight;
      final base = isLeftHalf ? _brightnessAtDragStart : _volumeAtDragStart;
      final value = (base + fraction).clamp(0.0, 1.0);
      if (isLeftHalf) {
        setState(() {
          _currentBrightness = value;
          _showBrightnessOverlay = true;
          _showVolumeOverlay = false;
        });
        ScreenBrightness.instance
            .setApplicationScreenBrightness(value)
            .catchError((_) {});
      } else {
        setState(() {
          _currentVolume = value;
          _muted = value <= 0;
          _showVolumeOverlay = true;
          _showBrightnessOverlay = false;
        });
        VolumeController.instance.setVolume(value);
      }
    }
  }

  void _onPanEnd(DragEndDetails details) {
    if (_dragAxis == _DragAxis.horizontal && _dragSeconds != null) {
      _seekTo(Duration(seconds: _dragSeconds!.round()));
      setState(() => _dragSeconds = null);
    }
    _dragAxis = _DragAxis.none;
    _hideOverlaysSoon();
  }

  void _onDoubleTapDown(TapDownDetails details, double width) {
    final dx = details.localPosition.dx;
    if (dx < width / 3) {
      _seekBy(const Duration(seconds: -10));
      _flashSeekBubble('- 10 ثواني');
    } else if (dx > width * 2 / 3) {
      _seekBy(const Duration(seconds: 10));
      _flashSeekBubble('+ 10 ثواني');
    } else {
      _togglePlayPause();
    }
  }

  // --- Settings sheet (quality + speed) ------------------------------------

  /// Label for a [VideoTrack] in the settings sheet.
  static String _trackLabel(VideoTrack track) {
    if (track.id == 'auto') return _autoLabel;
    if (track.h != null && track.h! > 0) return '${track.h}p';
    return track.title?.isNotEmpty == true ? track.title! : track.id;
  }

  void _showSettingsSheet() {
    _hideControlsTimer?.cancel();
    if (_serverMode) {
      PlayerSettingsSheet.show(
        context,
        currentSpeed: _playbackRate,
        onSpeedChanged: _setPlaybackRate,
        qualities: [_autoLabel, for (final q in _serverQualities) q.label],
        currentQuality: _currentSource,
        pendingQuality: _switchTarget,
        onQualityChanged: _switchSource,
      ).whenComplete(_bumpControls);
      return;
    }
    // "تلقائي" always leads the list, even if the source only carries one
    // real rendition — the option should never disappear.
    final entries = <VideoTrack>[
      VideoTrack.auto(),
      ..._videoTracks.where((t) => t.id != 'auto' && t.id != 'no'),
    ];
    final current = _currentVideoTrack;
    PlayerSettingsSheet.show(
      context,
      currentSpeed: _playbackRate,
      onSpeedChanged: _setPlaybackRate,
      qualities: [for (final t in entries) _trackLabel(t)],
      currentQuality: current == null || current.id == 'auto'
          ? _autoLabel
          : _trackLabel(current),
      pendingQuality: _switchTarget,
      onQualityChanged: (label) {
        final track = entries.where((t) => _trackLabel(t) == label).firstOrNull;
        if (track != null) _setVideoTrack(track);
      },
      qualityNote: entries.length <= 1
          ? 'المصدر لا يوفر أكثر من جودة لهذا الفيديو'
          : null,
    ).whenComplete(_bumpControls);
  }

  @override
  Widget build(BuildContext context) {
    final player = ColoredBox(
      color: Colors.black,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            fit: StackFit.expand,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _toggleControlsVisibility,
                onDoubleTapDown: (details) =>
                    _onDoubleTapDown(details, constraints.maxWidth),
                onDoubleTap: () {},
                onPanStart: _onPanStart,
                onPanUpdate: (details) => _onPanUpdate(details, constraints),
                onPanEnd: _onPanEnd,
                // A quality being prepared sits underneath the one on
                // screen, so the swap is just a re-order — no black frame.
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_pendingSlot != null) _pendingSlot!.buildVideo(),
                    _slot.buildVideo(),
                  ],
                ),
              ),
              if (_loading) _buildLoading(),
              if (!_loading && _buffering)
                Center(
                  child: SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(
                      color: Theme.of(context).colorScheme.primary,
                      strokeWidth: 3,
                    ),
                  ),
                ),
              // A quality switch / reconnect never blocks the video — just a
              // small pill near the top while it loads in the background.
              if (!_loading && _switchingLabel != null)
                Align(
                  alignment: Alignment.topCenter,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.only(
                        top: AppSpacing.xxxl + AppSpacing.sm,
                      ),
                      child: IgnorePointer(
                        child: QualitySwitchIndicator(label: _switchingLabel!),
                      ),
                    ),
                  ),
                ),
              if (_seekBubbleText != null)
                Center(
                  child: _Bubble(
                    icon: _seekBubbleText!.startsWith('+')
                        ? Icons.fast_forward_rounded
                        : Icons.fast_rewind_rounded,
                    text: _seekBubbleText!,
                  ),
                ),
              if (_showBrightnessOverlay)
                Align(
                  alignment: Alignment.centerLeft,
                  child: _SideMeter(
                    icon: Icons.brightness_6_rounded,
                    value: _currentBrightness,
                  ),
                ),
              if (_showVolumeOverlay)
                Align(
                  alignment: Alignment.centerRight,
                  child: _SideMeter(
                    icon: _currentVolume <= 0
                        ? Icons.volume_off_rounded
                        : Icons.volume_up_rounded,
                    value: _currentVolume,
                  ),
                ),
              if (!_loading)
                AnimatedOpacity(
                  opacity: _showControls ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: IgnorePointer(
                    ignoring: !_showControls,
                    child: _Controls(
                      isPlaying: _isPlaying,
                      muted: _muted,
                      isFullscreen: _isFullscreen,
                      position: Duration(
                        seconds:
                            (_dragSeconds ??
                                    _handle.position.inSeconds.toDouble())
                                .round(),
                      ),
                      buffered: _buffered,
                      duration: _handle.duration,
                      onBack: () => Navigator.of(context).maybePop(),
                      onSeekBy: _seekBy,
                      onPlayPause: _togglePlayPause,
                      onMuteToggle: _toggleMute,
                      onSettingsTap: _showSettingsSheet,
                      onFullscreenTap: _toggleFullscreen,
                      onSeekChanged: (value) =>
                          setState(() => _dragSeconds = value),
                      onSeekEnd: (value) {
                        setState(() => _dragSeconds = null);
                        _seekTo(Duration(seconds: value.round()));
                      },
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );

    // Fullscreen: fill whatever space the parent (the full-screen Scaffold
    // body — see LecturePlayerScreen) actually gives, full stop. Forcing a
    // ratio here via MediaQuery.of(context).size was the bug: that reads
    // the *current* window size, which during the fullscreen transition is
    // often still the pre-rotation portrait size, squeezing the whole
    // Stack (video + controls) into a narrow vertical strip until
    // MediaQuery caught up. StackFit.expand above already makes the Stack
    // fill exactly the bounded constraints it's given — no ratio math
    // needed once nothing forces a specific one.
    // System back while fullscreen exits fullscreen first (a second back
    // then leaves the screen) instead of popping straight out of landscape.
    return PopScope(
      canPop: !_isFullscreen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _isFullscreen) _exitFullscreen();
      },
      child: _isFullscreen
          ? player
          : AspectRatio(aspectRatio: 16 / 9, child: player),
    );
  }

  Widget _buildLoading() {
    final thumbnail = widget.thumbnailUrl;
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (thumbnail != null && thumbnail.isNotEmpty)
            CachedNetworkImage(
              imageUrl: thumbnail,
              fit: BoxFit.cover,
              fadeInDuration: Duration.zero,
              placeholder: (context, url) => const SizedBox.shrink(),
              errorWidget: (context, url, error) => const SizedBox.shrink(),
            ),
          Center(
            child: CircularProgressIndicator(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaKitHandle extends LecturePlaybackHandle {
  @override
  Duration position = Duration.zero;

  @override
  Duration? duration;
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(40),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(width: AppSpacing.sm),
          Text(
            text,
            style: const TextStyle(
              fontFamily: 'Cairo',
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SideMeter extends StatelessWidget {
  const _SideMeter({required this.icon, required this.value});

  final IconData icon;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      width: 46,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(23),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 70,
            width: 4,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                FractionallySizedBox(
                  heightFactor: value.clamp(0, 1),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${(value.clamp(0, 1) * 100).round()}٪',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Round icon button for the center transport row. [filled] adds the
/// translucent dark disc behind the main play/pause button.
class _TransportButton extends StatelessWidget {
  const _TransportButton({
    required this.icon,
    required this.size,
    required this.onTap,
    this.filled = false,
  });

  final IconData icon;
  final double size;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      iconSize: size,
      padding: filled ? const EdgeInsets.all(AppSpacing.md) : null,
      style: IconButton.styleFrom(
        backgroundColor: filled ? Colors.black38 : Colors.transparent,
      ),
      icon: Icon(icon, color: Colors.white),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.isPlaying,
    required this.muted,
    required this.isFullscreen,
    required this.position,
    required this.buffered,
    required this.duration,
    required this.onBack,
    required this.onSeekBy,
    required this.onPlayPause,
    required this.onMuteToggle,
    required this.onSettingsTap,
    required this.onFullscreenTap,
    required this.onSeekChanged,
    required this.onSeekEnd,
  });

  final bool isPlaying;
  final bool muted;
  final bool isFullscreen;
  final Duration position;
  final Duration buffered;
  final Duration? duration;
  final VoidCallback onBack;
  final ValueChanged<Duration> onSeekBy;
  final VoidCallback onPlayPause;
  final VoidCallback onMuteToggle;
  final VoidCallback onSettingsTap;
  final VoidCallback onFullscreenTap;
  final ValueChanged<double> onSeekChanged;
  final ValueChanged<double> onSeekEnd;

  String _label(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final totalSeconds = duration?.inSeconds.toDouble() ?? 0;
    final maxSeconds = totalSeconds == 0 ? 1.0 : totalSeconds;
    final positionSeconds = position.inSeconds.toDouble().clamp(0, maxSeconds);
    final bufferedSeconds = buffered.inSeconds.toDouble().clamp(0, maxSeconds);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.45),
            Colors.transparent,
            Colors.transparent,
            Colors.black.withValues(alpha: 0.6),
          ],
        ),
      ),
      child: Stack(
        children: [
          PositionedDirectional(
            // Below the status bar / notch in fullscreen.
            top: MediaQuery.paddingOf(context).top + 4,
            start: 8,
            child: IconButton(
              icon: const Icon(
                Icons.arrow_back_rounded,
                color: Colors.white,
                size: 28,
              ),
              onPressed: onBack,
            ),
          ),
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              textDirection: TextDirection.ltr,
              children: [
                _TransportButton(
                  icon: Icons.replay_10_rounded,
                  size: 36,
                  onTap: () => onSeekBy(const Duration(seconds: -10)),
                ),
                const SizedBox(width: AppSpacing.xxl),
                _TransportButton(
                  icon: isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  size: 52,
                  onTap: onPlayPause,
                  filled: true,
                ),
                const SizedBox(width: AppSpacing.xxl),
                _TransportButton(
                  icon: Icons.forward_10_rounded,
                  size: 36,
                  onTap: () => onSeekBy(const Duration(seconds: 10)),
                ),
              ],
            ),
          ),
          PositionedDirectional(
            start: 8,
            end: 8,
            bottom: 4,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 7,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 14,
                    ),
                    activeTrackColor: scheme.primary,
                    secondaryActiveTrackColor: Colors.white38,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: scheme.primary,
                  ),
                  child: Slider(
                    min: 0,
                    max: maxSeconds,
                    value: positionSeconds.toDouble(),
                    secondaryTrackValue: bufferedSeconds.toDouble(),
                    onChanged: totalSeconds == 0 ? null : onSeekChanged,
                    onChangeEnd: totalSeconds == 0 ? null : onSeekEnd,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                  ),
                  child: Row(
                    children: [
                      Text(
                        _label(position),
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        duration != null
                            ? '-${_label(duration! > position ? duration! - position : Duration.zero)}'
                            : '--:--',
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      InkWell(
                        onTap: onMuteToggle,
                        child: Icon(
                          muted
                              ? Icons.volume_off_rounded
                              : Icons.volume_up_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.base),
                      InkWell(
                        onTap: onSettingsTap,
                        child: const Icon(
                          Icons.settings_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.base),
                      InkWell(
                        onTap: onFullscreenTap,
                        child: Icon(
                          isFullscreen
                              ? Icons.fullscreen_exit_rounded
                              : Icons.fullscreen_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ],
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
