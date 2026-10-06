import 'package:itaaleem/core/error/failure.dart';
import 'package:itaaleem/features/auth/presentation/providers/auth_controller.dart';
import 'package:itaaleem/features/subjects/data/datasources/subjects_remote_data_source.dart';
import 'package:itaaleem/features/subjects/domain/entities/subject.dart';
import 'package:flutter/material.dart';
import 'package:itaaleem/features/subscriptions/presentation/widgets/contact_center_access_sheet.dart';
import 'package:itaaleem/core/utils/platform_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:itaaleem/core/theme/app_palette.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';

/// Free lessons are never locked, nor is anything in a demo session. Otherwise
/// the lesson's own `is_accessible` from the API decides (it's per-student
/// and per-lesson, so it wins over the profile's general subscription
/// flags); only when the API doesn't send it do those flags decide.
bool isLessonLocked(WidgetRef ref, SubjectLesson lesson) {
  if (lesson.isFree) return false;
  // `has_video: true` with a withheld (null) `video_url`: the video exists
  // but this student needs a subscription for it.
  if (lesson.hasVideo && !lesson.canPlayVideo) return true;
  // Only the three flags this needs, so a profile refresh that changes
  // nothing here doesn't rebuild every lesson card.
  final (loggedIn, isDemo, isActivated) = ref.watch(
    authControllerProvider.select((s) {
      final student = s.valueOrNull;
      return (
        student != null,
        student?.isDemo ?? false,
        student?.isActivated ?? false,
      );
    }),
  );
  if (!loggedIn) return true;
  if (isDemo) return false;
  final accessible = lesson.isAccessible;
  if (accessible != null) return !accessible;
  return !isActivated;
}

/// "هذا المحتوى مدفوع" bottom sheet — its button sends
/// `POST /subscription-requests`, then closes with a success SnackBar.
///
/// Completes with `true` once the request was sent successfully, and `null`
/// when the sheet was just dismissed.
Future<bool?> showPaidContentSheet(
  BuildContext context, {
  int? subjectId,
  int? lessonId,
}) async {
  // iOS: no subscription request — how to get access instead.
  if (PlatformUtils.hideSubscriptions) {
    await showContactCenterAccessSheet(context);
    return null;
  }
  return showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (_) => _PaidContentSheet(subjectId: subjectId, lessonId: lessonId),
  );
}

class _PaidContentSheet extends ConsumerStatefulWidget {
  const _PaidContentSheet({this.subjectId, this.lessonId});

  final int? subjectId;
  final int? lessonId;

  @override
  ConsumerState<_PaidContentSheet> createState() => _PaidContentSheetState();
}

class _PaidContentSheetState extends ConsumerState<_PaidContentSheet> {
  bool _submitting = false;

  Future<void> _submit() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _submitting = true);
    try {
      // `ref` is only touched before the await; everything after uses the
      // navigator/messenger captured up front.
      await ref
          .read(subjectsRemoteDataSourceProvider)
          .requestSubscription(
            subjectId: widget.subjectId,
            lessonId: widget.lessonId,
          );
      // Pop only if this sheet is still the one on screen: if the user
      // already dismissed it (or the sheet was disposed), a blind pop would
      // remove the lesson screen underneath and leave a black screen.
      if (mounted && navigator.canPop()) navigator.pop(true);
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'تم إرسال طلبك بنجاح. سيتم إشعارك عند التفعيل',
            textAlign: TextAlign.center,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(failureOf(error).message, textAlign: TextAlign.center),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_rounded, size: 40, color: context.palette.primary),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'هذا المحتوى مدفوع. هل تريد إرسال طلب اشتراك؟',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('طلب اشتراك'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small green "مجاني" pill shown on free lessons.
class FreeLessonBadge extends StatelessWidget {
  const FreeLessonBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: context.palette.success.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_rounded,
            size: 12,
            color: context.palette.success,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            'مجاني',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: context.palette.success,
            ),
          ),
        ],
      ),
    );
  }
}
