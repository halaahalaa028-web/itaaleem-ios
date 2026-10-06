import 'package:itaaleem/features/courses/domain/entities/lecture_details.dart';
import 'package:itaaleem/features/courses/presentation/widgets/players/advanced_direct_player.dart';
import 'package:itaaleem/features/courses/presentation/widgets/players/lecture_playback_handle.dart';
import 'package:itaaleem/features/courses/presentation/widgets/players/playback_failure.dart';
import 'package:itaaleem/features/courses/presentation/widgets/players/playback_progress_reporter.dart';
import 'package:itaaleem/features/courses/presentation/widgets/players/player_error_view.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:flutter/material.dart';

/// Plays a direct-URL (MP4/HLS/local offline copy) lecture video with
/// [AdvancedDirectPlayer]. There is no alternate player: if it fails to open
/// or can't recover mid-playback, [PlayerErrorView] is shown with a retry
/// button (after one fresh-URL attempt via [onRefreshSource] — signed URLs
/// expire). Every remount resumes from where the student was, not from
/// [startAt].
class LecturePlayerChooser extends StatefulWidget {
  const LecturePlayerChooser({
    super.key,
    required this.videoUrl,
    required this.startAt,
    required this.onReady,
    required this.onEnded,
    required this.onFullscreenChanged,
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
  final Map<String, String> headers;

  /// Per-quality signed URLs from `GET /lectures/{id}/playback`.
  final List<PlaybackQuality> qualities;
  final DateTime? expiresAt;
  final ValueChanged<LecturePlaybackHandle> onReady;
  final VoidCallback onEnded;
  final ValueChanged<bool> onFullscreenChanged;

  /// Fetches freshly signed URLs (they can expire). Used by the player
  /// itself to recover mid-playback, and here once per failure before the
  /// error view. Returning null goes straight to the error view.
  final Future<LecturePlaybackInfo?> Function()? onRefreshSource;

  /// Optional throttled progress reporter — forwarded to
  /// [AdvancedDirectPlayer].
  final ProgressReporter? progressReporter;

  @override
  State<LecturePlayerChooser> createState() => _LecturePlayerChooserState();
}

class _LecturePlayerChooserState extends State<LecturePlayerChooser> {
  late String _videoUrl = widget.videoUrl;
  late Map<String, String> _headers = widget.headers;
  late List<PlaybackQuality> _qualities = widget.qualities;
  late DateTime? _expiresAt = widget.expiresAt;
  bool _refreshAttempted = false;
  PlaybackFailure? _failure;
  int _attempt = 0;

  /// The mounted player's handle — its last position is where a remount
  /// resumes.
  LecturePlaybackHandle? _handle;
  DateTime? _readyAt;

  Duration get _resumeAt {
    final position = _handle?.position ?? Duration.zero;
    return position > Duration.zero ? position : widget.startAt;
  }

  void _onReady(LecturePlaybackHandle handle) {
    _handle = handle;
    _readyAt = DateTime.now();
    widget.onReady(handle);
  }

  /// Fresh signed URLs into state; `false` if there's no refresher or the
  /// call failed.
  Future<bool> _refresh() async {
    final refresh = widget.onRefreshSource;
    if (refresh == null) return false;
    try {
      final info = await refresh();
      if (info == null || info.url.isEmpty) return false;
      _videoUrl = info.url;
      _headers = info.headers;
      if (info.qualities.isNotEmpty) _qualities = info.qualities;
      _expiresAt = info.expiresAt;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _onPlayerError(PlaybackFailure failure) async {
    if (!mounted) return;
    // A player that played fine for a while earns another refresh — the
    // signed URL simply expired again.
    final readyAt = _readyAt;
    if (readyAt != null &&
        DateTime.now().difference(readyAt) > const Duration(minutes: 1)) {
      _refreshAttempted = false;
    }
    if (!_refreshAttempted && failure != PlaybackFailure.network) {
      _refreshAttempted = true;
      if (await _refresh() && mounted) {
        setState(() => _attempt++);
        return;
      }
    }
    if (kDebugMode) {
      debugPrint(
        '[LecturePlayerChooser] playback failed ($failure) for $_videoUrl',
      );
    }
    if (mounted) setState(() => _failure = failure);
  }

  Future<void> _retry() async {
    // The URL may well have expired while the error view was up.
    await _refresh();
    if (!mounted) return;
    setState(() {
      _failure = null;
      _refreshAttempted = false;
      _readyAt = null;
      _attempt++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final failure = _failure;
    if (failure != null) {
      return PlayerErrorView(message: failure.message, onRetry: _retry);
    }
    return AdvancedDirectPlayer(
      key: ValueKey('adv-$_attempt'),
      videoUrl: _videoUrl,
      startAt: _resumeAt,
      thumbnailUrl: widget.thumbnailUrl,
      headers: _headers,
      qualities: _qualities,
      expiresAt: _expiresAt,
      onRefreshSource: widget.onRefreshSource,
      onReady: _onReady,
      onEnded: widget.onEnded,
      onFullscreenChanged: widget.onFullscreenChanged,
      onError: _onPlayerError,
      progressReporter: widget.progressReporter,
    );
  }
}
