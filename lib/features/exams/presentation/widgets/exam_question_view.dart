import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:itaaleem/core/widgets/app_shimmer.dart';
import 'package:itaaleem/core/theme/app_palette.dart';
import 'package:itaaleem/core/theme/app_radius.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';
import 'package:itaaleem/features/exams/domain/entities/exam.dart';

/// Review information for one question (correct answer + the student's).
class QuestionReview {
  const QuestionReview({
    required this.isCorrect,
    this.correctOptionIds = const {},
    this.explanation,
  });

  final bool isCorrect;
  final Set<int> correctOptionIds;
  final String? explanation;
}

/// One exam question: text, optional image, then options (multiple choice /
/// true-false) or a text field (short answer).
///
/// Taking mode: [onSelectOption]/[onTextChanged] are set. Review mode:
/// [review] is set — options are read-only, the correct ones green, the
/// student's wrong pick red, and the explanation shown below.
class ExamQuestionView extends StatelessWidget {
  const ExamQuestionView({
    super.key,
    required this.question,
    required this.index,
    required this.total,
    this.selectedOptionId,
    this.textAnswer,
    this.onSelectOption,
    this.onTextChanged,
    this.review,
  });

  final ExamQuestion question;
  final int index;
  final int total;
  final int? selectedOptionId;
  final String? textAnswer;
  final ValueChanged<int>? onSelectOption;
  final ValueChanged<String>? onTextChanged;
  final QuestionReview? review;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final review = this.review;
    final typeLabel = question.isShortAnswer
        ? 'إجابة قصيرة'
        : question.isTrueFalse
        ? 'صح أم خطأ'
        : 'اختيار من متعدد';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'سؤال ${index + 1} من $total',
                style: text.labelMedium?.copyWith(color: cs.primary),
              ),
              const Spacer(),
              Text(
                '$typeLabel • ${_marks(question.marks)}',
                style: text.labelSmall,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            question.text,
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (question.imageUrl != null && question.imageUrl!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.image),
              child: CachedNetworkImage(
                imageUrl: question.imageUrl!,
                fit: BoxFit.contain,
                placeholder: (_, _) => const AppShimmer(
                  child: ShimmerBlock(height: 160, radius: AppRadius.image),
                ),
                errorWidget: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          if (question.isShortAnswer)
            _ShortAnswer(
              initial: textAnswer,
              onChanged: onTextChanged,
              review: review,
            )
          else
            for (final option in question.options) ...[
              _OptionTile(
                option: option,
                selected: option.id == selectedOptionId,
                onTap: onSelectOption == null || review != null
                    ? null
                    : () => onSelectOption!(option.id),
                state: review == null
                    ? _OptionState.normal
                    : review.correctOptionIds.contains(option.id)
                    ? _OptionState.correct
                    : option.id == selectedOptionId
                    ? _OptionState.wrong
                    : _OptionState.normal,
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          if (review != null) ...[
            if (!question.isShortAnswer && selectedOptionId == null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Text(
                  'لم تُجب على هذا السؤال',
                  style: text.bodySmall?.copyWith(color: cs.error),
                ),
              ),
            if (review.explanation != null && review.explanation!.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(AppSpacing.base),
                decoration: BoxDecoration(
                  color: cs.tertiaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lightbulb_outline_rounded,
                      color: cs.onTertiaryContainer,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'الشرح',
                            style: text.labelLarge?.copyWith(
                              color: cs.onTertiaryContainer,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            review.explanation!,
                            style: text.bodyMedium?.copyWith(
                              color: cs.onTertiaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  static String _marks(double m) {
    final v = m == m.roundToDouble() ? m.round().toString() : m.toString();
    return m == 1 ? 'درجة واحدة' : '$v درجات';
  }
}

enum _OptionState { normal, correct, wrong }

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.option,
    required this.selected,
    required this.onTap,
    required this.state,
  });

  final ExamOption option;
  final bool selected;
  final VoidCallback? onTap;
  final _OptionState state;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final palette = context.palette;
    final (
      Color border,
      Color fill,
      IconData icon,
      Color iconColor,
    ) = switch (state) {
      _OptionState.correct => (
        palette.success,
        palette.successLight,
        Icons.check_circle_rounded,
        palette.success,
      ),
      _OptionState.wrong => (
        cs.error,
        cs.errorContainer,
        Icons.cancel_rounded,
        cs.error,
      ),
      _OptionState.normal when selected => (
        cs.primary,
        cs.primary.withValues(alpha: 0.12),
        Icons.radio_button_checked_rounded,
        cs.primary,
      ),
      _OptionState.normal => (
        Colors.transparent,
        cs.surfaceContainerHighest,
        Icons.radio_button_unchecked_rounded,
        cs.onSurfaceVariant,
      ),
    };
    return Material(
      color: fill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: border, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.base),
          child: Row(
            children: [
              Icon(icon, color: iconColor),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  option.text,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShortAnswer extends StatefulWidget {
  const _ShortAnswer({this.initial, this.onChanged, this.review});

  final String? initial;
  final ValueChanged<String>? onChanged;
  final QuestionReview? review;

  @override
  State<_ShortAnswer> createState() => _ShortAnswerState();
}

class _ShortAnswerState extends State<_ShortAnswer> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final review = widget.review;
    if (review != null) {
      final palette = context.palette;
      final cs = Theme.of(context).colorScheme;
      final answer = widget.initial?.trim() ?? '';
      final color = review.isCorrect ? palette.success : cs.error;
      return Container(
        padding: const EdgeInsets.all(AppSpacing.base),
        decoration: BoxDecoration(
          color: review.isCorrect ? palette.successLight : cs.errorContainer,
          border: Border.all(color: color, width: 1.5),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Row(
          children: [
            Icon(
              review.isCorrect
                  ? Icons.check_circle_rounded
                  : Icons.cancel_rounded,
              color: color,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                answer.isEmpty ? 'لم تُجب على هذا السؤال' : answer,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      );
    }
    return TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      minLines: 3,
      maxLines: 6,
      textInputAction: TextInputAction.newline,
      decoration: const InputDecoration(hintText: 'اكتب إجابتك هنا'),
    );
  }
}
