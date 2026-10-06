import 'package:itaaleem/core/widgets/app_toast.dart';
import 'package:itaaleem/features/video/data/offline/offline_database.dart';
import 'package:itaaleem/features/video/data/offline/offline_download_manager.dart';
import 'package:itaaleem/features/video/presentation/providers/downloads_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:itaaleem/core/theme/app_palette.dart';
import 'package:itaaleem/core/theme/app_radius.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';

/// "تحميل" control shown under a downloadable lecture's video
/// ([LectureDetails.isDownloadable]) — reflects and drives the lesson's
/// [OfflineVideo] row live, so it stays in sync with "المحمّلات" and with
/// [PrivateServerPlaybackResolver] picking it up automatically once
/// completed.
class LectureDownloadButton extends ConsumerWidget {
  const LectureDownloadButton({
    super.key,
    required this.lectureId,
    required this.subjectName,
    required this.lessonTitle,
    required this.sourceUrl,
  });

  final int lectureId;

  /// The lesson's `video_url` (YouTube link or direct file) to download.
  final String sourceUrl;
  final String subjectName;
  final String lessonTitle;

  Future<void> _start(BuildContext context, WidgetRef ref) async {
    try {
      await ref
          .read(offlineDownloadManagerProvider)
          .startDownload(
            lectureId,
            sourceUrl: sourceUrl,
            subjectName: subjectName,
            lessonTitle: lessonTitle,
          );
    } on DemoModeDownloadException catch (e) {
      if (context.mounted) AppToast.showError(context, e.toString());
    } on InsufficientStorageException catch (e) {
      if (context.mounted) AppToast.showError(context, e.toString());
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف التحميل'),
        content: const Text('هل تريد حذف النسخة المحمّلة من هذه المحاضرة؟'),
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
      await ref.read(offlineDownloadManagerProvider).deleteDownload(lectureId);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rowAsync = ref.watch(offlineVideoByLessonProvider(lectureId));
    final row = rowAsync.valueOrNull;
    final manager = ref.read(offlineDownloadManagerProvider);

    switch (row?.downloadStatus) {
      case 'downloading':
      case 'queued':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Chip(
              icon: Icons.pause_circle_outline_rounded,
              label:
                  '...جاري التحميل ${((row!.downloadProgress) * 100).round()}٪',
              progress: row.downloadProgress,
              onTap: () => manager.pauseDownload(lectureId),
            ),
            const SizedBox(width: AppSpacing.sm),
            _CancelIcon(onTap: () => manager.cancelDownload(lectureId)),
          ],
        );
      case 'paused':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Chip(
              icon: Icons.play_circle_outline_rounded,
              label:
                  'متابعة التحميل ${((row!.downloadProgress) * 100).round()}٪',
              progress: row.downloadProgress,
              onTap: () => manager.resumeDownload(lectureId),
            ),
            const SizedBox(width: AppSpacing.sm),
            _DeleteIcon(onTap: () => _delete(context, ref)),
          ],
        );
      case 'completed':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Chip(
              icon: Icons.check_circle_rounded,
              label: 'تم التحميل',
              color: context.palette.success,
            ),
            const SizedBox(width: AppSpacing.sm),
            _DeleteIcon(onTap: () => _delete(context, ref)),
          ],
        );
      case 'failed':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Chip(
              icon: Icons.error_outline_rounded,
              label: 'فشل التحميل — اضغط لإعادة المحاولة',
              color: context.palette.error,
              onTap: () => manager.retryDownload(lectureId),
            ),
            const SizedBox(width: AppSpacing.sm),
            _DeleteIcon(onTap: () => _delete(context, ref)),
          ],
        );
      case 'expired':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Chip(
              icon: Icons.lock_clock_rounded,
              label: 'انتهت صلاحية التحميل',
              color: context.palette.error,
            ),
            const SizedBox(width: AppSpacing.sm),
            _DeleteIcon(onTap: () => _delete(context, ref)),
          ],
        );
      default:
        return _Chip(
          icon: Icons.download_rounded,
          label: 'تحميل للمشاهدة أوفلاين',
          onTap: () => _start(context, ref),
        );
    }
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.label,
    this.onTap,
    this.color,
    this.progress,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? color;

  /// 0-1, shown as a thin bar under the label while downloading.
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? context.palette.primary;
    // Never wider than the screen minus page padding and the two side icons.
    final maxWidth = (MediaQuery.sizeOf(context).width - 140).clamp(
      120.0,
      360.0,
    );
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: tint.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 16, color: tint),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tint,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              if (progress != null) ...[
                const SizedBox(height: 6),
                SizedBox(
                  width: 140,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 3,
                      backgroundColor: tint.withValues(alpha: 0.15),
                      valueColor: AlwaysStoppedAnimation(tint),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CancelIcon extends StatelessWidget {
  const _CancelIcon({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: context.palette.error.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Icon(
          Icons.close_rounded,
          size: 18,
          color: context.palette.error,
        ),
      ),
    );
  }
}

class _DeleteIcon extends StatelessWidget {
  const _DeleteIcon({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: context.palette.error.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Icon(
          Icons.delete_outline_rounded,
          size: 18,
          color: context.palette.error,
        ),
      ),
    );
  }
}
