import 'dart:async';

import 'package:itaaleem/core/services/exam_history_service.dart';
import 'package:itaaleem/core/utils/result.dart';
import 'package:itaaleem/core/widgets/app_toast.dart';
import 'package:itaaleem/features/exams/domain/entities/exam.dart';
import 'package:itaaleem/features/exams/domain/entities/exam_result.dart';
import 'package:itaaleem/features/exams/presentation/providers/exams_providers.dart';
import 'package:itaaleem/features/exams/presentation/widgets/exam_question_view.dart';
import 'package:itaaleem/app/router/app_router.dart';
import 'package:itaaleem/app/router/route_args.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:itaaleem/core/theme/app_radius.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';

/// One question per page (multiple choice, true/false or short answer) with
/// a countdown pill in the app bar (when the exam has a duration), a tappable
/// question navigator, and free navigation between questions. Submits via
/// `POST /exams/{id}/submit` on "تسليم" (after a confirmation listing the
/// unanswered questions) or automatically when the time runs out.
///
/// The countdown runs from a fixed deadline (the server's `started_at` when
/// it sent one), so backgrounding the app doesn't pause it.
///
/// A `null` [examId] means a demo ("دخول تجريبي") exam — [questions] then
/// carry each option's real [ExamOption.isCorrect] flag, and submitting
/// grades locally instead of calling the network.
class ExamTakingScreen extends ConsumerStatefulWidget {
  const ExamTakingScreen({
    super.key,
    required this.examId,
    required this.title,
    required this.durationMinutes,
    required this.questions,
    this.passPercentage,
    this.attemptId,
    this.startedAt,
    this.allowReview = true,
  });

  final int? examId;
  final String title;
  final int? durationMinutes;
  final List<ExamQuestion> questions;

  /// Only used to grade a demo attempt locally — a real submit's pass/fail
  /// verdict always comes from the server.
  final int? passPercentage;
  final int? attemptId;
  final DateTime? startedAt;
  final bool allowReview;

  @override
  ConsumerState<ExamTakingScreen> createState() => _ExamTakingScreenState();
}

class _ExamTakingScreenState extends ConsumerState<ExamTakingScreen> {
  final _pageController = PageController();

  /// Question id → selected option id (`int`) or typed answer (`String`).
  final Map<int, Object> _answers = {};
  int _currentIndex = 0;
  Timer? _ticker;
  DateTime? _deadline;
  Duration? _remaining;
  late final DateTime _openedAt = widget.startedAt ?? DateTime.now();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final minutes = widget.durationMinutes;
    if (minutes != null && minutes > 0) {
      _deadline = _openedAt.add(Duration(minutes: minutes));
      _remaining = _deadline!.difference(DateTime.now());
      _ticker = Timer.periodic(const Duration(seconds: 1), _onTick);
    }
  }

  void _onTick(Timer timer) {
    final deadline = _deadline;
    if (deadline == null || !mounted) return;
    final remaining = deadline.difference(DateTime.now());
    if (remaining <= Duration.zero) {
      timer.cancel();
      setState(() => _remaining = Duration.zero);
      AppToast.showError(context, 'انتهى الوقت — جاري تسليم إجاباتك');
      _submit();
      return;
    }
    setState(() => _remaining = remaining);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  bool _isAnswered(ExamQuestion q) {
    final a = _answers[q.id];
    return a is int || (a is String && a.trim().isNotEmpty);
  }

  int get _answeredCount => widget.questions.where(_isAnswered).length;

  void _goToQuestion(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _confirmSubmit() async {
    final unanswered = widget.questions.length - _answeredCount;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تسليم الامتحان'),
        content: Text(
          unanswered > 0
              ? 'هل أنت متأكد؟ لديك $unanswered سؤال بدون إجابة.'
              : 'هل أنت متأكد من تسليم الامتحان؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('تسليم'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await _submit();
  }

  /// Grades a demo attempt locally from each question's real
  /// [ExamOption.isCorrect] flag — no network call, since a demo session
  /// has no exam id the server would recognize.
  ExamResult _gradeLocally() {
    var correct = 0;
    final questionResults = <ExamQuestionResult>[];
    for (final question in widget.questions) {
      final selected = _answers[question.id];
      final correctOption = question.options
          .where((o) => o.isCorrect)
          .firstOrNull;
      final isCorrect = selected is int && selected == correctOption?.id;
      if (isCorrect) correct++;
      questionResults.add(
        ExamQuestionResult(
          questionId: question.id,
          isCorrect: isCorrect,
          selectedOptionId: selected is int ? selected : null,
          correctOptionId: correctOption?.id,
          answerText: selected is String ? selected : null,
        ),
      );
    }
    final total = widget.questions.length;
    final percentage = total > 0 ? correct / total * 100 : 0.0;
    return ExamResult(
      score: correct.toDouble(),
      totalScore: total.toDouble(),
      percentage: percentage,
      isPassed: percentage >= (widget.passPercentage ?? 60),
      questionResults: questionResults,
      timeSpentSeconds: _timeSpentSeconds,
    );
  }

  int get _timeSpentSeconds {
    final spent = DateTime.now().difference(_openedAt).inSeconds;
    final limit = widget.durationMinutes;
    return limit != null && limit > 0 ? spent.clamp(0, limit * 60) : spent;
  }

  void _openResult(ExamResult result) {
    _ticker?.cancel();
    context.pushReplacement(
      examResultPath,
      extra: ExamResultArgs(
        result: result,
        questions: widget.questions,
        answers: Map.of(_answers),
        title: widget.title,
        allowReview: widget.allowReview && result.allowReview,
      ),
    );
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);

    final examId = widget.examId;
    if (examId == null) {
      final result = _gradeLocally();
      if (!mounted) return;
      setState(() => _submitting = false);
      _openResult(result);
      return;
    }

    final answers = {
      for (final entry in _answers.entries)
        if (entry.value is int || (entry.value as String).trim().isNotEmpty)
          entry.key: entry.value is String
              ? (entry.value as String).trim()
              : entry.value,
    };
    final useCase = ref.read(submitExamUseCaseProvider);
    final result = await useCase(
      examId,
      answers,
      attemptId: widget.attemptId,
      timeSpentSeconds: _timeSpentSeconds,
      booleanQuestionIds: {
        for (final q in widget.questions)
          if (q.syntheticBooleanOptions) q.id,
      },
    );
    if (!mounted) return;
    setState(() => _submitting = false);

    switch (result) {
      case Ok<ExamResult>(:final value):
        if (!value.isPending) {
          ref
              .read(examHistoryServiceProvider)
              .record(
                ExamAttemptRecord(
                  examId: examId,
                  passed: value.isPassed,
                  percentage: value.percentage,
                  takenAt: DateTime.now(),
                ),
              );
        }
        ref.invalidate(examResultsProvider(examId));
        ref.invalidate(examDetailsProvider(examId));
        ref.invalidate(examsListProvider);
        ref.invalidate(subjectExamsProvider);
        ref.invalidate(examBestScoreProvider(examId));
        _openResult(
          value.timeSpentSeconds == null
              ? ExamResult(
                  score: value.score,
                  totalScore: value.totalScore,
                  percentage: value.percentage,
                  isPassed: value.isPassed,
                  questionResults: value.questionResults,
                  attemptId: value.attemptId ?? widget.attemptId,
                  timeSpentSeconds: _timeSpentSeconds,
                  allowReview: value.allowReview,
                  isPending: value.isPending,
                )
              : value,
        );
      case Err<ExamResult>(:final failure):
        AppToast.showError(
          context,
          failure.message.isNotEmpty
              ? failure.message
              : 'تعذر تسليم الامتحان، حاول مرة أخرى',
        );
    }
  }

  Future<bool> _confirmLeave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('الخروج من الامتحان'),
        content: const Text('إذا خرجت الآن ستفقد إجاباتك. هل تريد المتابعة؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('البقاء'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('خروج'),
          ),
        ],
      ),
    );
    return leave ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final questions = widget.questions;
    final remaining = _remaining;
    final cs = Theme.of(context).colorScheme;
    final isLast = _currentIndex >= questions.length - 1;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (await _confirmLeave() && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          centerTitle: false,
          title: Text(
            widget.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            if (questions.isNotEmpty)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
                child: Center(
                  child: Text(
                    '${_currentIndex + 1}/${questions.length}',
                    textDirection: TextDirection.ltr,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            if (remaining != null)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: AppSpacing.md),
                child: Center(child: _TimerPill(remaining: remaining)),
              ),
          ],
        ),
        body: Column(
          children: [
            _QuestionNavigator(
              count: questions.length,
              current: _currentIndex,
              isAnswered: (i) => _isAnswered(questions[i]),
              onTap: _goToQuestion,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.full),
                child: LinearProgressIndicator(
                  minHeight: 4,
                  value: questions.isEmpty
                      ? 0
                      : _answeredCount / questions.length,
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: questions.length,
                onPageChanged: (index) => setState(() => _currentIndex = index),
                itemBuilder: (context, index) {
                  final question = questions[index];
                  final answer = _answers[question.id];
                  return ExamQuestionView(
                    key: ValueKey(question.id),
                    question: question,
                    index: index,
                    total: questions.length,
                    selectedOptionId: answer is int ? answer : null,
                    textAnswer: answer is String ? answer : null,
                    onSelectOption: (optionId) =>
                        setState(() => _answers[question.id] = optionId),
                    onTextChanged: (value) =>
                        setState(() => _answers[question.id] = value),
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.base),
                child: Row(
                  children: [
                    if (_currentIndex > 0) ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _goToQuestion(_currentIndex - 1),
                          icon: const Icon(Icons.arrow_back_rounded),
                          label: const Text('السابق'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                    ],
                    Expanded(
                      child: !isLast
                          ? FilledButton.icon(
                              onPressed: () => _goToQuestion(_currentIndex + 1),
                              icon: const Icon(Icons.arrow_forward_rounded),
                              label: const Text('التالي'),
                            )
                          : FilledButton(
                              onPressed: _submitting ? null : _confirmSubmit,
                              child: _submitting
                                  ? SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: cs.onPrimary,
                                      ),
                                    )
                                  : const Text('تسليم الامتحان'),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Countdown pill; turns red in the last minute.
class _TimerPill extends StatelessWidget {
  const _TimerPill({required this.remaining});

  final Duration remaining;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final urgent = remaining.inSeconds < 60;
    final fg = urgent ? cs.error : cs.onPrimaryContainer;
    final h = remaining.inHours;
    final m = remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: urgent ? cs.error.withValues(alpha: 0.15) : cs.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_rounded, size: 18, color: fg),
          const SizedBox(width: AppSpacing.xs),
          Text(
            h > 0 ? '$h:$m:$s' : '$m:$s',
            textDirection: TextDirection.ltr,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Numbered circles: current question outlined, answered ones filled.
class _QuestionNavigator extends StatelessWidget {
  const _QuestionNavigator({
    required this.count,
    required this.current,
    required this.isAnswered,
    required this.onTap,
  });

  final int count;
  final int current;
  final bool Function(int) isAnswered;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base,
          vertical: AppSpacing.sm,
        ),
        itemCount: count,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, i) {
          final answered = isAnswered(i);
          final active = i == current;
          return InkWell(
            customBorder: const CircleBorder(),
            onTap: () => onTap(i),
            child: Container(
              width: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: answered ? cs.primary : cs.surfaceContainerHighest,
                border: Border.all(
                  color: active
                      ? (answered ? cs.onSurface : cs.primary)
                      : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Text(
                '${i + 1}',
                style: text.labelLarge?.copyWith(
                  color: answered ? cs.onPrimary : cs.onSurfaceVariant,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
