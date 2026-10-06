import 'package:itaaleem/core/network/api_endpoints.dart';
import 'package:itaaleem/core/network/dio_client.dart';
import 'package:itaaleem/core/widgets/secure_screen.dart';
import 'package:itaaleem/app/theme/app_theme.dart';
import 'package:itaaleem/core/utils/youtube_utils.dart';
import 'package:itaaleem/features/courses/presentation/widgets/players/lecture_player_chooser.dart';
import 'package:itaaleem/features/courses/presentation/widgets/players/player_selection_sheet.dart';
import 'package:itaaleem/features/courses/presentation/widgets/players/lecture_playback_handle.dart';
import 'package:itaaleem/features/courses/presentation/widgets/players/offline_progress_reporter.dart';
import 'package:itaaleem/features/courses/presentation/widgets/players/playback_progress_reporter.dart';
import 'package:itaaleem/features/subjects/presentation/widgets/lesson_pdf_view.dart';
import 'package:itaaleem/features/video/data/offline/local_range_server.dart';
import 'package:itaaleem/features/video/data/offline/offline_database.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:itaaleem/core/widgets/content_watermark.dart';
import 'package:itaaleem/features/auth/presentation/providers/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:itaaleem/core/theme/app_palette.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:itaaleem/core/theme/app_radius.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';

/// Plays a subject lesson's own video directly from `SubjectLesson.videoUrl`
/// — deliberately *not* routed through `/lectures/{id}`
/// ([LecturePlayerScreen]/`lectureDetailsProvider`), which fetches from the
/// separate "courses" content model's own id space. A subject's lesson id
/// has no guaranteed relationship to a `GET /lectures/{id}` row (different
/// resource entirely), so reusing that id there could 403/404 or — worse —
/// silently play the wrong lecture's video. `GET /subjects/{id}` already
/// hands this screen a real, directly-playable video URL, so playback here
/// reuses [LecturePlayerChooser] fed straight from that URL, with no extra
/// network round-trip.
/// Carried via `GoRouter`'s `extra` when pushing [lessonVideoPath].
class LessonVideoArgs {
  const LessonVideoArgs({
    required this.title,
    this.videoUrl,
    this.lessonId,
    this.pdfUrl,
    this.playerKind,
  });

  final String title;
  final String? videoUrl;
  final int? lessonId;
  final String? pdfUrl;

  /// The YouTube player picked before navigating (see [pickYoutubePlayer]).
  final YoutubePlayerKind? playerKind;
}

class LessonVideoScreen extends ConsumerStatefulWidget {
  const LessonVideoScreen({
    super.key,
    required this.title,
    required this.videoUrl,
    this.lessonId,
    this.pdfUrl,
    this.playerKind,
  });

  final String title;
  final String? videoUrl;
  final YoutubePlayerKind? playerKind;

  /// The lesson's PDF — when set, a button under the video opens it in a
  /// split view beneath the (still playing) player.
  final String? pdfUrl;

  /// When set, a completed (non-expired) offline download of this lesson is
  /// played from disk instead of [videoUrl] — see `OfflineDownloadManager`.
  final int? lessonId;

  @override
  ConsumerState<LessonVideoScreen> createState() => _LessonVideoScreenState();
}

class _ResolvedLesson {
  const _ResolvedLesson({
    required this.url,
    required this.startAt,
    required this.isOffline,
  });

  final String? url;
  final Duration startAt;
  final bool isOffline;
}

class _LessonVideoScreenState extends ConsumerState<LessonVideoScreen> {
  bool _fullscreen = false;
  bool _showPdf = false;
  late final Future<_ResolvedLesson> _resolveFuture = _resolve();
  ProgressReporter? _progressReporter;

  /// Keeps the player's `State` (and so its media_kit `Player`) alive when
  /// entering/leaving fullscreen changes where the widget sits in the tree
  /// (plain vs. wrapped in `SizedBox.expand`). Without a `GlobalKey` Flutter
  /// can't move it between parents, so it would dispose the player and start
  /// a brand-new one — re-fetching the stream and restarting playback.
  final _youtubePlayerKey = GlobalKey();

  @override
  void dispose() {
    _progressReporter?.dispose();
    // Safety net on top of the players' own cleanup: leaving this screen must
    // always restore portrait + visible system bars, whatever state the
    // player was in (fullscreen, errored, mid-load).
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<_ResolvedLesson> _resolve() async {
    final lessonId = widget.lessonId;
    // --- Offline check ---
    if (lessonId != null) {
      try {
        final row = await ref
            .read(offlineDatabaseProvider)
            .getByLessonId(lessonId);
        final expired =
            row?.expiresAt != null && row!.expiresAt!.isBefore(DateTime.now());
        if (row != null && row.downloadStatus == 'completed' && !expired) {
          final server = ref.read(localRangeServerProvider);
          await server.start();
          final offlineUrl = server.urlFor(lessonId);
          if (kDebugMode) {
            debugPrint('[LessonVideoScreen] playing OFFLINE copy: $offlineUrl');
          }
          // Resume from offline pending sync position if available.
          final resumeSeconds = row.pendingSyncPositionSeconds ?? 0;
          // Track progress locally — synced to server by
          // OfflineLicenseChecker.syncPendingProgress on next app start.
          _progressReporter = OfflineProgressReporter(
            db: ref.read(offlineDatabaseProvider),
            lessonId: lessonId,
          );
          return _ResolvedLesson(
            url: offlineUrl,
            startAt: Duration(seconds: resumeSeconds),
            isOffline: true,
          );
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[LessonVideoScreen] offline lookup failed: $e');
        }
      }
    }
    if (kDebugMode) {
      debugPrint(
        '[LessonVideoScreen] lesson=$lessonId video_url=${widget.videoUrl}',
      );
    }

    // --- Online: fetch saved position for resume ---
    var startAt = Duration.zero;
    if (lessonId != null) {
      try {
        final dio = ref.read(dioClientProvider);
        final response = await dio.get<Map<String, dynamic>>(
          ApiEndpoints.lectureProgress(lessonId),
        );
        final data = response.data?['data'] ?? response.data;
        final posSeconds = data?['position'] as int? ?? 0;
        if (posSeconds > 5 && mounted) {
          final resume = await _askResumeChoice(posSeconds);
          if (resume) {
            startAt = Duration(seconds: posSeconds);
          }
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
            '[LessonVideoScreen] GET progress failed (ok, starting from 0): $e',
          );
        }
      }

      // Create online progress reporter.
      _progressReporter = PlaybackProgressReporter(
        dio: ref.read(dioClientProvider),
        lessonId: lessonId,
      );
    }

    return _ResolvedLesson(
      url: widget.videoUrl,
      startAt: startAt,
      isOffline: false,
    );
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
    if (kDebugMode) {
      debugPrint('>>> VIDEO: build, canPop=${Navigator.canPop(context)}');
    }
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) return;
        if (kDebugMode) {
          debugPrint('>>> VIDEO: popped successfully');
        }
        SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      },
      child: FutureBuilder<_ResolvedLesson>(
        future: _resolveFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return Scaffold(
              backgroundColor: Colors.black,
              body: Center(
                child: CircularProgressIndicator(
                  color: context.palette.primaryOnDark,
                ),
              ),
            );
          }
          final resolved = snapshot.data;
          return _buildScreen(
            context,
            resolved?.url,
            resolved?.startAt ?? Duration.zero,
            resolved?.isOffline ?? false,
          );
        },
      ),
    );
  }

  /// Same approach as the old Capital Academy app: `youtube_explode_dart`
  /// resolves a real stream that media_kit plays; if that fails it falls back
  /// shows an Arabic error with a retry button if that fails.
  Widget _buildYoutube(String url, Duration startAt) {
    final player = YoutubeMultiPlayer(
      key: _youtubePlayerKey,
      rawIdOrUrl: url,
      startAt: startAt,
      title: widget.title,
      progressReporter: _progressReporter,
      initialKind: widget.playerKind,
      onReady: (LecturePlaybackHandle handle) {},
      onEnded: () {},
      onFullscreenChanged: (value) {
        if (mounted) setState(() => _fullscreen = value);
      },
    );
    return _fullscreen ? SizedBox.expand(child: player) : player;
  }

  Widget _buildScreen(
    BuildContext context,
    String? url,
    Duration startAt,
    bool isOffline,
  ) {
    return SecureScreen(
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: _fullscreen
            ? null
            : AppBar(
                backgroundColor: Colors.black,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                title: Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 15),
                ),
              ),
        body: SafeArea(
          top: !_fullscreen,
          bottom: !_fullscreen,
          child: _buildBody(context, url, startAt),
        ),
      ),
    );
  }

  /// Video on top; below it either the "open PDF" button or the PDF split
  /// view. The player always sits at the same spot in the tree (only its
  /// siblings come and go), so opening/closing the PDF never remounts it.
  Widget _buildBody(BuildContext context, String? url, Duration startAt) {
    final scheme = Theme.of(context).colorScheme;
    final pdfUrl = widget.pdfUrl;
    final hasPdf = pdfUrl != null && pdfUrl.isNotEmpty && !_fullscreen;
    final split = hasPdf && _showPdf;
    final student = ref.watch(authControllerProvider).valueOrNull;
    final fillVideo = _fullscreen || split;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          fit: fillVideo ? FlexFit.tight : FlexFit.loose,
          child: Align(
            heightFactor: fillVideo ? null : 1,
            // The watermark is a sibling of the player (never its parent), so
            // it can't cause the player to be recreated.
            child: Stack(
              alignment: Alignment.center,
              children: [
                _buildPlayer(url, startAt),
                if (student != null)
                  Positioned.fill(
                    child: ContentWatermark(
                      studentName: student.fullName,
                      studentPhone: student.mobile,
                      opacity: 0.06,
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (hasPdf && !_showPdf)
          Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.sm,
              horizontal: AppSpacing.base,
            ),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.picture_as_pdf_rounded, size: 20),
                label: const Text(
                  'عرض ملف المحاضرة',
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 14),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white38),
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                onPressed: () => setState(() => _showPdf = true),
              ),
            ),
          ),
        if (split)
          Expanded(
            child: Column(
              children: [
                Container(
                  color: scheme.surface,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.base,
                    vertical: AppSpacing.xs,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'ملف المحاضرة',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          size: 20,
                          color: scheme.onSurface,
                        ),
                        onPressed: () => setState(() => _showPdf = false),
                        tooltip: 'إغلاق',
                      ),
                    ],
                  ),
                ),
                Expanded(child: LessonPdfView(pdfUrl: pdfUrl)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildPlayer(String? url, Duration startAt) {
    return (url == null || url.isEmpty)
        ? const Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Text(
              'لا يوجد فيديو لهذا الدرس بعد',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Cairo',
                color: AppColors.darkTextSecondary,
                fontSize: 15,
              ),
            ),
          )
        : looksLikeYouTube(url)
        ? _buildYoutube(url, startAt)
        : LecturePlayerChooser(
            videoUrl: url,
            startAt: startAt,
            onReady: (LecturePlaybackHandle handle) {},
            onEnded: () {},
            onFullscreenChanged: (value) {
              if (mounted) setState(() => _fullscreen = value);
            },
            progressReporter: _progressReporter,
          );
  }
}
