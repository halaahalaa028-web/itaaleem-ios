import 'package:itaaleem/app/router/app_router.dart';
import 'package:itaaleem/core/widgets/error_view.dart';
import 'package:itaaleem/features/subjects/presentation/screens/lesson_video_screen.dart';
import 'package:itaaleem/features/video/data/offline/offline_database.dart';
import 'package:itaaleem/features/video/data/offline/offline_download_manager.dart';
import 'package:itaaleem/features/video/presentation/providers/downloads_providers.dart';
import 'package:flutter/material.dart';
import 'package:itaaleem/core/widgets/fade_slide_in.dart';
import 'package:itaaleem/core/widgets/app_shimmer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:itaaleem/core/theme/app_palette.dart';
import 'package:itaaleem/core/theme/app_radius.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';

/// "المحمّلات": every lecture video downloaded for offline playback
/// (`OfflineDatabase.watchAll`, live). Opening a completed one plays it
/// straight from disk via [LecturePlayerScreen]'s `forceOffline` flag,
/// skipping the online/offline prompt [PrivateServerPlaybackResolver] would
/// otherwise show.
class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videosAsync = ref.watch(downloadedVideosProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('المحمّلات')),
      body: videosAsync.when(
        loading: () => const ShimmerList(count: 4, thumbnailSize: 64),
        error: (error, _) => ErrorView(
          message: 'تعذر تحميل قائمة المحمّلات',
          retryLabel: 'إعادة المحاولة',
          onRetry: () => ref.invalidate(downloadedVideosProvider),
        ),
        data: (videos) => videos.isEmpty
            ? const _EmptyState()
            : ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.base),
                itemCount: videos.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: AppSpacing.md),
                itemBuilder: (context, index) => KeyedSubtree(
                  key: ValueKey(videos[index].lessonId),
                  child: FadeSlideIn.staggered(
                    index: index,
                    child: _DownloadRow(video: videos[index]),
                  ),
                ),
              ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: context.palette.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.download_for_offline_rounded,
                size: 38,
                color: context.palette.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text(
              'لا توجد محاضرات محمّلة',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'حمّل محاضراتك من شاشة تشغيل الفيديو لمشاهدتها بدون إنترنت',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                color: context.palette.textSecondary,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DownloadRow extends ConsumerWidget {
  const _DownloadRow({required this.video});

  final OfflineVideo video;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف التحميل'),
        content: Text('هل تريد حذف "${video.lessonTitle}" من المحمّلات؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: context.palette.error),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref
          .read(offlineDownloadManagerProvider)
          .deleteDownload(video.lessonId);
    }
  }

  void _play(BuildContext context) {
    // No `videoUrl`: `LessonVideoScreen` finds the completed local copy by
    // lesson id and plays it from disk, with no network involved.
    context.push<void>(
      lessonVideoPath,
      extra: LessonVideoArgs(
        title: video.lessonTitle.isNotEmpty ? video.lessonTitle : 'محاضرة',
        videoUrl: null,
        lessonId: video.lessonId,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manager = ref.read(offlineDownloadManagerProvider);
    final status = video.downloadStatus;
    final title = video.lessonTitle.isNotEmpty ? video.lessonTitle : 'محاضرة';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: context.palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _statusColor(context, status).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  _statusIcon(status),
                  color: _statusColor(context, status),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (video.subjectName.isNotEmpty) video.subjectName,
                        _statusLabel(video),
                        if (status == 'completed')
                          _formatBytes(video.encryptedSize),
                      ].join(' • '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11,
                        color: context.palette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (status == 'downloading' ||
              status == 'queued' ||
              status == 'paused') ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.xs),
              child: LinearProgressIndicator(
                value: video.downloadProgress,
                minHeight: 4,
                backgroundColor: context.palette.surfaceVariant,
                valueColor: AlwaysStoppedAnimation(context.palette.primary),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _actionButton(status, manager, context)),
              const SizedBox(width: AppSpacing.sm),
              IconButton(
                onPressed: () => _delete(context, ref),
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: context.palette.error,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionButton(
    String status,
    OfflineDownloadManager manager,
    BuildContext context,
  ) {
    switch (status) {
      case 'completed':
        return FilledButton.icon(
          onPressed: () => _play(context),
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('تشغيل'),
          style: FilledButton.styleFrom(
            backgroundColor: context.palette.primary,
          ),
        );
      case 'downloading':
      case 'queued':
        return OutlinedButton.icon(
          onPressed: () => manager.pauseDownload(video.lessonId),
          icon: const Icon(Icons.pause_rounded),
          label: const Text('إيقاف مؤقت'),
        );
      case 'paused':
        return OutlinedButton.icon(
          onPressed: () => manager.resumeDownload(video.lessonId),
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('متابعة'),
        );
      case 'failed':
        return OutlinedButton.icon(
          onPressed: () => manager.retryDownload(video.lessonId),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('إعادة المحاولة'),
          style: OutlinedButton.styleFrom(
            foregroundColor: context.palette.error,
          ),
        );
      case 'expired':
      default:
        return OutlinedButton.icon(
          onPressed: null,
          icon: const Icon(Icons.lock_clock_rounded),
          label: Text(status == 'expired' ? 'انتهت الصلاحية' : status),
        );
    }
  }

  String _statusLabel(OfflineVideo video) {
    switch (video.downloadStatus) {
      case 'downloading':
        return '...جاري التحميل ${(video.downloadProgress * 100).round()}٪';
      case 'queued':
        return 'في الانتظار';
      case 'paused':
        return 'متوقف مؤقتاً ${(video.downloadProgress * 100).round()}٪';
      case 'completed':
        return 'مكتمل';
      case 'failed':
        return video.lastError?.isNotEmpty == true
            ? 'فشل — ${video.lastError}'
            : 'فشل التحميل';
      case 'expired':
        return 'انتهت الصلاحية';
      default:
        return video.downloadStatus;
    }
  }

  IconData _statusIcon(String status) {
    return switch (status) {
      'completed' => Icons.check_circle_rounded,
      'downloading' || 'queued' => Icons.downloading_rounded,
      'paused' => Icons.pause_circle_rounded,
      'failed' => Icons.error_rounded,
      'expired' => Icons.lock_clock_rounded,
      _ => Icons.movie_rounded,
    };
  }

  Color _statusColor(BuildContext context, String status) {
    return switch (status) {
      'completed' => context.palette.success,
      'failed' || 'expired' => context.palette.error,
      _ => context.palette.primary,
    };
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 MB';
    const units = ['B', 'KB', 'MB', 'GB'];
    var value = bytes.toDouble();
    var unitIndex = 0;
    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex++;
    }
    return '${value.toStringAsFixed(value >= 10 || unitIndex == 0 ? 0 : 1)} ${units[unitIndex]}';
  }
}
