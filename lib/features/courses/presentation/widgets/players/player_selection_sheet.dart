import 'package:flutter/material.dart';
import 'package:itaaleem/core/theme/app_radius.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';
import 'package:itaaleem/features/courses/presentation/widgets/players/lecture_playback_handle.dart';
import 'package:itaaleem/features/courses/presentation/widgets/players/playback_progress_reporter.dart';
import 'package:itaaleem/features/courses/presentation/widgets/players/chewie_youtube_player.dart';
import 'package:itaaleem/features/courses/presentation/widgets/players/youtube_webview_player.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The two ways a YouTube lecture can be played. Only these labels and
/// captions are ever shown — never a package or technical name.
enum YoutubePlayerKind {
  /// YouTube's IFrame player (privacy-enhanced embed) in a WebView.
  webview(
    'المشغل الأساسي',
    'تشغيل مباشر بجودة عالية',
    Icons.play_circle_fill_rounded,
  ),

  /// Native video player with streams resolved on the device. (media_kit
  /// is not a YouTube option; it still plays direct server videos.)
  native('المشغل البديل', 'مشغل بديل', Icons.slow_motion_video_rounded);

  const YoutubePlayerKind(this.label, this.caption, this.icon);

  final String label;
  final String caption;
  final IconData icon;
}

/// Remembers the last player the student picked (the default next time).
class PlayerKindPrefs {
  static const _key = 'youtube_player_kind';

  static Future<YoutubePlayerKind> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString(_key);
      // Older choices: the removed "advanced" WebView (`webviewHd`) is now
      // the basic player; the old media_kit option (`mediaKit`) and
      // anything unknown fall back to it too.
      if (name == 'webviewHd') {
        await prefs.setString(_key, YoutubePlayerKind.webview.name);
      }
      return YoutubePlayerKind.values.firstWhere(
        (k) => k.name == name,
        orElse: () => YoutubePlayerKind.webview,
      );
    } catch (_) {
      return YoutubePlayerKind.webview;
    }
  }

  static Future<void> save(YoutubePlayerKind kind) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, kind.name);
    } catch (_) {}
  }
}

/// Bottom sheet listing the two players; [current] is marked as the
/// default. Returns the choice, or `null` if dismissed.
Future<YoutubePlayerKind?> showPlayerSelectionSheet(
  BuildContext context, {
  required YoutubePlayerKind current,
  YoutubePlayerKind? failed,
}) {
  return showModalBottomSheet<YoutubePlayerKind>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) {
      final scheme = Theme.of(context).colorScheme;
      final text = Theme.of(context).textTheme;
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'اختر المشغل',
              style: text.titleMedium?.copyWith(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            for (final kind in YoutubePlayerKind.values)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Material(
                  color: kind == current
                      ? scheme.primaryContainer
                      : scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    leading: Icon(
                      kind.icon,
                      color: kind == current
                          ? scheme.onPrimaryContainer
                          : scheme.primary,
                    ),
                    title: Text(
                      '▶ ${kind.label}',
                      style: text.titleSmall?.copyWith(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      kind == failed ? 'لم يعمل هذه المرة' : kind.caption,
                    ),
                    trailing: kind == current
                        ? Icon(
                            Icons.check_circle_rounded,
                            color: scheme.primary,
                          )
                        : null,
                    onTap: () => Navigator.of(context).pop(kind),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}

/// Asks which player to use **before** a YouTube video opens (the saved one
/// is ticked) and remembers the answer. `null` when dismissed — the caller
/// then doesn't open the video.
Future<YoutubePlayerKind?> pickYoutubePlayer(BuildContext context) async {
  final saved = await PlayerKindPrefs.load();
  if (!context.mounted) return null;
  final picked = await showPlayerSelectionSheet(context, current: saved);
  if (picked != null) await PlayerKindPrefs.save(picked);
  return picked;
}

/// Plays a YouTube lecture with whichever player the student picks: the
/// selection sheet opens first (the remembered player pre-selected), and
/// again from "جرّب مشغل تاني" when the chosen one fails. Direct server
/// videos never come here — they go straight to media_kit.
class YoutubeMultiPlayer extends StatefulWidget {
  const YoutubeMultiPlayer({
    super.key,
    required this.rawIdOrUrl,
    required this.startAt,
    required this.title,
    required this.onReady,
    required this.onEnded,
    required this.onFullscreenChanged,
    this.thumbnailUrl,
    this.progressReporter,
    this.initialKind,
  });

  /// Already picked (via [pickYoutubePlayer]) before navigating — then the
  /// sheet isn't shown again; otherwise it opens first.
  final YoutubePlayerKind? initialKind;

  final String rawIdOrUrl;
  final Duration startAt;
  final String title;
  final ValueChanged<LecturePlaybackHandle> onReady;
  final VoidCallback onEnded;
  final ValueChanged<bool> onFullscreenChanged;
  final String? thumbnailUrl;
  final ProgressReporter? progressReporter;

  @override
  State<YoutubeMultiPlayer> createState() => _YoutubeMultiPlayerState();
}

class _YoutubeMultiPlayerState extends State<YoutubeMultiPlayer> {
  YoutubePlayerKind _saved = YoutubePlayerKind.webview;
  YoutubePlayerKind? _kind;
  YoutubePlayerKind? _failedKind;
  int _attempt = 0;

  /// While the selection sheet is up during a switch, no player is mounted
  /// (the old one is fully torn down first).
  bool _stopped = false;
  bool _switching = false;
  bool _fullscreen = false;

  /// The mounted player's handle, and where the next player starts.
  LecturePlaybackHandle? _handle;
  late Duration _resumeAt = widget.startAt;

  @override
  void initState() {
    super.initState();
    final kind = widget.initialKind;
    if (kind != null) {
      _saved = kind;
      _kind = kind;
      _attempt = 1;
    } else {
      _chooseInitial();
    }
  }

  Future<void> _chooseInitial() async {
    _saved = await PlayerKindPrefs.load();
    if (!mounted) return;
    final picked = await showPlayerSelectionSheet(context, current: _saved);
    if (!mounted) return;
    if (picked != null) {
      _saved = picked;
      PlayerKindPrefs.save(picked);
    }
    setState(() {
      _kind = picked ?? _saved;
      _attempt++;
    });
  }

  /// "تغيير المشغل" / "جرّب مشغل تاني": remember the position, tear the
  /// current player down completely, then ask, then start the new player
  /// from that position. Dismissing the sheet resumes the same player.
  Future<void> _switchPlayer() async {
    if (_switching) return;
    _switching = true;
    try {
      // 1. Where the student is.
      final position = _currentPosition();
      if (position > Duration.zero) _resumeAt = position;
      _handle = null;
      // 2. Leave fullscreen and unmount the current player (its dispose
      //    stops playback and releases the decoder / WebView).
      if (_fullscreen) _onFullscreenChanged(false);
      setState(() => _stopped = true);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      // 3. Ask.
      final picked = await showPlayerSelectionSheet(
        context,
        current: _kind ?? _saved,
        failed: _failedKind,
      );
      if (!mounted) return;
      if (picked != null) {
        _saved = picked;
        PlayerKindPrefs.save(picked);
      }
      // 4. Start the chosen (or the same) player from that position.
      setState(() {
        _kind = picked ?? _kind;
        _failedKind = picked == null ? _failedKind : null;
        _stopped = false;
        _attempt++;
      });
    } finally {
      _switching = false;
    }
  }

  Duration _currentPosition() {
    try {
      return _handle?.position ?? Duration.zero;
    } catch (_) {
      return Duration.zero;
    }
  }

  void _onFailed() {
    if (!mounted) return;
    final position = _currentPosition();
    if (position > Duration.zero) _resumeAt = position;
    _handle = null;
    if (_fullscreen) _onFullscreenChanged(false);
    setState(() => _failedKind = _kind);
  }

  void _onFullscreenChanged(bool value) {
    _fullscreen = value;
    widget.onFullscreenChanged(value);
  }

  void _onReady(LecturePlaybackHandle handle) {
    _handle = handle;
    widget.onReady(handle);
  }

  void _retrySame() {
    setState(() {
      _failedKind = null;
      _attempt++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final kind = _kind;
    if (kind == null || _stopped) {
      return const AspectRatio(
        aspectRatio: 16 / 9,
        child: ColoredBox(
          color: Colors.black,
          child: Center(child: CircularProgressIndicator(color: Colors.white)),
        ),
      );
    }
    if (_failedKind != null) return _failure(context);

    final key = ValueKey('${kind.name}-$_attempt');
    final player = switch (kind) {
      YoutubePlayerKind.native => ChewieYoutubePlayer(
        key: key,
        rawIdOrUrl: widget.rawIdOrUrl,
        startAt: _resumeAt,
        progressReporter: widget.progressReporter,
        onReady: _onReady,
        onEnded: widget.onEnded,
        onFailed: _onFailed,
      ),
      YoutubePlayerKind.webview => YoutubeWebviewPlayer(
        key: key,
        rawIdOrUrl: widget.rawIdOrUrl,
        startAt: _resumeAt,
        title: widget.title,
        thumbnailUrl: widget.thumbnailUrl,
        progressReporter: widget.progressReporter,
        onReady: _onReady,
        onEnded: widget.onEnded,
        onFullscreenChanged: _onFullscreenChanged,
        onFailed: _onFailed,
      ),
    };
    return Stack(
      fit: StackFit.passthrough,
      children: [
        player,
        PositionedDirectional(
          top: 4,
          start: 4,
          child: IconButton(
            tooltip: 'تغيير المشغل',
            style: IconButton.styleFrom(
              backgroundColor: Colors.black45,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.swap_horiz_rounded),
            onPressed: _switchPlayer,
          ),
        ),
      ],
    );
  }

  Widget _failure(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ColoredBox(
        color: Colors.black,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'تعذر تشغيل الفيديو بـ${_failedKind!.label}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Cairo',
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  alignment: WrapAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: _switchPlayer,
                      icon: const Icon(Icons.swap_horiz_rounded),
                      label: const Text('جرّب مشغل تاني'),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _retrySame,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
