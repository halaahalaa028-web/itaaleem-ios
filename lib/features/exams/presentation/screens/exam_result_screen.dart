import 'dart:math' as math;

import 'package:itaaleem/app/router/app_router.dart';
import 'package:itaaleem/app/router/route_args.dart';
import 'package:itaaleem/features/exams/domain/entities/exam.dart';
import 'package:itaaleem/features/exams/domain/entities/exam_result.dart';
import 'package:flutter/material.dart';
import 'package:itaaleem/core/widgets/app_shimmer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:itaaleem/core/error/failure.dart';
import 'package:itaaleem/core/widgets/app_error_state.dart';
import 'package:itaaleem/features/exams/presentation/providers/exams_providers.dart';
import 'package:itaaleem/core/theme/app_palette.dart';
import 'package:itaaleem/core/theme/app_radius.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';

/// Shown after `POST /exams/{id}/submit` resolves (or, for a demo attempt,
/// after local grading): an animated percentage ring (green on a pass, red
/// otherwise), the score, the time spent, a صح/غلط list when [result] carries
/// a per-question breakdown, and the way to review the answers.
class ExamResultScreen extends StatelessWidget {
  const ExamResultScreen({
    super.key,
    required this.result,
    this.questions = const [],
    this.answers = const {},
    this.title,
    this.allowReview = true,
  });

  final ExamResult result;

  /// The exam's questions — for each one's text in the breakdown and for the
  /// review screen. Empty when the caller doesn't have them.
  final List<ExamQuestion> questions;
  final Map<int, Object> answers;
  final String? title;
  final bool allowReview;

  static String _formatScore(double value) => value == value.roundToDouble()
      ? value.round().toString()
      : value.toStringAsFixed(1);

  static String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m == 0) return '$s ث';
    return s == 0 ? '$m د' : '$m د $s ث';
  }

  bool get _canReview =>
      allowReview &&
      (result.questionResults.isNotEmpty || result.attemptId != null);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final palette = context.palette;
    final passed = result.isPassed;
    final color = passed ? palette.success : cs.error;
    final correctCount = result.questionResults
        .where((r) => r.isCorrect)
        .length;
    final time = result.timeSpentSeconds;

    if (result.isPending) return _PendingResult(title: title);

    return Scaffold(
      appBar: AppBar(
        title: Text(title ?? 'نتيجة الامتحان'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  children: [
                    _ScoreRing(percentage: result.percentage, color: color),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      passed ? 'مبروك، لقد نجحت! 🎉' : 'لم تحقق درجة النجاح',
                      textAlign: TextAlign.center,
                      style: text.headlineSmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (!passed) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'راجع إجاباتك وحاول مرة أخرى',
                        style: text.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    Row(
                      children: [
                        _Stat(
                          icon: Icons.grading_rounded,
                          label: 'الدرجة',
                          value:
                              '${_formatScore(result.score)} / ${_formatScore(result.totalScore)}',
                        ),
                        if (result.questionResults.isNotEmpty) ...[
                          const SizedBox(width: AppSpacing.md),
                          _Stat(
                            icon: Icons.check_circle_outline_rounded,
                            label: 'إجابات صحيحة',
                            value:
                                '$correctCount من ${result.questionResults.length}',
                          ),
                        ],
                        if (time != null) ...[
                          const SizedBox(width: AppSpacing.md),
                          _Stat(
                            icon: Icons.timer_rounded,
                            label: 'الوقت',
                            value: _formatTime(time),
                          ),
                        ],
                      ],
                    ),
                    if (result.questionResults.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xl),
                      _QuestionBreakdown(
                        questionResults: result.questionResults,
                        questions: questions,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.base),
              child: Column(
                children: [
                  if (_canReview) ...[
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        icon: const Icon(Icons.fact_check_rounded),
                        label: const Text('مراجعة الإجابات'),
                        onPressed: () => context.push<void>(
                          examReviewPath,
                          extra: ExamReviewArgs(
                            title: title,
                            result: result,
                            questions: questions,
                            answers: answers,
                            attemptId: result.attemptId,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => context.canPop()
                              ? context.pop()
                              : context.go(homePath),
                          child: const Text('رجوع للمادة'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: TextButton(
                          onPressed: () => context.go(homePath),
                          child: const Text('الرئيسية'),
                        ),
                      ),
                    ],
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

/// Submitted, but the exam hides results until the teacher publishes them.
class _PendingResult extends StatelessWidget {
  const _PendingResult({this.title});

  final String? title;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(title ?? 'نتيجة الامتحان'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            children: [
              const Spacer(),
              CircleAvatar(
                radius: 48,
                backgroundColor: cs.primaryContainer,
                child: Icon(
                  Icons.task_alt_rounded,
                  size: 52,
                  color: cs.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'تم تسليم الامتحان',
                style: text.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'ستظهر النتيجة بعد أن يعلنها المدرس',
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () =>
                      context.canPop() ? context.pop() : context.go(homePath),
                  child: const Text('رجوع للمادة'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Animated circular percentage.
class _ScoreRing extends StatelessWidget {
  const _ScoreRing({required this.percentage, required this.color});

  final double percentage;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final track = Theme.of(context).colorScheme.surfaceContainerHigh;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: percentage.clamp(0, 100).toDouble()),
      duration: const Duration(milliseconds: 1100),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) => SizedBox(
        width: 180,
        height: 180,
        child: CustomPaint(
          painter: _RingPainter(
            fraction: value / 100,
            color: color,
            track: track,
          ),
          child: Center(
            child: Text(
              '${value.round()}٪',
              style: text.displaySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.fraction,
    required this.color,
    required this.track,
  });

  final double fraction;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 14.0;
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke / 2);
    final base = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    final fg = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke;
    canvas.drawArc(arcRect, 0, 2 * math.pi, false, base);
    if (fraction > 0) {
      canvas.drawArc(arcRect, -math.pi / 2, 2 * math.pi * fraction, false, fg);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction || old.color != color || old.track != track;
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.md,
          horizontal: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          children: [
            Icon(icon, color: cs.primary, size: 22),
            const SizedBox(height: AppSpacing.xs),
            Text(value, textAlign: TextAlign.center, style: text.titleSmall),
            Text(label, style: text.labelSmall),
          ],
        ),
      ),
    );
  }
}

/// صح/غلط per question, shown under the score when the API (or a locally
/// graded demo attempt) sent a breakdown.
class _QuestionBreakdown extends StatelessWidget {
  const _QuestionBreakdown({
    required this.questionResults,
    required this.questions,
  });

  final List<ExamQuestionResult> questionResults;
  final List<ExamQuestion> questions;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < questionResults.length; i++) ...[
            if (i > 0) const Divider(height: 20),
            _QuestionResultRow(
              index: i + 1,
              questionResult: questionResults[i],
              questionText: _questionTextFor(questionResults[i]),
            ),
          ],
        ],
      ),
    );
  }

  String? _questionTextFor(ExamQuestionResult result) {
    for (final question in questions) {
      if (question.id == result.questionId) return question.text;
    }
    return result.questionText;
  }
}

class _QuestionResultRow extends StatelessWidget {
  const _QuestionResultRow({
    required this.index,
    required this.questionResult,
    required this.questionText,
  });

  final int index;
  final ExamQuestionResult questionResult;
  final String? questionText;

  @override
  Widget build(BuildContext context) {
    final correct = questionResult.isCorrect;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          correct ? Icons.check_circle_rounded : Icons.cancel_rounded,
          color: correct
              ? context.palette.success
              : Theme.of(context).colorScheme.error,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            questionText ?? 'سؤال $index',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

/// `/exams/:examId/result/:attemptId` — a past attempt's result, rebuilt from
/// `GET /exam-attempts/{id}/review` (e.g. opened from a notification).
class ExamAttemptResultScreen extends ConsumerWidget {
  const ExamAttemptResultScreen({
    super.key,
    required this.examId,
    required this.attemptId,
  });

  final int examId;
  final int attemptId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final details = ref.watch(examDetailsProvider(examId)).valueOrNull;
    final review = ref.watch(examAttemptReviewProvider(attemptId));
    return review.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('نتيجة الامتحان')),
        body: const ShimmerDetail(heroHeight: 200),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('نتيجة الامتحان')),
        body: AppErrorState(
          message: failureOf(error).message,
          onRetry: () => ref.invalidate(examAttemptReviewProvider(attemptId)),
        ),
      ),
      data: (result) => ExamResultScreen(
        result: result.attemptId != null
            ? result
            : ExamResult(
                score: result.score,
                totalScore: result.totalScore,
                percentage: result.percentage,
                isPassed: result.isPassed,
                questionResults: result.questionResults,
                attemptId: attemptId,
                timeSpentSeconds: result.timeSpentSeconds,
                allowReview: result.allowReview,
                isPending: result.isPending,
              ),
        title: details?.title,
        allowReview: (details?.allowReview ?? true) && result.allowReview,
      ),
    );
  }
}
