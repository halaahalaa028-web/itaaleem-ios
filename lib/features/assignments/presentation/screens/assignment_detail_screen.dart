import 'package:flutter/material.dart';
import 'package:itaaleem/core/utils/open_file_in_app.dart';
import 'package:itaaleem/core/widgets/app_card.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:itaaleem/core/error/failure.dart';
import 'package:itaaleem/core/widgets/app_toast.dart';
import 'package:itaaleem/core/widgets/error_view.dart';
import 'package:itaaleem/core/widgets/skeleton_loading.dart';
import 'package:itaaleem/features/assignments/data/assignments_remote_data_source.dart';
import 'package:itaaleem/features/assignments/domain/entities/assignment.dart';
import 'package:itaaleem/features/assignments/presentation/providers/assignments_providers.dart';

import 'package:itaaleem/core/theme/app_palette.dart';
import 'package:itaaleem/core/theme/app_radius.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';

/// One assignment: instructions, the student's submission state, and a
/// file upload (`POST /assignments/{id}/submit`, multipart).
class AssignmentDetailScreen extends ConsumerStatefulWidget {
  const AssignmentDetailScreen({super.key, required this.assignmentId});

  final int assignmentId;

  @override
  ConsumerState<AssignmentDetailScreen> createState() =>
      _AssignmentDetailScreenState();
}

class _AssignmentDetailScreenState
    extends ConsumerState<AssignmentDetailScreen> {
  final _notes = TextEditingController();
  XFile? _file;
  bool _submitting = false;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 2400,
      );
      if (picked != null && mounted) setState(() => _file = picked);
    } catch (_) {
      if (mounted) AppToast.showError(context, 'تعذر اختيار الملف');
    }
  }

  Future<void> _submit() async {
    final file = _file;
    if (file == null) {
      AppToast.showError(context, 'اختار ملف الحل الأول');
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref
          .read(assignmentsRemoteDataSourceProvider)
          .submit(widget.assignmentId, filePath: file.path, notes: _notes.text);
      if (!mounted) return;
      ref.invalidate(assignmentSubmissionProvider(widget.assignmentId));
      ref.invalidate(assignmentDetailsProvider(widget.assignmentId));
      ref.invalidate(allAssignmentsProvider);
      ref.invalidate(subjectAssignmentsProvider);
      setState(() {
        _file = null;
        _notes.clear();
      });
      AppToast.showSuccess(context, 'تم تسليم الواجب بنجاح');
    } catch (e) {
      if (mounted) AppToast.showError(context, failureOf(e).message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.assignmentId;
    final details = ref.watch(assignmentDetailsProvider(id));
    final submission = ref.watch(assignmentSubmissionProvider(id));
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('تفاصيل الواجب')),
      body: details.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: SkeletonList(count: 3),
        ),
        error: (e, _) => ErrorView(
          message: failureOf(e).message,
          retryLabel: 'إعادة المحاولة',
          onRetry: () => ref.invalidate(assignmentDetailsProvider(id)),
        ),
        data: (a) {
          final sub = submission.valueOrNull;
          final submitted = sub != null || a.isSubmitted;
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.cardPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a.title,
                      style: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (a.subjectName != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        a.subjectName!,
                        style: text.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      children: [
                        if (a.dueDate != null)
                          _Meta(
                            icon: Icons.event_rounded,
                            label:
                                'الموعد: ${DateFormat('d MMM yyyy - h:mm a', 'ar').format(a.dueDate!)}',
                            color: a.isOverdue ? scheme.error : null,
                          ),
                        if (a.maxScore != null)
                          _Meta(
                            icon: Icons.star_rounded,
                            label: 'الدرجة: ${a.maxScore}',
                          ),
                      ],
                    ),
                    if (a.description != null &&
                        a.description!.trim().isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.base),
                      Text(a.description!, style: text.bodyMedium),
                    ],
                    if (a.attachmentUrl != null) ...[
                      const SizedBox(height: AppSpacing.base),
                      OutlinedButton.icon(
                        onPressed: () => openFileInApp(
                          context,
                          a.attachmentUrl,
                          title: 'ملف الواجب',
                        ),
                        icon: const Icon(Icons.attach_file_rounded),
                        label: const Text('ملف الواجب'),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.base),
              if (submitted) _SubmissionCard(submission: sub, assignment: a),
              if (!submitted || (sub != null && !sub.isGraded)) ...[
                if (submitted) const SizedBox(height: AppSpacing.base),
                _UploadCard(
                  title: submitted ? 'إعادة التسليم' : 'تسليم الحل',
                  file: _file,
                  notes: _notes,
                  submitting: _submitting,
                  onPickGallery: () => _pick(ImageSource.gallery),
                  onPickCamera: () => _pick(ImageSource.camera),
                  onClear: () => setState(() => _file = null),
                  onSubmit: _submit,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: c),
        const SizedBox(width: AppSpacing.xs),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: c),
        ),
      ],
    );
  }
}

class _SubmissionCard extends StatelessWidget {
  const _SubmissionCard({required this.submission, required this.assignment});

  final AssignmentSubmission? submission;
  final Assignment assignment;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final sub = submission;
    final score = sub?.score ?? assignment.score;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: context.palette.success.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.task_alt_rounded,
                  color: context.palette.success,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'تم تسليم الواجب',
                      style: text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (sub?.submittedAt != null)
                      Text(
                        DateFormat(
                          'd MMM yyyy - h:mm a',
                          'ar',
                        ).format(sub!.submittedAt!.toLocal()),
                        style: text.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              if (score != null)
                Text(
                  assignment.maxScore != null
                      ? '$score / ${assignment.maxScore}'
                      : '$score',
                  style: text.titleMedium?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
          if (sub?.feedback != null && sub!.feedback!.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Text(sub.feedback!, style: text.bodyMedium),
            ),
          ],
        ],
      ),
    );
  }
}

class _UploadCard extends StatelessWidget {
  const _UploadCard({
    required this.title,
    required this.file,
    required this.notes,
    required this.submitting,
    required this.onPickGallery,
    required this.onPickCamera,
    required this.onClear,
    required this.onSubmit,
  });

  final String title;
  final XFile? file;
  final TextEditingController notes;
  final bool submitting;
  final VoidCallback onPickGallery;
  final VoidCallback onPickCamera;
  final VoidCallback onClear;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.md),
          if (file == null)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: submitting ? null : onPickGallery,
                    icon: const Icon(Icons.photo_library_rounded),
                    label: const Text('من المعرض'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: submitting ? null : onPickCamera,
                    icon: const Icon(Icons.photo_camera_rounded),
                    label: const Text('تصوير'),
                  ),
                ),
              ],
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                children: [
                  Icon(Icons.image_rounded, color: scheme.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      file!.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodyMedium,
                    ),
                  ),
                  IconButton(
                    onPressed: submitting ? null : onClear,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: notes,
            enabled: !submitting,
            maxLines: 3,
            decoration: const InputDecoration(hintText: 'ملاحظات (اختياري)'),
          ),
          const SizedBox(height: AppSpacing.base),
          FilledButton.icon(
            onPressed: submitting ? null : onSubmit,
            icon: submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.upload_rounded),
            label: Text(submitting ? 'جاري الرفع...' : 'إرسال الحل'),
          ),
        ],
      ),
    );
  }
}
