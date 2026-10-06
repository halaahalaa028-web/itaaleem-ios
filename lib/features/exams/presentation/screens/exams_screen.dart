import 'package:itaaleem/core/widgets/status_badge.dart';
import 'package:itaaleem/core/error/failure.dart';
import 'package:itaaleem/core/theme/app_radius.dart';
import 'package:itaaleem/core/widgets/app_button.dart';
import 'package:itaaleem/core/widgets/app_card.dart';
import 'package:itaaleem/core/widgets/error_view.dart';
import 'package:itaaleem/core/widgets/skeleton_loading.dart';
import 'package:itaaleem/features/auth/presentation/providers/auth_controller.dart';
import 'package:itaaleem/features/exams/domain/entities/exam.dart';
import 'package:itaaleem/features/exams/presentation/providers/exams_providers.dart';
import 'package:itaaleem/app/router/app_router.dart';
import 'package:itaaleem/app/router/route_args.dart';
import 'package:flutter/material.dart';
import 'package:itaaleem/core/widgets/fade_slide_in.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:itaaleem/core/theme/app_palette.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';

class _DummyExam {
  const _DummyExam({
    required this.name,
    required this.subject,
    required this.questions,
    required this.durationMinutes,
    required this.passPercent,
    this.locked = false,
  });

  final String name;
  final String subject;
  final List<ExamQuestion> questions;
  final int durationMinutes;
  final int passPercent;
  final bool locked;

  int get questionCount => questions.length;
}

const _accountingQuestions = [
  ExamQuestion(
    id: 1001,
    text:
        'أي القوائم المالية التالية توضح المركز المالي للمنشأة في لحظة زمنية معينة؟',
    options: [
      ExamOption(id: 1, text: 'قائمة الدخل'),
      ExamOption(id: 2, text: 'الميزانية العمومية', isCorrect: true),
      ExamOption(id: 3, text: 'قائمة التدفقات النقدية'),
      ExamOption(id: 4, text: 'قائمة حقوق الملكية'),
    ],
  ),
  ExamQuestion(
    id: 1002,
    text: 'قاعدة القيد المزدوج تعني أن كل عملية مالية تُسجَّل في:',
    options: [
      ExamOption(id: 1, text: 'حساب واحد فقط'),
      ExamOption(id: 2, text: 'حسابين على الأقل، مدين ودائن', isCorrect: true),
      ExamOption(id: 3, text: 'ثلاثة حسابات دائماً'),
      ExamOption(id: 4, text: 'لا يوجد قاعدة ثابتة'),
    ],
  ),
  ExamQuestion(
    id: 1003,
    text: 'الأصول المتداولة هي أصول يمكن تحويلها إلى نقدية خلال:',
    options: [
      ExamOption(id: 1, text: 'سنة مالية واحدة', isCorrect: true),
      ExamOption(id: 2, text: 'خمس سنوات'),
      ExamOption(id: 3, text: 'عشر سنوات'),
      ExamOption(id: 4, text: 'لا يمكن تحويلها أبداً'),
    ],
  ),
  ExamQuestion(
    id: 1004,
    text: 'حساب "المدينون" يُصنَّف ضمن:',
    options: [
      ExamOption(id: 1, text: 'الخصوم'),
      ExamOption(id: 2, text: 'الأصول', isCorrect: true),
      ExamOption(id: 3, text: 'حقوق الملكية'),
      ExamOption(id: 4, text: 'المصروفات'),
    ],
  ),
];

const _itQuestions = [
  ExamQuestion(
    id: 2001,
    text: 'ما وظيفة نظام التشغيل الأساسية؟',
    options: [
      ExamOption(
        id: 1,
        text: 'إدارة موارد الجهاز وتشغيل البرامج',
        isCorrect: true,
      ),
      ExamOption(id: 2, text: 'تصميم صفحات الويب فقط'),
      ExamOption(id: 3, text: 'طباعة المستندات فقط'),
      ExamOption(id: 4, text: 'لا شيء مما سبق'),
    ],
  ),
  ExamQuestion(
    id: 2002,
    text: 'أي مما يلي يُعتبر لغة برمجة؟',
    options: [
      ExamOption(id: 1, text: 'HTML'),
      ExamOption(id: 2, text: 'Python', isCorrect: true),
      ExamOption(id: 3, text: 'CSS'),
      ExamOption(id: 4, text: 'JSON'),
    ],
  ),
  ExamQuestion(
    id: 2003,
    text: 'الشبكة المحلية التي تربط أجهزة داخل مبنى واحد تُسمى:',
    options: [
      ExamOption(id: 1, text: 'WAN'),
      ExamOption(id: 2, text: 'LAN', isCorrect: true),
      ExamOption(id: 3, text: 'VPN'),
      ExamOption(id: 4, text: 'MAN'),
    ],
  ),
];

const _mathQuestions = [
  ExamQuestion(
    id: 3001,
    text: 'ما ناتج مشتقة الدالة f(x) = x²؟',
    options: [
      ExamOption(id: 1, text: 'x'),
      ExamOption(id: 2, text: '2x', isCorrect: true),
      ExamOption(id: 3, text: 'x²'),
      ExamOption(id: 4, text: '2x²'),
    ],
  ),
  ExamQuestion(
    id: 3002,
    text: 'ناتج جمع المصفوفتين يتطلب أن يكون لهما نفس:',
    options: [
      ExamOption(id: 1, text: 'الأبعاد', isCorrect: true),
      ExamOption(id: 2, text: 'المحدد'),
      ExamOption(id: 3, text: 'القطر الرئيسي'),
      ExamOption(id: 4, text: 'لا شرط لذلك'),
    ],
  ),
];

const _dummyExams = [
  _DummyExam(
    name: 'محاسبة مالية — نص الترم',
    subject: 'محاسبة مالية',
    questions: _accountingQuestions,
    durationMinutes: 10,
    passPercent: 60,
  ),
  _DummyExam(
    name: 'تكنولوجيا المعلومات — نص الترم',
    subject: 'تكنولوجيا المعلومات',
    questions: _itQuestions,
    durationMinutes: 8,
    passPercent: 60,
  ),
  _DummyExam(
    name: 'رياضيات — اختبار سريع',
    subject: 'رياضيات تطبيقية',
    questions: _mathQuestions,
    durationMinutes: 5,
    passPercent: 60,
  ),
  _DummyExam(
    name: 'محاسبة مالية — آخر الترم',
    subject: 'محاسبة مالية',
    questions: _accountingQuestions,
    durationMinutes: 20,
    passPercent: 60,
    locked: true,
  ),
];

/// Demo ("دخول تجريبي") attempt: no exam id, no network — [ExamTakingScreen]
/// grades [exam.questions] locally from each option's own [isCorrect] flag.
void _startDemoExam(BuildContext context, _DummyExam exam) {
  context.push<void>(
    examTakingPath,
    extra: ExamTakingArgs(
      examId: null,
      title: exam.name,
      durationMinutes: exam.durationMinutes,
      questions: exam.questions,
      passPercentage: exam.passPercent,
    ),
  );
}

/// Real attempt: opens [ExamDetailsScreen] (`/exams/:id`), whose own "بدء
/// الامتحان" fetches `GET /exams/{id}/questions` and pushes
/// [ExamTakingScreen].
void _startRealExam(BuildContext context, int examId) {
  context.push('/exams/$examId');
}

/// A demo ("دخول تجريبي") session renders the old dummy list exactly as
/// before (now with a real, locally-graded exam-taking flow); a real
/// session loads `GET /exams`.
class ExamsScreen extends ConsumerWidget {
  /// With a [subjectId] only that subject's exams are listed
  /// (`GET /exams?subject_id=`); without one, every exam the student has.
  const ExamsScreen({super.key, this.subjectId});

  final int? subjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDemo = ref.watch(isDemoSessionProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'الامتحانات',
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: isDemo
          ? const _DemoExamsList()
          : _RealExamsList(subjectId: subjectId),
    );
  }
}

class _DemoExamsList extends StatelessWidget {
  const _DemoExamsList();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: _dummyExams.length,
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppSpacing.listItemSpacing),
      itemBuilder: (context, index) => KeyedSubtree(
        key: ValueKey(index),
        child: FadeSlideIn.staggered(
          index: index,
          child: _ExamCard(
            exam: _dummyExams[index],
            onStart: () => _startDemoExam(context, _dummyExams[index]),
          ),
        ),
      ),
    );
  }
}

class _RealExamsList extends ConsumerWidget {
  const _RealExamsList({this.subjectId});

  final int? subjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = subjectId;
    final examsAsync = id == null
        ? ref.watch(examsListProvider)
        : ref.watch(subjectExamsProvider(id));

    return examsAsync.when(
      loading: () => const SingleChildScrollView(
        padding: EdgeInsets.all(AppSpacing.lg),
        physics: NeverScrollableScrollPhysics(),
        child: SkeletonList(count: 5),
      ),
      error: (error, _) => ErrorView(
        message: failureOf(error).message,
        retryLabel: 'إعادة المحاولة',
        onRetry: () => id == null
            ? ref.invalidate(examsListProvider)
            : ref.invalidate(subjectExamsProvider(id)),
      ),
      data: (exams) => exams.isEmpty
          ? Center(
              child: Text(
                'مفيش امتحانات متاحة حالياً',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.palette.textSecondary,
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: exams.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(height: AppSpacing.listItemSpacing),
              itemBuilder: (context, index) => KeyedSubtree(
                key: ValueKey(exams[index].id),
                child: FadeSlideIn.staggered(
                  index: index,
                  child: _RealExamCard(
                    exam: exams[index],
                    onStart: () => _startRealExam(context, exams[index].id),
                  ),
                ),
              ),
            ),
    );
  }
}

class _RealExamCard extends ConsumerWidget {
  const _RealExamCard({required this.exam, required this.onStart});

  final ExamSummary exam;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The best past attempt (highest score), if any.
    final attempts = ref.watch(examResultsProvider(exam.id)).valueOrNull;
    final best = (attempts == null || attempts.isEmpty)
        ? null
        : attempts.reduce((a, b) => a.percentage >= b.percentage ? a : b);
    return AppCard(
      child: Opacity(
        opacity: exam.isLocked ? 0.6 : 1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: context.palette.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(
                    Icons.edit_note_rounded,
                    color: context.palette.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exam.title,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (exam.subjectName != null)
                        Text(
                          exam.subjectName!,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: context.palette.textSecondary),
                        ),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _InfoChip(label: '${exam.questionsCount} سؤال'),
                          if (exam.durationMinutes != null)
                            _InfoChip(label: '${exam.durationMinutes} دقيقة'),
                          _InfoChip(label: 'نجاح: ${exam.passPercentage}%'),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                _AttemptBadge(best: best),
                const Spacer(),
                if (best != null && best.id > 0) ...[
                  TextButton(
                    onPressed: () => context.push<void>(
                      examReviewPath,
                      extra: ExamReviewArgs(
                        title: exam.title,
                        attemptId: best.id,
                      ),
                    ),
                    child: const Text('مراجعة'),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                ],
                if (exam.isLocked)
                  Text(
                    'مقفول 🔒',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: context.palette.textTertiary,
                    ),
                  )
                else
                  AppButton.primary(
                    best == null ? 'ابدأ الامتحان' : 'إعادة المحاولة',
                    expand: false,
                    onPressed: onStart,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// لم يُحَل (grey) / ناجح (green) / راسب (red) + the best score.
class _AttemptBadge extends StatelessWidget {
  const _AttemptBadge({required this.best});

  final ExamAttemptSummary? best;

  @override
  Widget build(BuildContext context) {
    final best = this.best;
    if (best == null) {
      return const StatusBadge(
        type: StatusType.locked,
        label: 'لم يُحَل',
        showIcon: false,
      );
    }
    final pct = '${best.percentage.round()}٪';
    return best.isPassed
        ? StatusBadge(type: StatusType.success, label: 'ناجح • $pct')
        : StatusBadge(type: StatusType.error, label: 'راسب • $pct');
  }
}

class _ExamCard extends StatelessWidget {
  const _ExamCard({required this.exam, required this.onStart});

  final _DummyExam exam;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Opacity(
        opacity: exam.locked ? 0.6 : 1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: context.palette.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(
                    Icons.edit_note_rounded,
                    color: context.palette.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exam.name,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        exam.subject,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.palette.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _InfoChip(label: '${exam.questionCount} سؤال'),
                          _InfoChip(label: '${exam.durationMinutes} دقيقة'),
                          _InfoChip(label: 'نجاح: ${exam.passPercent}%'),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                const Spacer(),
                if (exam.locked)
                  Text(
                    'مقفول 🔒',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.palette.textTertiary,
                    ),
                  )
                else
                  AppButton.primary(
                    'ابدأ الامتحان',
                    expand: false,
                    onPressed: onStart,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: context.palette.primarySurface,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: context.palette.primary),
      ),
    );
  }
}
