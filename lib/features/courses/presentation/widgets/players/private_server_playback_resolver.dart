import 'package:drift/drift.dart' show Value;
import 'package:itaaleem/app/theme/app_theme.dart';
import 'package:itaaleem/core/network/connectivity_provider.dart';
import 'package:itaaleem/core/network/dio_client.dart';
import 'package:itaaleem/core/utils/result.dart';
import 'package:itaaleem/features/courses/domain/entities/lecture_details.dart';
import 'package:itaaleem/features/courses/presentation/providers/courses_providers.dart';
import 'package:itaaleem/features/courses/presentation/widgets/players/lecture_playback_handle.dart';
import 'package:itaaleem/features/courses/presentation/widgets/players/lecture_player_chooser.dart';
import 'package:itaaleem/features/courses/presentation/widgets/players/offline_progress_reporter.dart';
import 'package:itaaleem/features/courses/presentation/widgets/players/playback_progress_reporter.dart';
import 'package:itaaleem/features/video/data/offline/local_range_server.dart';
import 'package:itaaleem/features/video/data/offline/offline_database.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:flutter/material.dart';
import 'package:itaaleem/core/theme/app_palette.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:itaaleem/core/theme/app_radius.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';

/// Thrown by [PrivateServerPlaybackResolver] when there's nothing playable
/// at all — no internet and no usable offline copy, or an offline copy
/// whose license has expired — carrying the exact message the player
/// screen should show.
class OfflineUnavailableException implements Exception {
  const OfflineUnavailableException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Resolves a `private_server` [LectureVideo] into an actually-playable
/// stream before handing it to [LecturePlayerChooser]:
///
/// 0. If this lesson has a completed offline download (see
///    `OfflineDownloadManager`), plays it through `LocalRangeServer` instead
///    of touching the network at all — automatically with no connectivity,
///    on request ([forceOffline], from "المحمّلات"), or after asking
///    "تشغيل أوفلاين ولا أونلاين؟" when both are possible. An expired
///    offline copy is skipped (falls through to online, or to
///    [OfflineUnavailableException] if there's no connectivity either).
/// 1. Otherwise, `GET /lectures/{id}/playback` for a signed URL (+ optional
///    headers) — falls back to the plain [LectureVideo.videoUrl] already
///    embedded in `GET /lectures/{id}` if this call fails (no internet, API
///    error, ...).
/// 2. `GET /lectures/{id}/progress` for the lecture-level saved position —
///    falls back to the video's own embedded `progress` if this call fails.
///    A saved position past a few seconds prompts "متابعة من {time}؟" before
///    the player ever mounts.
/// 3. If the resolved player then fails to open or its stream dies
///    mid-playback (an expired signed URL surfaces the same way as any other
///    failure — see [LecturePlayerChooser.onRefreshSource]), freshly signed
///    URLs are fetched and playback resumes at the same position; only if
///    that fails too is the error view shown.
///
/// A demo session (`isDemo`) skips offline lookup and all three network
/// calls entirely and plays [LectureVideo.videoUrl] (the sample/dummy URL)
/// directly.
class PrivateServerPlaybackResolver extends ConsumerStatefulWidget {
  const PrivateServerPlaybackResolver({
    super.key,
    required this.lectureId,
    required this.video,
    required this.isDemo,
    required this.onReady,
    required this.onEnded,
    required this.onFullscreenChanged,
    required this.onSourceResolved,
    this.forceOffline = false,
  });

  final int lectureId;
  final LectureVideo video;
  final bool isDemo;
  final ValueChanged<LecturePlaybackHandle> onReady;
  final VoidCallback onEnded;
  final ValueChanged<bool> onFullscreenChanged;

  /// Called once resolution lands on a source, before [onReady] — `true`
  /// when playing the local offline copy, so the screen hosting this
  /// widget knows to record progress locally instead of over the network.
  final ValueChanged<bool> onSourceResolved;

  /// From "المحمّلات"' play button — skips the "تشغيل أوفلاين ولا
  /// أونلاين؟" prompt and always plays the offline copy.
  final bool forceOffline;

  @override
  ConsumerState<PrivateServerPlaybackResolver> createState() =>
      _PrivateServerPlaybackResolverState();
}

class _ResolvedPlayback {
  const _ResolvedPlayback({
    required this.url,
    required this.headers,
    required this.startAt,
    this.qualities = const [],
    this.expiresAt,
  });

  final String url;
  final Map<String, String> headers;
  final Duration startAt;

  /// Per-quality signed URLs offered by `GET /lectures/{id}/playback`.
  final List<PlaybackQuality> qualities;
  final DateTime? expiresAt;
}

class _PrivateServerPlaybackResolverState
    extends ConsumerState<PrivateServerPlaybackResolver> {
  late Future<_ResolvedPlayback> _future;
  Duration _resolvedStartAt = Duration.zero;
  bool _isOffline = false;
  ProgressReporter? _progressReporter;

  @override
  void initState() {
    super.initState();
    _future = _resolve();
  }

  @override
  void didUpdateWidget(covariant PrivateServerPlaybackResolver oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.video.id != widget.video.id) {
      _resolvedStartAt = Duration.zero;
      _future = _resolve();
    }
  }

  Future<_ResolvedPlayback> _resolve() async {
    final fallbackUrl = widget.video.videoUrl ?? '';

    if (widget.isDemo) {
      widget.onSourceResolved(false);
      _resolvedStartAt = Duration(
        seconds: widget.video.progress?.lastPositionSeconds ?? 0,
      );
      return _ResolvedPlayback(
        url: fallbackUrl,
        headers: const {},
        startAt: _resolvedStartAt,
      );
    }

    final db = ref.read(offlineDatabaseProvider);
    final offlineRow = await db.getByLessonId(widget.lectureId);
    final isOnline = ref.read(connectivityStatusProvider).valueOrNull ?? true;

    if (offlineRow != null && offlineRow.downloadStatus == 'completed') {
      final expired =
          offlineRow.expiresAt != null &&
          offlineRow.expiresAt!.isBefore(DateTime.now());
      if (expired) {
        await db.updateByLessonId(
          widget.lectureId,
          (base) => base.copyWith(downloadStatus: const Value('expired')),
        );
      } else {
        final playOffline =
            widget.forceOffline ||
            !isOnline ||
            (mounted && await _askOnlineOrOffline());
        if (playOffline) return _resolveOffline(offlineRow);
      }
    } else if (offlineRow != null &&
        offlineRow.downloadStatus == 'expired' &&
        !isOnline) {
      widget.onSourceResolved(false);
      throw const OfflineUnavailableException(
        'انتهت صلاحية التحميل — اتصل بالإنترنت للتجديد',
      );
    }

    if (!isOnline) {
      widget.onSourceResolved(false);
      throw const OfflineUnavailableException(
        'لا يوجد اتصال بالإنترنت ولم يتم تحميل هذه المحاضرة',
      );
    }

    return _resolveOnline(fallbackUrl);
  }

  /// Serves the completed download straight off disk via `LocalRangeServer`
  /// — no network call of any kind. Resumes from whatever position was last
  /// recorded locally (`pendingSyncPositionSeconds`, written by the screen
  /// hosting this widget every time it reports offline progress), falling
  /// back to the video's last known online position.
  Future<_ResolvedPlayback> _resolveOffline(OfflineVideo row) async {
    final server = ref.read(localRangeServerProvider);
    await server.start();
    final url = server.urlFor(widget.lectureId);
    final resumeSeconds =
        row.pendingSyncPositionSeconds ??
        widget.video.progress?.lastPositionSeconds ??
        0;
    widget.onSourceResolved(true);
    _isOffline = true;
    _progressReporter = OfflineProgressReporter(
      db: ref.read(offlineDatabaseProvider),
      lessonId: widget.lectureId,
    );
    _resolvedStartAt = Duration(seconds: resumeSeconds);
    return _ResolvedPlayback(
      url: url,
      headers: const {},
      startAt: _resolvedStartAt,
    );
  }

  Future<bool> _askOnlineOrOffline() async {
    final choice = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        title: const Text(
          'تشغيل أوفلاين ولا أونلاين؟',
          style: TextStyle(
            color: AppColors.darkTextPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: const Text(
          'هذه المحاضرة محمّلة على جهازك.',
          style: TextStyle(color: AppColors.darkTextSecondary),
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('أونلاين'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
            child: const Text('أوفلاين'),
          ),
        ],
      ),
    );
    // A dismissed dialog defaults to the offline copy — the safer choice
    // (no data usage) when the student didn't make an explicit pick.
    return choice ?? true;
  }

  Future<_ResolvedPlayback> _resolveOnline(String fallbackUrl) async {
    widget.onSourceResolved(false);
    // Create the online progress reporter — the player will report every 15s.
    _progressReporter = PlaybackProgressReporter(
      dio: ref.read(dioClientProvider),
      lessonId: widget.lectureId,
    );
    var url = fallbackUrl;
    var headers = const <String, String>{};
    var qualities = const <PlaybackQuality>[];
    DateTime? expiresAt;
    try {
      final result = await ref.read(getLecturePlaybackUseCaseProvider)(
        widget.lectureId,
      );
      if (result case Ok(:final value) when value.url.isNotEmpty) {
        url = value.url;
        headers = value.headers;
        qualities = value.qualities;
        expiresAt = value.expiresAt;
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          '[PrivateServerPlaybackResolver] GET /lectures/${widget.lectureId}/playback '
          'failed, falling back to video_url: $e\n$stackTrace',
        );
      }
    }

    var resumeSeconds = widget.video.progress?.lastPositionSeconds ?? 0;
    try {
      final result = await ref.read(getLectureProgressUseCaseProvider)(
        widget.lectureId,
      );
      if (result case Ok(:final value)) resumeSeconds = value.positionSeconds;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          '[PrivateServerPlaybackResolver] GET /lectures/${widget.lectureId}/progress '
          'failed, falling back to embedded video progress: $e\n$stackTrace',
        );
      }
    }

    var startAt = Duration(seconds: resumeSeconds);
    if (resumeSeconds > 5 && mounted) {
      final resume = await _askResumeChoice(resumeSeconds);
      if (!resume) startAt = Duration.zero;
    }
    _resolvedStartAt = startAt;
    return _ResolvedPlayback(
      url: url,
      headers: headers,
      startAt: startAt,
      qualities: qualities,
      expiresAt: expiresAt,
    );
  }

  /// Freshly signed URLs (main + per-quality + headers) only — the player
  /// keeps its own position, and the resume dialog is never re-prompted.
  Future<LecturePlaybackInfo?> _refreshSignedSource() async {
    try {
      final result = await ref.read(getLecturePlaybackUseCaseProvider)(
        widget.lectureId,
      );
      if (result case Ok(:final value) when value.url.isNotEmpty) {
        return value;
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          '[PrivateServerPlaybackResolver] signed URL refresh failed: $e\n$stackTrace',
        );
      }
    }
    return null;
  }

  Future<bool> _askResumeChoice(int seconds) async {
    final label = _formatDuration(Duration(seconds: seconds));
    final choice = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        title: Text(
          'متابعة من $label؟',
          style: const TextStyle(
            color: AppColors.darkTextPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('من البداية'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
            child: const Text('متابعة'),
          ),
        ],
      ),
    );
    return choice ?? true;
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ResolvedPlayback>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          final error = snapshot.error;
          return _message(
            error is OfflineUnavailableException
                ? error.message
                : 'تعذر تحميل الفيديو',
          );
        }
        if (!snapshot.hasData) return _loadingBox();
        final resolved = snapshot.data!;
        if (resolved.url.isEmpty) return _message('تعذر تحميل الفيديو');

        return LecturePlayerChooser(
          key: ValueKey('resolver-${widget.video.id}'),
          videoUrl: resolved.url,
          headers: resolved.headers,
          qualities: resolved.qualities,
          expiresAt: resolved.expiresAt,
          startAt: resolved.startAt,
          thumbnailUrl: widget.video.thumbnailUrl,
          onReady: widget.onReady,
          onEnded: widget.onEnded,
          onFullscreenChanged: widget.onFullscreenChanged,
          onRefreshSource: (widget.isDemo || _isOffline)
              ? null
              : _refreshSignedSource,
          progressReporter: _progressReporter,
        );
      },
    );
  }

  Widget _loadingBox() => AspectRatio(
    aspectRatio: 16 / 9,
    child: ColoredBox(
      color: Colors.black,
      child: Center(
        child: CircularProgressIndicator(color: context.palette.primaryOnDark),
      ),
    ),
  );

  Widget _message(String text) => AspectRatio(
    aspectRatio: 16 / 9,
    child: ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textOnDark),
          ),
        ),
      ),
    ),
  );
}
