import 'package:itaaleem/core/utils/result.dart';
import 'package:itaaleem/core/widgets/app_toast.dart';
import 'package:itaaleem/features/activation/presentation/screens/activation_screen.dart';
import 'package:itaaleem/features/courses/presentation/providers/courses_providers.dart';
import 'package:itaaleem/features/home/presentation/providers/home_subjects_provider.dart';
import 'package:flutter/material.dart';
import 'package:itaaleem/features/subscriptions/presentation/widgets/contact_center_access_sheet.dart';
import 'package:itaaleem/core/utils/platform_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:itaaleem/core/theme/app_palette.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';

/// Shown whenever the student taps something that requires an enrollment
/// they don't have yet (a locked lecture, or a catalog course/subject on the
/// home tab): offers either a `POST /courses/{id}/request` enrollment
/// request or code activation.
///
/// Completes with `true` once the enrollment request was sent successfully,
/// and `null` when the sheet was dismissed (or went to code activation).
Future<bool?> showSubscribeRequestSheet(
  BuildContext context, {
  required int courseId,
  String? courseTitle,
}) async {
  // iOS: no subscription request — how to get access instead.
  if (PlatformUtils.hideSubscriptions) {
    await showContactCenterAccessSheet(context);
    return null;
  }
  return showModalBottomSheet<bool>(
    context: context,
    // Draws its own rounded container on a transparent sheet.
    showDragHandle: false,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) =>
        SubscribeRequestSheet(courseId: courseId, courseTitle: courseTitle),
  );
}

class SubscribeRequestSheet extends ConsumerStatefulWidget {
  const SubscribeRequestSheet({
    super.key,
    required this.courseId,
    this.courseTitle,
  });

  final int courseId;
  final String? courseTitle;

  @override
  ConsumerState<SubscribeRequestSheet> createState() =>
      _SubscribeRequestSheetState();
}

class _SubscribeRequestSheetState extends ConsumerState<SubscribeRequestSheet> {
  bool _submitting = false;

  Future<void> _requestEnrollment() async {
    setState(() => _submitting = true);
    final useCase = ref.read(requestEnrollmentUseCaseProvider);
    final result = await useCase(widget.courseId);
    if (!mounted) return;
    setState(() => _submitting = false);

    switch (result) {
      case Ok<String>(:final value):
        // Reload courses/materials immediately so the request (or its
        // "pending" state) shows up on the home tab right away.
        ref.invalidate(coursesProvider);
        ref.invalidate(availableCoursesProvider);
        ref.invalidate(courseDetailsProvider(widget.courseId));
        ref.invalidate(homeSubjectsProvider);
        Navigator.of(context).pop(true);
        AppToast.showSuccess(
          context,
          value.isNotEmpty ? value : 'تم إرسال طلب الاشتراك',
        );
      case Err<String>(:final failure):
        AppToast.showError(
          context,
          failure.message.isNotEmpty
              ? failure.message
              : 'حدث خطأ ما، حاول مرة أخرى',
        );
    }
  }

  void _goActivateCode() {
    Navigator.of(context).pop();
    pushActivationScreen();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(AppSpacing.base),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: context.palette.primary.withValues(alpha: 0.25),
              blurRadius: 30,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsetsDirectional.fromSTEB(24, 28, 24, 24),
              decoration: BoxDecoration(
                gradient: context.palette.brandGradient,
              ),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: context.palette.onPrimary.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: context.palette.onPrimary.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      Icons.lock_rounded,
                      color: context.palette.onPrimary,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.base),
                  Text(
                    widget.courseTitle != null
                        ? 'طلب اشتراك في ${widget.courseTitle}'
                        : 'طلب اشتراك',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: context.palette.onPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'سيتم إرسال طلبك للإدارة وتفعيله قريباً',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.palette.onPrimary.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.all(24),
              child: Column(
                children: [
                  FilledButton(
                    onPressed: _submitting ? null : _requestEnrollment,
                    child: _submitting
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(
                                context.palette.onPrimary,
                              ),
                            ),
                          )
                        : const Text('طلب اشتراك'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: _submitting ? null : _goActivateCode,
                    child: const Text('تفعيل بكود'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
