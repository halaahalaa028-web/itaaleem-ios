import 'package:itaaleem/core/services/screen_security_service.dart';
import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:itaaleem/features/courses/presentation/widgets/players/lecture_playback_handle.dart';
import 'package:itaaleem/features/courses/presentation/widgets/players/playback_failure.dart';
import 'package:itaaleem/features/courses/presentation/widgets/players/playback_progress_reporter.dart';
import 'package:itaaleem/features/courses/presentation/widgets/players/playback_quality_prefs.dart';
import 'package:itaaleem/features/courses/presentation/widgets/players/playback_speed_prefs.dart';
import 'package:itaaleem/features/courses/presentation/widgets/players/player_settings_sheet.dart';
import 'package:itaaleem/features/courses/presentation/widgets/players/player_slot.dart';
import 'package:itaaleem/core/utils/youtube_utils.dart';
import 'package:itaaleem/core/widgets/app_toast.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt_explode;
import 'package:itaaleem/core/theme/app_spacing.dart';

/// Chrome-free YouTube player: resolves a direct muxed (audio+video) stream
/// URL via [yt_explode.YoutubeExplode] and plays it through media_kit — no
/// iframe, no WebView, no YouTube branding, fully custom controls.
///
/// Quality: YouTube only ships ONE muxed stream (itag 18, 360p) and it is the
/// only one that reliably plays everywhere, so it is the default
/// ("الأساسية"). Everything higher (480p…2160p) exists only as video-only
/// adaptive streams; those are listed in the picker (only heights really in
/// the manifest) and play with the best AAC audio attached as an external
/// audio track.
///
/// Switching never interrupts playback: the new quality is opened on a
/// second [PlayerSlot] underneath while the current one keeps playing (a
/// small pill says what is loading), then swapped in at the live position.
/// If it won't open, a fresh manifest is fetched once (stream URLs expire /
/// get rejected), then each lower quality is tried; if nothing works the old
/// quality simply carries on and a toast says so. Repeated stalls step the
/// quality down automatically (never below "الأساسية"), and a stream that
/// dies mid-playback (expired URL, dropped connection) is brought back at
/// the same position with fresh URLs.
///
/// Tapping the video toggles a control overlay (auto-hides after 4s): a top
/// bar with back + title, a center play/pause with ±10s skip, and a bottom
/// seekbar with time, quality, speed and fullscreen. The left half of the
/// screen drags vertically for brightness, the right half for volume;
/// double-tapping either half seeks ±10s with a ripple; dragging horizontally
/// anywhere scrubs. Wakelock stays on while playing.
///
/// If stream resolution or playback fails for good (private/deleted video,
/// YouTube changing its extraction internals, no internet, ...) a clear
/// Arabic error with a retry button is shown; retrying resumes where the
/// student was.
class YoutubeMediaKitPlayer extends StatefulWidget {
  const YoutubeMediaKitPlayer({
    super.key,
    required this.rawIdOrUrl,
    required this.startAt,
    required this.title,
    required this.onReady,
    required this.onEnded,
    required this.onFullscreenChanged,
    this.thumbnailUrl,
    this.progressReporter,
    this.onFailed,
  });

  /// Called once playback has definitively failed — the host can then
  /// offer another player.
  final VoidCallback? onFailed;

  final String rawIdOrUrl;
  final Duration startAt;

  /// Shown in the overlay's top bar — the normal-layout header above the
  /// tabs disappears in fullscreen, so this is the only title the student
  /// sees once the video takes over the whole screen.
  final String title;

  final ValueChanged<LecturePlaybackHandle> onReady;
  final VoidCallback onEnded;
  final ValueChanged<bool> onFullscreenChanged;

  /// Poster shown behind the play button before the student starts playback.
  /// Falls back to YouTube's own default thumbnail for the resolved video id
  /// when the lecture didn't carry one.
  final String? thumbnailUrl;

  /// Reports watch progress (online or offline) so the student can resume.
  final ProgressReporter? progressReporter;

  @override
  State<YoutubeMediaKitPlayer> createState() => _YoutubeMediaKitPlayerState();
}

class _YoutubeMediaKitPlayerState extends State<YoutubeMediaKitPlayer>
    with TickerProviderStateMixin {
  /// The slot on screen. [_pendingSlot] is a quality being prepared
  /// underneath it; [_retiringSlot] the previous one, kept (paused) right
  /// after a swap until the new one has proven it plays.
  PlayerSlot _slot = PlayerSlot();
  PlayerSlot? _pendingSlot;
  PlayerSlot? _retiringSlot;
  Player get _player => _slot.player;

  final _handle = _MediaKitHandle();
  final _subscriptions = <StreamSubscription<Object?>>[];

  /// The video surface moves between `AspectRatio` (inline) and filling the
  /// screen (fullscreen). A `GlobalKey` lets Flutter re-parent it instead of
  /// unmounting/recreating the `Video` widget (which drops the texture and
  /// flashes black) on every fullscreen toggle.
  final _surfaceKey = GlobalKey();

  bool _failed = false;
  String? _failMessage;
  bool _started = false;

  /// One option per height the manifest really offers ("الأساسية" first).
  /// [_currentQuality] is `null` until the manifest has been resolved.
  List<_QualityOption> _qualities = const [];
  String? _currentQuality;
  _QualityOption? _muxedBase;
  _QualityOption? _lastChosen;
  DateTime? _manifestFetchedAt;

  /// "تلقائي": no quality pinned by the student — starts at the best height
  /// ≤ [_defaultHeight] and steps down on stalls / back up when smooth.
  bool _autoMode = true;
  DateTime _lastQualityChangeAt = DateTime.now();
  bool _refreshingInBackground = false;

  /// Text of the small "loading" pill while a quality is prepared in the
  /// background (or a dead stream is being brought back); `null` when idle.
  String? _switchingLabel;

  /// The picker label being switched to — marked in the settings sheet.
  String? _switchTarget;

  /// Bumped by every switch / recovery / retry; a superseded one drops
  /// whatever it prepared.
  int _switchGen = 0;
  bool _recovering = false;
  Object? _lastFailure;

  /// Buffering events while playing — three inside 90s step the quality
  /// down (see [_onStall]). Buffering right after a seek doesn't count.
  final _stallTimes = <DateTime>[];
  DateTime _lastSeekAt = DateTime.fromMillisecondsSinceEpoch(0);

  /// "Playing but the position is frozen" watchdog — catches streams that die
  /// without a clear error (expired URL mid-video, dropped connection).
  Timer? _watchdog;
  Duration _watchPosition = Duration.zero;
  int _stalledTicks = 0;
  DateTime? _lastErrorAt;

  bool _loading = true;

  /// True between a failed first attempt and the automatic next one — the
  /// loading overlay then reads "جاري إعادة المحاولة...".
  bool _retrying = false;
  bool _buffering = false;
  bool _isPlaying = false;
  double _playbackRate = 1;
  bool _isFullscreen = false;
  bool _showControls = false;
  double? _dragSeconds;
  Timer? _hideControlsTimer;
  bool _readyReported = false;
  bool _endedFired = false;

  // See AdvancedDirectPlayer._seekQueue — same media_kit seek-while-playing
  // double-audio issue, same pause→seek→resume, chained fix.
  Future<void> _seekQueue = Future.value();

  // Vertical (brightness/volume) + horizontal (seek) drag gesture state.
  bool _dragging = false;
  bool _draggingHorizontal = false;
  double _dragStartGlobalX = 0;
  double _dragStartGlobalY = 0;
  int _seekBaseSeconds = 0;
  double _brightnessAtDragStart = 0.5;
  double _volumeAtDragStart = 0.5;
  double _currentBrightness = 0.5;
  double _currentVolume = 0.5;
  bool _showBrightnessOverlay = false;
  bool _showVolumeOverlay = false;
  Timer? _overlayHideTimer;

  /// Which half the last double-tap seek landed on — drives the ripple.
  bool _rippleOnRight = true;

  Duration _bufferedPosition = Duration.zero;
  late final AnimationController _rippleController;

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
        '[YoutubeMediaKitPlayer] initState — mounting for ${widget.rawIdOrUrl}',
      );
    }
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _initBrightnessAndVolume();
    _bindStreams();
    _watchdog = Timer.periodic(const Duration(seconds: 2), (_) => _watch());
    // Starts right away — one tap on "فيديوهات المحاضرة" is enough: the
    // poster is only visible for the moment before the first frame builds,
    // then the loading spinner takes over until the stream is ready.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _startPlayback();
    });
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

  void _startPlayback() {
    if (_started) return;
    setState(() => _started = true);
    WakelockPlus.enable();
    _loadSavedSpeed();
    _load();
    // Controls stay hidden until the student explicitly taps the video —
    // see _showControls' default.
  }

  Future<void> _loadSavedSpeed() async {
    final saved = await PlaybackSpeedPrefs.load();
    if (!mounted || saved == _playbackRate) return;
    setState(() => _playbackRate = saved);
    _player.setRate(saved);
  }

  /// (Re)subscribes to the slot on screen. [playing] seeds [_isPlaying] — a
  /// swap passes the outgoing slot's state, so the new slot starting to play
  /// isn't mistaken for the student pressing play (which enters fullscreen).
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
    _subscriptions.addAll([
      player.stream.position.listen((position) {
        _handle.position = position;
        if (mounted && !_draggingHorizontal) setState(() {});
        widget.progressReporter?.onPositionChanged(
          position,
          _handle.duration ?? Duration.zero,
        );
      }),
      player.stream.buffer.listen((buffer) => _bufferedPosition = buffer),
      player.stream.duration.listen((duration) {
        _handle.duration = duration > Duration.zero ? duration : null;
        if (mounted) setState(() {});
      }),
      player.stream.playing.listen((playing) {
        if (kDebugMode) debugPrint('>>> YT PLAYING: $playing');
        final wasPlaying = _isPlaying;
        _isPlaying = playing;
        if (!wasPlaying && playing && !_isFullscreen && !_loading) {
          _enterFullscreen();
        }
        if (wasPlaying && !playing) _handle.onPause?.call();
        if (mounted) setState(() {});
      }),
      player.stream.buffering.listen((buffering) {
        if (kDebugMode) debugPrint('>>> YT BUFFERING: $buffering');
        if (mounted) setState(() => _buffering = buffering);
        if (buffering) _onStall();
      }),
      player.stream.completed.listen((completed) {
        if (!completed || _endedFired || _loading) return;
        // libmpv reports a stream that died mid-video (expired URL, dropped
        // connection) as "end of file" too — that's a recovery, not the end.
        final total = _handle.duration;
        final nearEnd =
            total == null ||
            _handle.position >= total - const Duration(seconds: 5);
        if (!nearEnd) {
          if (kDebugMode) debugPrint('>>> YT: premature EOF — recovering');
          _recover();
          return;
        }
        widget.progressReporter?.reportCompleted(total ?? Duration.zero);
        _endedFired = true;
        widget.onEnded();
      }),
      player.stream.error.listen((message) {
        if (kDebugMode) debugPrint('>>> YT PLAYER ERROR: $message');
        // Opening (initial load, a switch) handles its own errors; on the
        // stream on screen an error only shortens the watchdog's patience —
        // libmpv also reports transient, self-healing network hiccups here.
        _lastErrorAt = DateTime.now();
      }),
    ]);
  }

  /// Every 2s: if the slot on screen is meant to be playing but its position
  /// hasn't moved for 20s (6s after an error), bring it back — see
  /// [_recover].
  void _watch() {
    if (!mounted ||
        !_started ||
        _loading ||
        _failed ||
        _recovering ||
        _switchingLabel != null) {
      _stalledTicks = 0;
      return;
    }
    _maybeRefreshManifest();
    final state = _player.state;
    if (state.playing && !state.buffering) _maybeStepUp();
    if (!state.playing || state.completed || _draggingHorizontal) {
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

  /// Fetches the manifest and plays: the quality the student picked last
  /// time (if this video offers it), else "الأساسية". On failure waits
  /// [_retryDelay] and tries again with a fresh manifest, up to
  /// [_maxLoadRetries] times, before showing the error view. Resumes from
  /// the last known position on a retry.
  Future<void> _load({int attempt = 0}) async {
    final videoId = extractYouTubeId(widget.rawIdOrUrl);
    if (videoId == null) {
      if (kDebugMode) {
        debugPrint(
          '[YoutubeMediaKitPlayer] could not extract a video id from '
          '"${widget.rawIdOrUrl}" — showing the error view',
        );
      }
      _fail(message: PlaybackFailure.unavailable.message);
      return;
    }
    final startAt = _handle.position > Duration.zero
        ? _handle.position
        : widget.startAt;

    Object? failure;
    try {
      final options = await _fetchOptions(videoId);
      if (!mounted) return;
      if (options.isEmpty) {
        if (kDebugMode) {
          debugPrint('>>> YT: no playable stream available for $videoId');
        }
        _fail(message: PlaybackFailure.unavailable.message);
        return;
      }
      _applyOptions(options);

      // The student's saved height (picked earlier), else "تلقائي": the
      // best height ≤ 720p. Then every lower height, ending at the muxed
      // base — the most robust stream.
      final saved = await PlaybackQualityPrefs.loadYoutube();
      _autoMode = saved == null;
      final target = _initialOption(saved ?? _defaultHeight);
      final heights = target == null
          ? <int>[]
          : _fallbackHeights(target.height);
      final base = _muxedBase;
      if (base != null && !heights.contains(base.height)) {
        heights.add(base.height);
      }

      // This video's video+audio streams already failed this session:
      // skip them and open the muxed stream straight away.
      final skipAdaptive = _adaptiveFailedVideos.contains(videoId);
      if (skipAdaptive && kDebugMode) {
        debugPrint(
          '>>> YT: $videoId failed with video+audio earlier — going straight '
          'to muxed',
        );
      }

      _QualityOption? chosen;
      var adaptiveFailed = false;
      var refreshed = false;
      for (var i = 0; i < heights.length && mounted; i++) {
        final option = _optionAt(heights[i]);
        if (option == null) continue;
        // One failed video+audio attempt is enough — never walk down the
        // other adaptive heights (each would fail the same way, slowly).
        if (option.isAdaptive && (skipAdaptive || adaptiveFailed)) continue;
        final opened = await _openOnScreen(
          option,
          startAt,
          option.isAdaptive ? _adaptiveOpenTimeout : _baseOpenTimeout,
          errorGrace: option.isAdaptive
              ? const Duration(seconds: 1)
              : const Duration(seconds: 4),
        );
        if (opened) {
          chosen = option;
          break;
        }
        if (!mounted || await isDeviceOffline()) break;
        if (option.isAdaptive) {
          adaptiveFailed = true;
          _adaptiveFailedVideos.add(videoId);
          if (kDebugMode) {
            debugPrint('>>> YT: video+audio failed, falling back to muxed');
          }
          continue;
        }
        // The muxed stream itself failed (403 / expired signature): one
        // retry with a fresh manifest.
        if (!refreshed) {
          refreshed = true;
          if (await _refreshManifest()) i--;
        }
      }
      // Playing muxed because video+audio failed: quietly try another
      // InnerTube client's video+audio in the background and swap up if it
      // works (the muxed stream keeps playing meanwhile).
      if (chosen != null &&
          !chosen.isAdaptive &&
          (adaptiveFailed || skipAdaptive) &&
          target != null &&
          target.height > chosen.height) {
        unawaited(_upgradeViaAlternateClient(videoId, target.height));
      }
      if (chosen != null &&
          saved != null &&
          chosen.height != target?.height &&
          mounted) {
        AppToast.showError(
          context,
          'جودة ${saved}p مش متاحة حالياً، تم التشغيل بجودة ${chosen.label}',
        );
      }
      if (!mounted) return;
      if (chosen != null) {
        _lastChosen = chosen;
        _currentQuality = chosen.label;
        _lastQualityChangeAt = DateTime.now();
        if (kDebugMode) {
          debugPrint(
            '>>> YT: playing ${chosen.label} (${chosen.detail}), '
            '${chosen.isAdaptive ? 'video-only + external audio' : 'muxed'}',
          );
        }
        setState(() {
          _loading = false;
          _retrying = false;
        });
        await _player.play();
        if (!_readyReported && mounted) {
          _readyReported = true;
          widget.onReady(_handle);
        }
        return;
      }
      failure = _lastFailure;
    } catch (e, stackTrace) {
      if (kDebugMode) debugPrint('>>> YT: load failed = $e\n$stackTrace');
      failure = e;
    }

    if (!mounted || _failed) return;
    final kind = failure is yt_explode.VideoUnplayableException
        ? PlaybackFailure.unavailable
        : await diagnosePlaybackError(failure);
    if (!mounted) return;
    if (kind == PlaybackFailure.unavailable || attempt >= _maxLoadRetries) {
      _fail(message: kind.message);
      return;
    }
    if (kDebugMode) debugPrint('>>> YT: attempting retry ($kind)...');
    setState(() => _retrying = true);
    await Future<void>.delayed(_retryDelay);
    if (!mounted || _failed) return;
    await _load(attempt: attempt + 1);
  }

  /// Opens [option] on the slot on screen (behind the loading overlay) —
  /// on a fresh slot if an earlier attempt already used this one.
  Future<bool> _openOnScreen(
    _QualityOption option,
    Duration startAt,
    Duration timeout, {
    Duration errorGrace = const Duration(seconds: 4),
  }) async {
    if (_slot.opened) _replaceSlotOnScreen(PlayerSlot());
    try {
      await _slot.open(
        option.source,
        position: startAt,
        rate: _playbackRate,
        timeout: timeout,
        errorGrace: errorGrace,
      );
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('>>> YT: ${option.label} failed to open: $e');
      _lastFailure = e;
      return false;
    }
  }

  void _replaceSlotOnScreen(PlayerSlot slot) {
    final old = _slot;
    setState(() => _slot = slot);
    _bindStreams();
    old.dispose();
  }

  /// Fresh manifest → quality options. Stream URLs expire (and can be bound
  /// to the client that asked), so they are never reused across a retry.
  Future<List<_QualityOption>> _fetchOptions(
    String videoId, {
    List<yt_explode.YoutubeApiClient>? clients,
  }) async {
    final client = yt_explode.YoutubeExplode();
    try {
      Object? lastError;
      // One InnerTube client at a time, so we know whose User-Agent the
      // stream URLs are bound to.
      for (final ytClient in clients ?? _ytClients) {
        try {
          if (kDebugMode) {
            debugPrint(
              '>>> YT: fetching manifest for $videoId '
              '(${_clientName(ytClient)})',
            );
          }
          final manifest = await client.videos.streamsClient.getManifest(
            videoId,
            ytClients: [ytClient],
          );
          if (kDebugMode) _logManifest(manifest);
          final headers = {'User-Agent': _userAgentOf(ytClient)};
          final options = _qualityOptionsOf(manifest, headers);
          if (options.isEmpty) continue;
          _manifestFetchedAt = DateTime.now();
          return options;
        } on yt_explode.VideoUnplayableException {
          rethrow;
        } catch (e) {
          if (kDebugMode) {
            debugPrint('>>> YT: ${_clientName(ytClient)} manifest failed: $e');
          }
          lastError = e;
        }
      }
      if (lastError != null) throw lastError;
      return const [];
    } finally {
      client.close();
    }
  }

  /// After ANDROID's video+audio failed: fetches the manifest from other
  /// clients (TV, WEB/Safari) and, if one offers video+audio
  /// at or below [targetHeight], switches to it in the background. The
  /// muxed stream keeps playing; on failure nothing changes.
  Future<void> _upgradeViaAlternateClient(
    String videoId,
    int targetHeight,
  ) async {
    try {
      final options = await _fetchOptions(videoId, clients: _alternateClients);
      if (!mounted || _failed) return;
      final candidate = options
          .where((o) => o.isAdaptive && o.height <= targetHeight)
          .fold<_QualityOption?>(
            null,
            (best, o) => best == null || o.height > best.height ? o : best,
          );
      if (candidate == null) {
        if (kDebugMode) {
          debugPrint('>>> YT: no alternate-client video+audio — staying muxed');
        }
        return;
      }
      // Keep the working muxed stream(s); take the alternate adaptive ones.
      _applyOptions(
        [
          ..._qualities.where((o) => !o.isAdaptive),
          ...options.where((o) => o.isAdaptive),
        ]..sort((a, b) => a.height.compareTo(b.height)),
      );
      if (kDebugMode) {
        debugPrint(
          '>>> YT: trying alternate-client video+audio ${candidate.label}',
        );
      }
      await _switchQuality(candidate, auto: true);
      if (mounted && _lastChosen?.isAdaptive == true) {
        _adaptiveFailedVideos.remove(videoId);
        if (kDebugMode) {
          debugPrint('>>> YT: alternate-client video+audio works');
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('>>> YT: alternate-client upgrade failed: $e');
    }
  }

  void _applyOptions(List<_QualityOption> options) {
    _qualities = options;
    _muxedBase = options.where((o) => !o.isAdaptive).firstOrNull;
    // Same heights, fresh URLs — keep pointing at what's on screen.
    final current = _lastChosen;
    if (current != null) {
      _lastChosen = _optionAt(current.height) ?? current;
    }
  }

  /// Re-fetches the manifest; `false` if that failed (keeps the old one).
  Future<bool> _refreshManifest() async {
    final videoId = extractYouTubeId(widget.rawIdOrUrl);
    if (videoId == null) return false;
    try {
      final options = await _fetchOptions(videoId);
      if (options.isEmpty) return false;
      _applyOptions(options);
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('>>> YT: manifest refresh failed = $e');
      _lastFailure = e;
      return false;
    }
  }

  /// Whether the manifest's URLs are expired / about to — read from the
  /// `expire` query parameter YouTube signs into every stream URL, else by
  /// age (they last ~6h).
  bool get _manifestExpiring {
    final fetchedAt = _manifestFetchedAt;
    if (fetchedAt == null) return true;
    final url = _qualities.firstOrNull?.url;
    final expire = int.tryParse(
      (url == null ? null : Uri.tryParse(url)?.queryParameters['expire']) ?? '',
    );
    if (expire != null) {
      final expiresAt = DateTime.fromMillisecondsSinceEpoch(expire * 1000);
      return expiresAt.difference(DateTime.now()) < const Duration(minutes: 10);
    }
    return DateTime.now().difference(fetchedAt) > const Duration(hours: 5);
  }

  /// The tallest option ≤ [height]; if there's none, the shortest above it.
  _QualityOption? _initialOption(int height) {
    final sorted = [..._qualities]
      ..sort((a, b) => a.height.compareTo(b.height));
    return sorted.lastWhere(
      (o) => o.height <= height,
      orElse: () => sorted.firstWhere(
        (o) => o.height > height,
        orElse: () => sorted.last,
      ),
    );
  }

  _QualityOption? _optionAt(int height) =>
      _qualities.where((o) => o.height == height).firstOrNull;

  /// [target], then every lower height — but never below "الأساسية" unless
  /// [target] itself is, and (switching up) never down to [above] or lower:
  /// the current quality is still playing, so there's no point.
  List<int> _fallbackHeights(int target, {int? above}) {
    final baseHeight = _muxedBase?.height ?? 0;
    final floor = target >= baseHeight ? baseHeight : 0;
    final lower =
        _qualities
            .map((o) => o.height)
            .where(
              (h) => h < target && h >= floor && (above == null || h > above),
            )
            .toSet()
            .toList()
          ..sort((a, b) => b.compareTo(a));
    return [target, ...lower];
  }

  /// Opens the first of [_fallbackHeights] that works on a new, silent slot
  /// underneath the one on screen, at the live position. A failure gets one
  /// retry of the same height with a fresh manifest (unless [refreshed]),
  /// then moves on to the next lower height. `null` if nothing opened (or a
  /// newer switch superseded this one — [gen]).
  Future<_Prepared?> _prepareWithFallback(
    int targetHeight,
    int gen, {
    int? above,
    bool refreshed = false,
  }) async {
    final heights = _fallbackHeights(targetHeight, above: above);
    for (var i = 0; i < heights.length; i++) {
      if (!mounted || gen != _switchGen) return null;
      if (_manifestExpiring && !refreshed) {
        refreshed = true;
        await _refreshManifest();
        if (!mounted || gen != _switchGen) return null;
      }
      final option = _optionAt(heights[i]);
      if (option == null) continue;
      final slot = PlayerSlot();
      setState(() => _pendingSlot = slot);
      try {
        await slot.open(
          option.source,
          position: _handle.position,
          rate: _playbackRate,
          silent: true,
          timeout: _switchOpenTimeout,
        );
        if (!mounted || gen != _switchGen) {
          _dropPending(slot);
          return null;
        }
        return _Prepared(slot, option);
      } catch (e) {
        if (kDebugMode) debugPrint('>>> YT: ${option.label} unavailable: $e');
        _lastFailure = e;
        _dropPending(slot);
        if (!mounted || gen != _switchGen) return null;
        if (await isDeviceOffline()) return null;
        if (!refreshed) {
          refreshed = true;
          if (await _refreshManifest()) i--; // same height, fresh URLs
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

  /// Hands playback from the slot on screen to [prepared]'s at the live
  /// position, speed and volume ([forcePlay]: start playing even if the old
  /// one had stopped, e.g. at a premature EOF). When it was playing, the new one
  /// must visibly advance; if it doesn't, the old one (kept paused until
  /// then) takes back over when [canRevert] — `false` is returned either way.
  Future<bool> _swapTo(
    _Prepared prepared, {
    required bool canRevert,
    bool forcePlay = false,
  }) async {
    final old = _slot;
    final next = prepared.slot;
    final previous = _lastChosen;
    final wasPlaying = forcePlay || old.player.state.playing;
    await next.syncTo(old);
    if (!mounted || next.isDisposed) return false;
    setState(() {
      _pendingSlot = null;
      _retiringSlot = old;
      _slot = next;
      _lastChosen = prepared.option;
      _currentQuality = prepared.option.label;
      _switchingLabel = null;
      _switchTarget = null;
    });
    _bindStreams(playing: wasPlaying);
    await old.player.pause();
    if (wasPlaying) await next.player.play();
    final ok = !wasPlaying || await next.waitUntilAdvancing();
    if (!mounted) return false;
    if (ok || !canRevert || old.isDisposed || previous == null) {
      _retiringSlot = null;
      old.dispose();
      return ok;
    }
    if (kDebugMode) {
      debugPrint('>>> YT: ${prepared.option.label} stalled — reverting');
    }
    await old.syncTo(next);
    await next.player.pause();
    if (!mounted) return false;
    setState(() {
      _retiringSlot = null;
      _slot = old;
      _lastChosen = previous;
      _currentQuality = previous.label;
    });
    _bindStreams(playing: true);
    await old.player.play();
    next.dispose();
    return false;
  }

  /// Picker action (or [auto] step-down): prepares [option] in the
  /// background — falling back through lower qualities — while the current
  /// one keeps playing, then swaps it in. Only a choice that really landed
  /// on the requested height is remembered for next time.
  Future<void> _switchQuality(
    _QualityOption option, {
    bool auto = false,
  }) async {
    if (_failed || _loading || _recovering) return;
    if (option.label == _currentQuality) {
      // Tapping the quality already on screen cancels a switch in flight.
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
    final current = _lastChosen;
    final gen = ++_switchGen;
    _discardPending();
    setState(() {
      _switchingLabel = 'جاري تحميل ${option.label}...';
      _switchTarget = option.label;
    });
    try {
      final prepared = await _prepareWithFallback(
        option.height,
        gen,
        above: current != null && option.height > current.height
            ? current.height
            : null,
      );
      if (!mounted || gen != _switchGen) {
        if (prepared != null) _dropPending(prepared.slot);
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
      final ok = await _swapTo(prepared, canRevert: true);
      if (!mounted) return;
      if (!ok) {
        AppToast.showError(context, _qualityUnavailableMessage);
        return;
      }
      final landed = prepared.option;
      _lastQualityChangeAt = DateTime.now();
      if (auto) {
        if (landed.height < (current?.height ?? 0)) {
          AppToast.showError(
            context,
            'الإنترنت ضعيف، تم تقليل الجودة إلى ${landed.label}',
          );
        }
      } else if (landed.height == option.height) {
        // A quality picked by hand pins it (and is remembered); "تلقائي"
        // un-pins.
        if (!_autoMode) await PlaybackQualityPrefs.saveYoutube(landed.height);
      } else {
        AppToast.showError(
          context,
          'جودة ${option.label} مش متاحة حالياً، تم التشغيل بجودة ${landed.label}',
        );
      }
    } catch (e, stackTrace) {
      // Only reachable when the widget was torn down mid-switch (a player
      // disposed under an await) — nothing left to show.
      if (kDebugMode) debugPrint('>>> YT: switch aborted = $e\n$stackTrace');
      if (mounted && gen == _switchGen) {
        setState(() {
          _switchingLabel = null;
          _switchTarget = null;
        });
      }
    }
  }

  /// The stream on screen stopped (expired URL, dropped connection, premature
  /// EOF): with a fresh manifest, brings the same quality back — or the next
  /// lower one that works — at the same position on a new slot. Only if
  /// nothing plays is the error view shown.
  Future<void> _recover() async {
    final current = _lastChosen;
    if (current == null || _recovering || _failed || _loading || !mounted) {
      return;
    }
    _recovering = true;
    final gen = ++_switchGen;
    _discardPending();
    setState(() {
      _switchingLabel = 'جاري إعادة الاتصال...';
      _switchTarget = null;
    });
    try {
      final refreshed = await _refreshManifest();
      if (!mounted || gen != _switchGen) return;
      final prepared = await _prepareWithFallback(
        current.height,
        gen,
        refreshed: refreshed,
      );
      if (!mounted || gen != _switchGen) {
        if (prepared != null) _dropPending(prepared.slot);
        return;
      }
      if (prepared != null) {
        // The old slot is the one that died — it can't take back over.
        if (await _swapTo(prepared, canRevert: false, forcePlay: true)) {
          if (prepared.option.height < current.height && mounted) {
            AppToast.showError(
              context,
              'تم التبديل إلى ${prepared.option.label} بسبب ضعف الاتصال',
            );
          }
          return;
        }
      }
      final kind = await diagnosePlaybackError(_lastFailure);
      if (!mounted) return;
      _fail(message: kind.message);
    } catch (e) {
      if (kDebugMode) debugPrint('>>> YT: recovery aborted = $e');
    } finally {
      _recovering = false;
      if (mounted && _switchingLabel != null && gen == _switchGen) {
        setState(() => _switchingLabel = null);
      }
    }
  }

  /// Three buffering stalls inside 90s while playing mean the connection
  /// can't keep up: step one quality down (never below "الأساسية"). The
  /// student's saved choice is left alone.
  void _onStall() {
    if (_loading || _failed || _recovering || _switchingLabel != null) return;
    if (!_isPlaying || _handle.position < const Duration(seconds: 3)) return;
    final now = DateTime.now();
    if (now.difference(_lastSeekAt) < const Duration(seconds: 3)) return;
    final current = _lastChosen;
    final base = _muxedBase;
    if (current == null || base == null || current.height <= base.height) {
      return;
    }
    _stallTimes
      ..add(now)
      ..removeWhere((t) => now.difference(t) > const Duration(seconds: 60));
    if (_stallTimes.length < 3) return;
    // Keep the timestamps' effect on step-up (see [_maybeStepUp]) but reset
    // the count; a pinned quality stays pinned only until the network fails.
    _stallTimes
      ..clear()
      ..add(now);
    final lower = _qualities
        .where((q) => q.height < current.height && q.height >= base.height)
        .fold<_QualityOption?>(
          null,
          (best, q) => best == null || q.height > best.height ? q : best,
        );
    if (lower != null) _switchQuality(lower, auto: true);
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
    _rippleController.dispose();
    // Always — not only when we think we're fullscreen — so leaving the
    // video can never strand the app in landscape/immersive mode.
    _restoreSystemChrome();
    if (_started) WakelockPlus.disable();
    ScreenBrightness.instance.resetApplicationScreenBrightness().catchError(
      (_) {},
    );
    widget.progressReporter?.flush();
    _switchGen++;
    _pendingSlot?.dispose();
    _retiringSlot?.dispose();
    _slot.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    if (_isPlaying) widget.progressReporter?.flush();
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
  }

  /// Skip buttons in the center row: seek and keep the controls open.
  void _skipBy(Duration delta) {
    _seekBy(delta);
    _bumpControls();
  }

  void _setPlaybackRate(double rate) {
    setState(() => _playbackRate = rate);
    _player.setRate(rate);
    _pendingSlot?.player.setRate(rate);
    PlaybackSpeedPrefs.save(rate);
    _bumpControls();
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
    if (_isFullscreen) {
      _exitFullscreen();
    } else {
      _enterFullscreen();
    }
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
    // Unconditional — a stalled/buffering `_isPlaying` check here used to
    // leave the controls stuck visible forever, covering the video.
    _hideControlsTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      setState(() => _showControls = false);
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

  static const _retryDelay = Duration(seconds: 3);
  static const _maxLoadRetries = 2;

  /// How long each source gets to become playable: the muxed "الأساسية"
  /// on first load (slow connections) and a background switch (the current
  /// quality keeps playing meanwhile). Adaptive first loads: see
  /// [_adaptiveOpenTimeout].

  /// A video+audio (adaptive) open gets only this long before the muxed
  /// stream takes over — a broken adaptive stream usually errors at once
  /// (errorGrace 1s), this caps the "hangs silently" case.
  static const _adaptiveOpenTimeout = Duration(seconds: 5);

  /// Videos whose video+audio streams failed this session (in memory only):
  /// they open muxed straight away next time.
  static final _adaptiveFailedVideos = <String>{};

  /// Tried in the background when ANDROID's video+audio fails.
  static final _alternateClients = <yt_explode.YoutubeApiClient>[
    yt_explode.YoutubeApiClient.tv,
    yt_explode.YoutubeApiClient.safari,
  ];
  static const _baseOpenTimeout = Duration(seconds: 45);
  static const _switchOpenTimeout = Duration(seconds: 20);

  /// InnerTube clients tried in order. `androidSdkless` serves every
  /// adaptive height without a PO token; the others are fallbacks.
  static final _ytClients = <yt_explode.YoutubeApiClient>[
    yt_explode.YoutubeApiClient.androidSdkless,
    yt_explode.YoutubeApiClient.androidVr,
    yt_explode.YoutubeApiClient.ios,
    yt_explode.YoutubeApiClient.tv,
  ];

  static Map<String, dynamic>? _clientContext(
    yt_explode.YoutubeApiClient client,
  ) {
    final context = client.payload['context'];
    final inner = context is Map ? context['client'] : null;
    return inner is Map ? Map<String, dynamic>.from(inner) : null;
  }

  static String _clientName(yt_explode.YoutubeApiClient client) =>
      _clientContext(client)?['clientName']?.toString() ?? '?';

  /// The UA the stream URLs must be fetched with — the client's own.
  static String _userAgentOf(yt_explode.YoutubeApiClient client) {
    final context = _clientContext(client);
    final ua = context?['userAgent']?.toString();
    if (ua != null && ua.isNotEmpty) return ua;
    final version = context?['clientVersion'] ?? '1.56.21';
    return switch (_clientName(client)) {
      'ANDROID_VR' =>
        'com.google.android.apps.youtube.vr.oculus/$version '
            '(Linux; U; Android 12L; eureka-user Build/SQ3A.220605.009.A1) gzip',
      _ =>
        'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
    };
  }

  /// Default ceiling for "تلقائي": the best height ≤ 720p (1080p costs too
  /// much data on typical mobile connections; still one tap away).
  static const _defaultHeight = 720;
  static const _autoLabel = 'تلقائي';

  void _fail({String? message}) {
    if (_failed || !mounted) return;
    _switchGen++;
    _discardPending();
    _player.pause();
    // Leave fullscreen first: an error shown in landscape/immersive mode with
    // the app bar hidden left a black screen with nothing to tap.
    if (_isFullscreen) _exitFullscreen();
    setState(() {
      _failed = true;
      _retrying = false;
      _switchingLabel = null;
      _switchTarget = null;
      _failMessage = message;
    });
    widget.onFailed?.call();
  }

  /// Fetches a brand-new manifest (see [_load]) and resumes where the student
  /// was — never replays the old, possibly expired, URL.
  Future<void> _retry() async {
    _endedFired = false;
    _failMessage = null;
    _lastErrorAt = null;
    setState(() {
      _failed = false;
      _started = true;
      _loading = true;
      _retrying = false;
    });
    _load();
  }

  /// Dumps every format YouTube returned (no URLs — they carry signatures).
  void _logManifest(yt_explode.StreamManifest manifest) {
    debugPrint(
      '>>> YT formats: muxed=${manifest.muxed.length} '
      'videoOnly=${manifest.videoOnly.length} '
      'audioOnly=${manifest.audioOnly.length} hls=${manifest.hls.length}',
    );
    for (final stream in manifest.streams) {
      final kind = stream is yt_explode.MuxedStreamInfo
          ? 'muxed'
          : stream is yt_explode.VideoOnlyStreamInfo
          ? 'video-only'
          : stream is yt_explode.AudioOnlyStreamInfo
          ? 'audio-only'
          : stream.runtimeType.toString();
      final video = stream is yt_explode.VideoStreamInfo
          ? '${stream.videoResolution.height}p'
                '${stream.framerate.framesPerSecond.round()} ${stream.videoCodec}'
          : '';
      final audio = stream is yt_explode.AudioStreamInfo
          ? stream.audioCodec
          : '';
      debugPrint(
        '>>>   $kind itag=${stream.tag} ${stream.container.name} $video '
        '$audio ${(stream.bitrate.bitsPerSecond / 1000).round()}kbps',
      );
    }
  }

  /// Codec preference for video-only streams: H.264 decodes cheaply in
  /// software (Android runs without hardware acceleration here), VP9 next,
  /// AV1 last. 1440p/2160p only exist as VP9/AV1, so they still appear.
  static int _codecRank(String codec) {
    final c = codec.toLowerCase();
    if (c.startsWith('avc1')) return 3;
    if (c.startsWith('vp9') || c.startsWith('vp09')) return 2;
    return 1;
  }

  /// One option per distinct height: "الأساسية" (the tallest muxed stream)
  /// first, then every other height ascending. Only formats that are really
  /// in [manifest] are offered:
  ///  * the muxed stream(s) (audio included, most robust) at their heights;
  ///  * each other height from its best video-only stream, paired with the
  ///    best AAC audio-only stream.
  List<_QualityOption> _qualityOptionsOf(
    yt_explode.StreamManifest manifest,
    Map<String, String> headers,
  ) {
    final byHeight = <int, _QualityOption>{};

    final audioStreams = manifest.audioOnly.toList()
      ..sort((a, b) {
        final aac = (b.audioCodec.startsWith('mp4a') ? 1 : 0).compareTo(
          a.audioCodec.startsWith('mp4a') ? 1 : 0,
        );
        return aac != 0
            ? aac
            : b.bitrate.bitsPerSecond.compareTo(a.bitrate.bitsPerSecond);
      });
    final audio = audioStreams.firstOrNull;

    if (audio != null) {
      final best = <int, yt_explode.VideoOnlyStreamInfo>{};
      for (final stream in manifest.videoOnly) {
        final height = stream.videoResolution.height;
        final current = best[height];
        if (current == null) {
          best[height] = stream;
          continue;
        }
        final rank = _codecRank(
          stream.videoCodec,
        ).compareTo(_codecRank(current.videoCodec));
        if (rank > 0 ||
            (rank == 0 &&
                stream.bitrate.bitsPerSecond > current.bitrate.bitsPerSecond)) {
          best[height] = stream;
        }
      }
      for (final entry in best.entries) {
        final stream = entry.value;
        byHeight[entry.key] = _QualityOption(
          label: _labelFor(entry.key, stream.framerate.framesPerSecond),
          url: stream.url.toString(),
          audioUrl: audio.url.toString(),
          height: entry.key,
          headers: headers,
          detail:
              '${stream.container.name} ${stream.videoCodec} '
              '${stream.framerate.framesPerSecond.round()}fps',
        );
      }
    }

    // Muxed streams win at their own height — a single URL with audio.
    for (final stream in manifest.muxed) {
      final height = stream.videoResolution.height;
      final existing = byHeight[height];
      if (existing != null && !existing.isAdaptive) continue;
      byHeight[height] = _QualityOption(
        label: _labelFor(height, stream.framerate.framesPerSecond),
        url: stream.url.toString(),
        height: height,
        headers: headers,
        detail:
            '${stream.container.name} ${stream.videoCodec} '
            '${stream.framerate.framesPerSecond.round()}fps',
      );
    }

    final heights = byHeight.keys.toList()..sort();
    final muxed = [
      for (final h in heights)
        if (!byHeight[h]!.isAdaptive) byHeight[h]!,
    ];
    if (muxed.isEmpty) return [for (final h in heights) byHeight[h]!];
    // The tallest muxed stream is "الأساسية" and leads the list; every other
    // real height follows, ascending.
    final baseOption = muxed.last;
    return [
      baseOption.withLabel('الأساسية (${baseOption.height}p)'),
      for (final h in heights)
        if (byHeight[h] != baseOption) byHeight[h]!,
    ];
  }

  static String _labelFor(int height, num fps) =>
      fps > 30 ? '${height}p${fps.round()}' : '${height}p';

  static const _qualityUnavailableMessage = 'الجودة مش متاحة حالياً';

  /// "تلقائي (720p)" while adaptive mode drives the quality.
  String get _autoEntryLabel {
    final h = _lastChosen?.height;
    return _autoMode && h != null ? '$_autoLabel (${h}p)' : _autoLabel;
  }

  Future<void> _enableAutoMode() async {
    if (_autoMode) return;
    setState(() => _autoMode = true);
    await PlaybackQualityPrefs.clearYoutube();
    final target = _initialOption(_defaultHeight);
    if (target != null && mounted && target.label != _currentQuality) {
      _switchQuality(target, auto: true);
    }
  }

  /// Adaptive step-up: in "تلقائي", after 2 smooth minutes (no stalls)
  /// at a height below [_defaultHeight], tries the next one up — in the
  /// background, so a failure costs nothing.
  void _maybeStepUp() {
    if (!_autoMode || !_isPlaying || _switchingLabel != null) return;
    final now = DateTime.now();
    if (now.difference(_lastQualityChangeAt) < const Duration(minutes: 2)) {
      return;
    }
    if (_stallTimes.any(
      (t) => now.difference(t) < const Duration(minutes: 2),
    )) {
      return;
    }
    final current = _lastChosen;
    if (current == null) return;
    final higher =
        _qualities
            .where(
              (q) => q.height > current.height && q.height <= _defaultHeight,
            )
            .toList()
          ..sort((a, b) => a.height.compareTo(b.height));
    _lastQualityChangeAt = now;
    if (higher.isNotEmpty) _switchQuality(higher.first, auto: true);
  }

  /// Refreshes an ageing manifest (> 5h / near its `expire`) in the
  /// background, so the next switch or reconnect uses valid signatures.
  void _maybeRefreshManifest() {
    if (_refreshingInBackground || !_manifestExpiring) return;
    _refreshingInBackground = true;
    _refreshManifest().whenComplete(() => _refreshingInBackground = false);
  }

  void _openSettingsSheet() {
    _hideControlsTimer?.cancel();
    PlayerSettingsSheet.show(
      context,
      currentSpeed: _playbackRate,
      onSpeedChanged: _setPlaybackRate,
      qualities: [_autoEntryLabel, for (final q in _qualities) q.label],
      currentQuality: _autoMode ? _autoEntryLabel : _currentQuality,
      pendingQuality: _switchTarget,
      onQualityChanged: (label) {
        if (label == _autoEntryLabel) {
          _enableAutoMode();
          return;
        }
        final option = _qualities.where((q) => q.label == label).firstOrNull;
        if (option == null) return;
        _autoMode = false;
        if (option.label == _currentQuality) {
          // Same stream, now pinned.
          PlaybackQualityPrefs.saveYoutube(option.height);
        }
        _switchQuality(option);
      },
      qualityNote: _qualities.length <= 1 || _qualities.last.height <= 360
          ? 'المصدر (يوتيوب) لا يوفر جودة أعلى لهذا الفيديو'
          : null,
    ).whenComplete(_bumpControls);
  }

  // --- Gestures (left half = brightness, right half = volume, either half
  // scrubs horizontally, double-tap either half seeks ±10s) -------------

  void _onZonePanStart(DragStartDetails details) {
    _dragging = true;
    _draggingHorizontal = false;
    _dragStartGlobalX = details.globalPosition.dx;
    _dragStartGlobalY = details.globalPosition.dy;
    _brightnessAtDragStart = _currentBrightness;
    _volumeAtDragStart = _currentVolume;
    _seekBaseSeconds = _handle.position.inSeconds;
  }

  void _onZonePanUpdate(
    DragUpdateDetails details,
    BoxConstraints constraints,
    bool isLeftZone,
  ) {
    final dx = details.globalPosition.dx - _dragStartGlobalX;
    final dy = details.globalPosition.dy - _dragStartGlobalY;

    if (!_draggingHorizontal && dx.abs() < 12 && dy.abs() < 12) return;

    final horizontal = dx.abs() > dy.abs();
    if (!_dragging) return;
    if (horizontal) {
      _draggingHorizontal = true;
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
      final fraction = -dy / constraints.maxHeight;
      final base = isLeftZone ? _brightnessAtDragStart : _volumeAtDragStart;
      final value = (base + fraction).clamp(0.0, 1.0);
      if (isLeftZone) {
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
          _showVolumeOverlay = true;
          _showBrightnessOverlay = false;
        });
        VolumeController.instance.setVolume(value);
      }
    }
  }

  void _onZonePanEnd(DragEndDetails details) {
    if (_draggingHorizontal && _dragSeconds != null) {
      _seekTo(Duration(seconds: _dragSeconds!.round()));
      setState(() => _dragSeconds = null);
    }
    _dragging = false;
    _draggingHorizontal = false;
    _hideOverlaysSoon();
  }

  // Double-tap seek deliberately doesn't call _bumpControls() — it works as a
  // hidden gesture (the ripple is the feedback), not forcing the overlay open.
  void _onDoubleTapZone({required bool right}) {
    _seekBy(Duration(seconds: right ? 10 : -10));
    setState(() => _rippleOnRight = right);
    _rippleController.forward(from: 0);
  }

  String _label(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (_failed) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: _buildError(scheme),
      );
    }

    final player = ColoredBox(
      key: _surfaceKey,
      color: scheme.scrim,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            fit: StackFit.expand,
            children: [
              if (!_started) _buildPoster(scheme),
              if (_started) ...[
                // A quality being prepared sits underneath the one on
                // screen, so the swap is just a re-order — no black frame.
                if (_pendingSlot != null) _pendingSlot!.buildVideo(),
                _slot.buildVideo(),
              ],
              if (_started && !_loading && _buffering && !_showControls)
                Center(
                  child: SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  ),
                ),
              // Full-area gesture layer, split into a left (brightness)
              // and right (volume) half. Placed above the video but below
              // the controls overlay so taps/drags always reach it. Uses
              // `Positioned` with all 4 edges pinned (not Row/Expanded)
              // so each zone gets a real, non-zero hit-test area even
              // though the GestureDetectors have no visual child —
              // Row's default CrossAxisAlignment.center would otherwise
              // shrink a childless GestureDetector to zero height.
              if (_started && !_loading)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: constraints.maxWidth / 2,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _toggleControlsVisibility,
                    onDoubleTap: () => _onDoubleTapZone(right: false),
                    onPanStart: _onZonePanStart,
                    onPanUpdate: (details) =>
                        _onZonePanUpdate(details, constraints, true),
                    onPanEnd: _onZonePanEnd,
                  ),
                ),
              if (_started && !_loading)
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  width: constraints.maxWidth / 2,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _toggleControlsVisibility,
                    onDoubleTap: () => _onDoubleTapZone(right: true),
                    onPanStart: _onZonePanStart,
                    onPanUpdate: (details) =>
                        _onZonePanUpdate(details, constraints, false),
                    onPanEnd: _onZonePanEnd,
                  ),
                ),
              _buildSeekRipple(scheme, constraints),
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
              if (_started && !_loading)
                Positioned.fill(
                  child: IgnorePointer(
                    ignoring: !_showControls,
                    child: AnimatedOpacity(
                      opacity: _showControls ? 1 : 0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                      child: _buildControlsOverlay(scheme),
                    ),
                  ),
                ),
              // A quality switch / reconnect never blocks the video — just a
              // small pill under the top bar while it loads underneath.
              if (_started && !_loading && _switchingLabel != null)
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
              // Above everything while the first stream is being resolved.
              if (_started && _loading) _buildLoading(scheme),
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
    return Directionality(
      textDirection: TextDirection.rtl,
      child: PopScope(
        canPop: !_isFullscreen,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && _isFullscreen) {
            _exitFullscreen();
            return;
          }
          if (didPop) {
            // Leaving the video: stop playback, then back to portrait with
            // visible system bars before the previous screen shows.
            _player.pause();
            _restoreSystemChrome();
          }
        },
        child: _isFullscreen
            ? player
            : AspectRatio(aspectRatio: 16 / 9, child: player),
      ),
    );
  }

  /// Ripple + ±10s icon over the half of the screen that was double-tapped.
  Widget _buildSeekRipple(ColorScheme scheme, BoxConstraints constraints) {
    return Positioned(
      left: _rippleOnRight ? constraints.maxWidth / 2 : 0,
      top: 0,
      bottom: 0,
      width: constraints.maxWidth / 2,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _rippleController,
          builder: (context, _) {
            final t = _rippleController.value;
            if (_rippleController.isDismissed) return const SizedBox.shrink();
            final opacity = (1 - t).clamp(0.0, 1.0);
            return Opacity(
              opacity: opacity,
              child: Center(
                child: Container(
                  width: 96 + 48 * t,
                  height: 96 + 48 * t,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _rippleOnRight
                            ? Icons.fast_forward_rounded
                            : Icons.fast_rewind_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                      Text(
                        _rippleOnRight ? '+10' : '-10',
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Top bar (back + title + settings), center transport row, bottom bar
  /// (time + seekbar + fullscreen) over top/bottom black gradients. Only the
  /// bars and buttons take touches; the gradients and the empty space let taps
  /// through to the gesture zones underneath, so tapping bare video still
  /// toggles the controls. The caller fades it.
  Widget _buildControlsOverlay(ColorScheme scheme) {
    final position = Duration(
      seconds: (_dragSeconds ?? _handle.position.inSeconds.toDouble()).round(),
    );
    final duration = _handle.duration;
    final totalSeconds = duration?.inSeconds.toDouble() ?? 0;
    final maxSeconds = totalSeconds == 0 ? 1.0 : totalSeconds;
    final positionSeconds = position.inSeconds.toDouble().clamp(0, maxSeconds);
    final bufferedSeconds = _bufferedPosition.inSeconds.toDouble().clamp(
      0,
      maxSeconds,
    );
    const white = Colors.white;

    Widget gradient({required bool top, required double height}) {
      return PositionedDirectional(
        top: top ? 0 : null,
        bottom: top ? null : 0,
        start: 0,
        end: 0,
        height: height,
        child: IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: top ? Alignment.topCenter : Alignment.bottomCenter,
                end: top ? Alignment.bottomCenter : Alignment.topCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.7),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Stack(
      children: [
        gradient(top: true, height: 80),
        gradient(top: false, height: 120),
        PositionedDirectional(
          top: 0,
          start: 0,
          end: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_forward_ios_rounded),
                    iconSize: 22,
                    color: white,
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).backButtonTooltip,
                  ),
                  Expanded(
                    child: Text(
                      widget.title,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        color: white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _openSettingsSheet,
                    icon: const Icon(Icons.settings_rounded),
                    iconSize: 24,
                    color: white,
                  ),
                ],
              ),
            ),
          ),
        ),
        Center(
          // Physical order, whatever the text direction: back on the left,
          // forward on the right — same as the double-tap zones.
          child: Row(
            mainAxisSize: MainAxisSize.min,
            textDirection: TextDirection.ltr,
            children: [
              IconButton(
                iconSize: 30,
                onPressed: () => _skipBy(const Duration(seconds: -10)),
                icon: const Icon(Icons.replay_10_rounded),
                color: white,
              ),
              const SizedBox(width: AppSpacing.xl),
              CircleAvatar(
                radius: 35,
                backgroundColor: Colors.black.withValues(alpha: 0.5),
                child: _buffering
                    ? const SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                          color: white,
                          strokeWidth: 3,
                        ),
                      )
                    : IconButton(
                        padding: EdgeInsets.zero,
                        iconSize: 50,
                        onPressed: _togglePlayPause,
                        icon: Icon(
                          _isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                        ),
                        color: white,
                      ),
              ),
              const SizedBox(width: AppSpacing.xl),
              IconButton(
                iconSize: 30,
                onPressed: () => _skipBy(const Duration(seconds: 10)),
                icon: const Icon(Icons.forward_10_rounded),
                color: white,
              ),
            ],
          ),
        ),
        PositionedDirectional(
          start: 0,
          end: 0,
          bottom: 0,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Row(
                children: [
                  Text(
                    '${_label(position)} / ${duration != null ? _label(duration) : '--:--'}',
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      color: white,
                      fontSize: 12,
                    ),
                  ),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 7,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 14,
                        ),
                        activeTrackColor: scheme.primary,
                        secondaryActiveTrackColor: scheme.primary.withValues(
                          alpha: 0.3,
                        ),
                        inactiveTrackColor: Colors.white.withValues(alpha: 0.3),
                        thumbColor: scheme.primary,
                        overlayColor: scheme.primary.withValues(alpha: 0.2),
                      ),
                      child: Slider(
                        min: 0,
                        max: maxSeconds,
                        value: positionSeconds.toDouble(),
                        secondaryTrackValue: bufferedSeconds.toDouble(),
                        onChanged: totalSeconds == 0
                            ? null
                            : (value) {
                                _scheduleAutoHide();
                                setState(() => _dragSeconds = value);
                              },
                        onChangeEnd: totalSeconds == 0
                            ? null
                            : (value) {
                                setState(() => _dragSeconds = null);
                                _seekTo(Duration(seconds: value.round()));
                              },
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _toggleFullscreen,
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      _isFullscreen
                          ? Icons.fullscreen_exit_rounded
                          : Icons.fullscreen_rounded,
                    ),
                    color: white,
                    iconSize: 26,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String? get _posterUrl {
    final thumbnailUrl = widget.thumbnailUrl;
    if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) return thumbnailUrl;
    final videoId = extractYouTubeId(widget.rawIdOrUrl);
    if (videoId == null) return null;
    return 'https://img.youtube.com/vi/$videoId/hqdefault.jpg';
  }

  /// Visible only for the moment before playback starts — over a poster image
  /// rather than a live/streaming surface.
  Widget _buildPoster(ColorScheme scheme) {
    final posterUrl = _posterUrl;
    final blank = ColoredBox(color: scheme.scrim);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _startPlayback,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (posterUrl != null)
            CachedNetworkImage(
              imageUrl: posterUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => blank,
              errorWidget: (context, url, error) => blank,
            )
          else
            blank,
          DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.scrim.withValues(alpha: 0.25),
            ),
          ),
          Center(
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: scheme.primary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.play_arrow_rounded,
                color: scheme.onPrimary,
                size: 44,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Shown while the first stream is being resolved (quality switches load in
  /// the background instead — see [QualitySwitchIndicator]).
  Widget _buildLoading(ColorScheme scheme) {
    return ColoredBox(
      color: scheme.scrim,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Colors.white),
            if (_retrying) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                'جاري إعادة المحاولة...',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: scheme.onPrimary),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Error state: icon, message and a retry button. A specific [_failMessage]
  /// (e.g. no playable stream at all) wins over the generic text.
  Widget _buildError(ColorScheme scheme) {
    final textTheme = Theme.of(context).textTheme;
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ColoredBox(
        color: scheme.scrim,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  color: scheme.error,
                  size: 40,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _failMessage ?? 'حدث خطأ في تحميل الفيديو',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(
                    color: scheme.onPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                FilledButton(
                  onPressed: _retry,
                  child: const Text('إعادة المحاولة'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QualityOption {
  const _QualityOption({
    required this.label,
    required this.url,
    required this.height,
    required this.detail,
    this.audioUrl,
    this.headers = const {},
  });

  /// The User-Agent of the client that produced these URLs.
  final Map<String, String> headers;

  final String label;

  /// The muxed stream's URL, or the video-only stream's when [audioUrl] is set.
  final String url;

  /// Separate audio stream for video-only (adaptive) options; `null` = muxed.
  final String? audioUrl;
  final int height;

  /// Container / codec / fps — for logs only.
  final String detail;

  bool get isAdaptive => audioUrl != null;

  PlaybackSource get source =>
      PlaybackSource(url: url, audioUrl: audioUrl, headers: headers);

  _QualityOption withLabel(String newLabel) => _QualityOption(
    label: newLabel,
    url: url,
    audioUrl: audioUrl,
    height: height,
    detail: detail,
    headers: headers,
  );
}

/// A quality opened (silent, paused) on its own slot, ready to be swapped in.
class _Prepared {
  const _Prepared(this.slot, this.option);

  final PlayerSlot slot;
  final _QualityOption option;
}

class _MediaKitHandle extends LecturePlaybackHandle {
  @override
  Duration position = Duration.zero;

  @override
  Duration? duration;
}

class _SideMeter extends StatelessWidget {
  const _SideMeter({required this.icon, required this.value});

  final IconData icon;
  final double value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      width: 46,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: scheme.scrim.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(23),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: scheme.onPrimary, size: 20),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 70,
            width: 4,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: scheme.onPrimary.withValues(alpha: 0.24),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                FractionallySizedBox(
                  heightFactor: value.clamp(0, 1),
                  child: Container(
                    decoration: BoxDecoration(
                      color: scheme.primary,
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
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.onPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
