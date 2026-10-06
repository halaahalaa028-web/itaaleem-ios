import 'dart:async';

import 'package:chewie/chewie.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:itaaleem/core/utils/youtube_utils.dart';
import 'package:itaaleem/features/courses/presentation/widgets/players/lecture_playback_handle.dart';
import 'package:itaaleem/features/courses/presentation/widgets/players/playback_progress_reporter.dart';
import 'package:itaaleem/features/courses/presentation/widgets/players/player_error_view.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;

/// One playable URL plus the headers its InnerTube client needs.
class _Candidate {
  const _Candidate(this.url, this.headers, this.label);

  final String url;
  final Map<String, String> headers;
  final String label;
}

/// "المشغل البديل": a YouTube lecture through `video_player` (ExoPlayer on
/// Android, AVPlayer on iOS) with Chewie's ready-made controls and
/// fullscreen. (better_player 0.0.84 doesn't build on AGP 8, so this is
/// the chewie + video_player alternative.)
///
/// video_player can't merge YouTube's separate video/audio streams, so it
/// plays/// muxed streams best-first, ≤ 720p (720 → 480 → 360), from youtube_explode's
/// default clients and then each InnerTube client in turn (10 s timeout per
/// step), stopping at the first stream that opens.
class ChewieYoutubePlayer extends StatefulWidget {
  const ChewieYoutubePlayer({
    super.key,
    required this.rawIdOrUrl,
    required this.startAt,
    required this.onReady,
    required this.onEnded,
    this.progressReporter,
    this.onFailed,
  });

  final String rawIdOrUrl;
  final Duration startAt;
  final ValueChanged<LecturePlaybackHandle> onReady;
  final VoidCallback onEnded;
  final ProgressReporter? progressReporter;
  final VoidCallback? onFailed;

  @override
  State<ChewieYoutubePlayer> createState() => _ChewieYoutubePlayerState();
}

class _ChewieYoutubePlayerState extends State<ChewieYoutubePlayer> {
  static final _clients = <yt.YoutubeApiClient>[
    yt.YoutubeApiClient.androidVr,
    yt.YoutubeApiClient.ios,
    yt.YoutubeApiClient.androidSdkless,
    yt.YoutubeApiClient.tv,
  ];

  /// Per manifest fetch and per stream open — never an endless spinner.
  static const _stepTimeout = Duration(seconds: 10);
  static const _maxHeight = 720;

  VideoPlayerController? _video;
  ChewieController? _chewie;
  final _handle = _ChewieHandle();
  Timer? _progressTimer;
  bool _failed = false;
  bool _ended = false;
  bool _wasPlaying = false;
  String _status = 'جاري تجهيز الفيديو...';

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    final id = extractYouTubeId(widget.rawIdOrUrl);
    if (id == null) return _fail();
    await for (final candidate in _candidates(id)) {
      if (!mounted) return;
      if (kDebugMode) debugPrint('>>> chewie YT: trying ${candidate.label}');
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(candidate.url),
        httpHeaders: candidate.headers,
      );
      try {
        await controller.initialize().timeout(_stepTimeout);
        if (kDebugMode) {
          debugPrint('>>> Chewie: VideoPlayerController initialized');
        }
        if (!mounted) {
          await controller.dispose();
          return;
        }
        _attach(controller);
        return;
      } catch (e) {
        if (kDebugMode) {
          debugPrint('>>> chewie YT: ${candidate.label} failed: $e');
        }
        await controller.dispose();
      }
    }
    _fail();
  }

  /// Lazily resolves candidates so the first working one wins without
  /// fetching every client's manifest.
  Stream<_Candidate> _candidates(String id) async* {
    if (kDebugMode) debugPrint('>>> Chewie: Extracting streams for video $id');
    final explode = yt.YoutubeExplode();
    final seen = <String>{};
    try {
      // youtube_explode's own default clients first, then one at a time.
      for (final client in <yt.YoutubeApiClient?>[null, ..._clients]) {
        yt.StreamManifest manifest;
        try {
          manifest =
              await (client == null
                      ? explode.videos.streamsClient.getManifest(id)
                      : explode.videos.streamsClient.getManifest(
                          id,
                          ytClients: [client],
                        ))
                  .timeout(_stepTimeout);
        } on yt.VideoUnplayableException catch (e) {
          if (kDebugMode) debugPrint('>>> Chewie: Error: unplayable: $e');
          return;
        } catch (e) {
          if (kDebugMode) debugPrint('>>> Chewie: Error: manifest failed: $e');
          continue;
        }
        if (kDebugMode) {
          debugPrint(
            '>>> Chewie: Found ${manifest.muxed.length} muxed streams',
          );
        }
        // Best first, ≤ 720p before anything taller.
        final muxed = manifest.muxed.sortByVideoQuality();
        final ordered = [
          ...muxed.where((s) => s.videoResolution.height <= _maxHeight),
          ...muxed.where((s) => s.videoResolution.height > _maxHeight),
        ];
        for (final s in ordered) {
          final url = s.url.toString();
          if (!seen.add(url)) continue;
          if (mounted) setState(() => _status = 'جاري تحميل الفيديو...');
          if (kDebugMode) {
            debugPrint('>>> Chewie: Playing quality ${s.qualityLabel}');
          }
          yield _Candidate(url, {
            'User-Agent': _userAgentFor(s.url, client),
          }, 'muxed ${s.qualityLabel}');
        }
      }
    } finally {
      explode.close();
    }
  }

  /// Stream URLs are bound to the InnerTube client that issued them (its
  /// `c=` query parameter) — send that client's User-Agent.
  static String _userAgentFor(Uri url, yt.YoutubeApiClient? client) {
    if (client != null) return _userAgentOf(client);
    final c = url.queryParameters['c']?.toUpperCase() ?? '';
    if (c.startsWith('IOS')) return _userAgentOf(yt.YoutubeApiClient.ios);
    if (c == 'ANDROID_VR') return _userAgentOf(yt.YoutubeApiClient.androidVr);
    if (c.startsWith('ANDROID')) {
      return _userAgentOf(yt.YoutubeApiClient.androidSdkless);
    }
    return _fallbackUserAgent;
  }

  static const _fallbackUserAgent =
      'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36';

  static String _userAgentOf(yt.YoutubeApiClient client) {
    final context = client.payload['context'];
    final inner = context is Map ? context['client'] : null;
    final ua = inner is Map ? inner['userAgent'] : null;
    return ua is String && ua.isNotEmpty ? ua : _fallbackUserAgent;
  }

  void _attach(VideoPlayerController controller) {
    _video = controller;
    _handle.controller = controller;
    controller.addListener(_onTick);
    if (widget.startAt > Duration.zero) controller.seekTo(widget.startAt);
    setState(() {
      _chewie = ChewieController(
        videoPlayerController: controller,
        autoPlay: true,
        allowFullScreen: true,
        allowPlaybackSpeedChanging: true,
        allowMuting: false,
        aspectRatio: controller.value.aspectRatio,
        deviceOrientationsAfterFullScreen: const [
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ],
        materialProgressColors: ChewieProgressColors(
          playedColor: Theme.of(context).colorScheme.primary,
          handleColor: Theme.of(context).colorScheme.primary,
        ),
        errorBuilder: (context, message) =>
            PlayerErrorView(message: 'تعذر تشغيل الفيديو', onRetry: _retry),
      );
    });
    // Progress every 5 seconds while playing.
    _progressTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      final v = controller.value;
      if (!v.isPlaying || v.duration <= Duration.zero) return;
      widget.progressReporter
        ?..onPositionChanged(v.position, v.duration)
        ..flush();
    });
    widget.onReady(_handle);
  }

  void _onTick() {
    final v = _video?.value;
    if (v == null) return;
    if (v.hasError && !_failed) {
      _fail();
      return;
    }
    if (_wasPlaying && !v.isPlaying) {
      widget.progressReporter?.onPositionChanged(v.position, v.duration);
      widget.progressReporter?.flush();
      _handle.onPause?.call();
    }
    _wasPlaying = v.isPlaying;
    final done =
        v.duration > Duration.zero &&
        v.position >= v.duration - const Duration(milliseconds: 500);
    if (done && !_ended) {
      _ended = true;
      widget.progressReporter?.reportCompleted(v.duration);
      widget.onEnded();
    }
  }

  void _fail() {
    if (!mounted) return;
    setState(() => _failed = true);
    widget.onFailed?.call();
  }

  Future<void> _retry() async {
    await _teardown();
    if (!mounted) return;
    setState(() {
      _failed = false;
      _ended = false;
      _status = 'جاري تجهيز الفيديو...';
    });
    _open();
  }

  Future<void> _teardown() async {
    _progressTimer?.cancel();
    _progressTimer = null;
    final video = _video;
    final chewie = _chewie;
    _video = null;
    _chewie = null;
    _handle.controller = null;
    // Order matters: stop, release Chewie, then the decoder.
    video?.removeListener(_onTick);
    try {
      chewie?.pause();
    } catch (_) {}
    chewie?.dispose();
    await video?.dispose();
  }

  @override
  void dispose() {
    final v = _video?.value;
    if (v != null && v.duration > Duration.zero) {
      widget.progressReporter?.onPositionChanged(v.position, v.duration);
    }
    widget.progressReporter?.flush();
    _teardown();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return PlayerErrorView(
        message: 'تعذر تشغيل الفيديو بهذا المشغل',
        onRetry: _retry,
      );
    }
    final chewie = _chewie;
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ColoredBox(
        color: Colors.black,
        child: chewie == null
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Colors.white),
                    const SizedBox(height: 12),
                    Text(
                      _status,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Cairo',
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              )
            : Chewie(controller: chewie),
      ),
    );
  }
}

class _ChewieHandle extends LecturePlaybackHandle {
  VideoPlayerController? controller;

  @override
  Duration get position => controller?.value.position ?? Duration.zero;

  @override
  Duration? get duration {
    final d = controller?.value.duration;
    return d == null || d <= Duration.zero ? null : d;
  }
}
