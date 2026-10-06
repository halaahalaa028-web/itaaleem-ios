import 'package:flutter/material.dart';
import 'package:itaaleem/core/widgets/app_shimmer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:itaaleem/app/router/route_args.dart';
import 'package:itaaleem/core/error/failure.dart';
import 'package:itaaleem/core/theme/app_palette.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';
import 'package:itaaleem/core/widgets/app_empty_state.dart';
import 'package:itaaleem/core/widgets/app_error_state.dart';
import 'package:itaaleem/features/exams/domain/entities/exam.dart';
import 'package:itaaleem/features/exams/domain/entities/exam_result.dart';
import 'package:itaaleem/features/exams/presentation/providers/exams_providers.dart';
import 'package:itaaleem/features/exams/presentation/widgets/exam_question_view.dart';

/// Read-only walk through an attempt, one question per page like the exam
/// itself (no timer): the correct option in green, the student's wrong pick
/// in red, and the explanation when there is one.
///
/// Uses what the result screen already has when it includes the correct
/// answers; otherwise (or for an older attempt) fetches
/// `GET /exam-attempts/{id}/review`.
class ExamReviewScreen extends ConsumerWidget {
  const ExamReviewScreen({super.key, required this.args});

  final ExamReviewArgs args;

  bool get _localHasAnswers {
    final result = args.result;
    if (result == null || result.questionResults.isEmpty) return false;
    return result.questionResults.any(
          (r) => r.correctOptionId != null || r.options.isNotEmpty,
        ) ||
        args.questions.any((q) => q.options.any((o) => o.isCorrect));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attemptId = args.attemptId;
    final title = args.title ?? 'مراجعة الإجابات';

    if (_localHasAnswers || attemptId == null) {
      return _ReviewScaffold(
        title: title,
        items: _buildItems(args.result, args.questions, args.answers),
      );
    }

    final review = ref.watch(examAttemptReviewProvider(attemptId));
    return review.when(
      loading: () => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: const ShimmerDetail(heroHeight: 0, cards: 5),
      ),
      error: (error, _) {
        final local = args.result;
        if (local != null && local.questionResults.isNotEmpty) {
          return _ReviewScaffold(
            title: title,
            items: _buildItems(local, args.questions, args.answers),
          );
        }
        return Scaffold(
          appBar: AppBar(title: Text(title)),
          body: AppErrorState(
            message: failureOf(error).message,
            onRetry: () => ref.invalidate(examAttemptReviewProvider(attemptId)),
          ),
        );
      },
      data: (result) => _ReviewScaffold(
        title: title,
        items: _buildItems(result, args.questions, args.answers),
      ),
    );
  }

  /// Joins the questions the app has with the review data from [result].
  static List<_ReviewItem> _buildItems(
    ExamResult? result,
    List<ExamQuestion> questions,
    Map<int, Object> answers,
  ) {
    final byId = {for (final q in questions) q.id: q};
    final results = result?.questionResults ?? const <ExamQuestionResult>[];
    final resultById = {for (final r in results) r.questionId: r};
    // Exam order when the questions are known, else the review's order.
    final ids = questions.isNotEmpty
        ? questions.map((q) => q.id).toList()
        : results.map((r) => r.questionId).toList();

    return [
      for (final id in ids)
        if (byId[id] != null || resultById[id] != null)
          _itemFor(byId[id], resultById[id], answers[id], id),
    ];
  }

  static _ReviewItem _itemFor(
    ExamQuestion? question,
    ExamQuestionResult? r,
    Object? answer,
    int id,
  ) {
    final options = (r != null && r.options.isNotEmpty)
        ? r.options
        : (question?.options ?? const <ExamOption>[]);
    final type =
        question?.type ??
        (options.isEmpty
            ? ExamQuestionType.shortAnswer
            : ExamQuestionType.multipleChoice);
    final shown = ExamQuestion(
      id: id,
      text: question?.text ?? r?.questionText ?? 'سؤال',
      options: options,
      type: type,
      marks: question?.marks ?? 1,
      imageUrl: question?.imageUrl,
    );
    final correct = {
      for (final o in options)
        if (o.isCorrect) o.id,
      ?r?.correctOptionId,
    };
    final selected = r?.selectedOptionId ?? (answer is int ? answer : null);
    final textAnswer = r?.answerText ?? (answer is String ? answer : null);
    final isCorrect =
        r?.isCorrect ?? (selected != null && correct.contains(selected));
    return _ReviewItem(
      question: shown,
      selectedOptionId: selected,
      textAnswer: textAnswer,
      review: QuestionReview(
        isCorrect: isCorrect,
        correctOptionIds: correct,
        explanation: r?.explanation ?? question?.explanation,
      ),
    );
  }
}

class _ReviewItem {
  const _ReviewItem({
    required this.question,
    required this.review,
    this.selectedOptionId,
    this.textAnswer,
  });

  final ExamQuestion question;
  final QuestionReview review;
  final int? selectedOptionId;
  final String? textAnswer;
}

class _ReviewScaffold extends StatefulWidget {
  const _ReviewScaffold({required this.title, required this.items});

  final String title;
  final List<_ReviewItem> items;

  @override
  State<_ReviewScaffold> createState() => _ReviewScaffoldState();
}

class _ReviewScaffoldState extends State<_ReviewScaffold> {
  final _pageController = PageController();
  int _index = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _go(int index) => _pageController.animateToPage(
    index,
    duration: const Duration(milliseconds: 250),
    curve: Curves.easeOut,
  );

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    final cs = Theme.of(context).colorScheme;
    final palette = context.palette;
    final text = Theme.of(context).textTheme;

    if (items.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: const AppEmptyState(
          icon: Icons.fact_check_rounded,
          title: 'لا توجد إجابات لمراجعتها',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          SizedBox(
            height: 56,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.base,
                vertical: AppSpacing.sm,
              ),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
              itemBuilder: (context, i) {
                final ok = items[i].review.isCorrect;
                final color = ok ? palette.success : cs.error;
                return InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => _go(i),
                  child: Container(
                    width: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withValues(alpha: 0.15),
                      border: Border.all(
                        color: i == _index ? color : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Text(
                      '${i + 1}',
                      style: text.labelLarge?.copyWith(color: color),
                    ),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: items.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) {
                final item = items[i];
                return ExamQuestionView(
                  key: ValueKey(item.question.id),
                  question: item.question,
                  index: i,
                  total: items.length,
                  selectedOptionId: item.selectedOptionId,
                  textAnswer: item.textAnswer,
                  review: item.review,
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
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _index > 0 ? () => _go(_index - 1) : null,
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: const Text('السابق'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _index < items.length - 1
                          ? () => _go(_index + 1)
                          : () => Navigator.of(context).maybePop(),
                      icon: Icon(
                        _index < items.length - 1
                            ? Icons.arrow_forward_rounded
                            : Icons.check_rounded,
                      ),
                      label: Text(
                        _index < items.length - 1 ? 'التالي' : 'إنهاء المراجعة',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
