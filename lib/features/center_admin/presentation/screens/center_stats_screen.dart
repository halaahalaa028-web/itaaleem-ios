import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:itaaleem/core/error/failure.dart';
import 'package:itaaleem/core/theme/app_radius.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';
import 'package:itaaleem/core/widgets/app_error_state.dart';
import 'package:itaaleem/core/widgets/app_shimmer.dart';
import 'package:itaaleem/features/center_admin/data/center_admin_models.dart';
import 'package:itaaleem/features/center_admin/presentation/widgets/admin_common.dart';
import 'package:itaaleem/features/center_admin/providers/center_admin_providers.dart';

/// `GET /center-admin/stats` — most / least watched videos, 7-day student
/// activity (bar chart), average exam score per subject.
class CenterStatsScreen extends ConsumerWidget {
  const CenterStatsScreen({super.key});

  static const _path = 'stats';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(centerAdminRecordProvider(_path));
    return Scaffold(
      appBar: AppBar(title: const Text('الإحصائيات')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(centerAdminRecordProvider(_path).future),
        child: async.when(
          loading: () => const ShimmerList(count: 6),
          error: (e, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              const SizedBox(height: 80),
              AppErrorState(
                message: failureOf(e).message,
                onRetry: () => ref.invalidate(centerAdminRecordProvider(_path)),
              ),
            ],
          ),
          data: (stats) {
            final activity = [
              ...stats.list('daily_activity'),
              ...stats.list('activity'),
              ...stats.list('students_activity'),
            ];
            final top = [
              ...stats.list('top_videos'),
              ...stats.list('most_watched'),
            ];
            final least = [
              ...stats.list('least_videos'),
              ...stats.list('least_watched'),
            ];
            final exams = [
              ...stats.list('exam_averages'),
              ...stats.list('exams_performance'),
            ];
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                const AdminSectionTitle('نشاط الطلاب — آخر 7 أيام'),
                _Panel(
                  child: activity.isEmpty
                      ? const _NoData()
                      : _BarChart(
                          bars: [
                            for (final d in activity.take(7))
                              (
                                _dayLabel(d),
                                d.number([
                                      'active_students',
                                      'count',
                                      'value',
                                      'students',
                                    ]) ??
                                    0,
                              ),
                          ],
                        ),
                ),
                const AdminSectionTitle('أداء الامتحانات — متوسط كل مادة'),
                _Panel(
                  child: exams.isEmpty
                      ? const _NoData()
                      : Column(
                          children: [
                            for (final e in exams)
                              _MeterRow(
                                label: e.nestedName('subject') ?? e.title,
                                value:
                                    e.number([
                                      'average',
                                      'average_score',
                                      'avg',
                                    ]) ??
                                    0,
                                suffix: '%',
                                max: 100,
                              ),
                          ],
                        ),
                ),
                const AdminSectionTitle('الأكثر مشاهدة'),
                _VideosPanel(videos: top.take(10).toList()),
                const AdminSectionTitle('الأقل مشاهدة'),
                _VideosPanel(videos: least.take(10).toList()),
              ],
            );
          },
        ),
      ),
    );
  }

  static String _dayLabel(AdminRecord d) {
    final date = d.date(['date', 'day']);
    if (date == null) return d.text(['label', 'day']) ?? '';
    const days = ['إثن', 'ثلا', 'أرب', 'خمي', 'جمع', 'سبت', 'أحد'];
    return days[date.weekday - 1];
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      margin: EdgeInsets.zero,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.base),
        child: child,
      ),
    );
  }
}

class _NoData extends StatelessWidget {
  const _NoData();

  @override
  Widget build(BuildContext context) {
    return Text(
      'لا توجد بيانات بعد',
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// A plain vertical bar chart — no chart package needed.
class _BarChart extends StatelessWidget {
  const _BarChart({required this.bars});

  final List<(String, num)> bars;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final max = bars.fold<num>(1, (m, b) => b.$2 > m ? b.$2 : m);
    return SizedBox(
      height: 180,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final (label, value) in bars)
            Expanded(
              child: Semantics(
                label: '$label: $value',
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text('$value', style: text.labelSmall),
                      const SizedBox(height: 4),
                      Flexible(
                        child: FractionallySizedBox(
                          heightFactor: (value / max).clamp(0.02, 1).toDouble(),
                          child: Container(
                            decoration: BoxDecoration(
                              color: scheme.primary,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(AppRadius.sm),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        style: text.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Label + horizontal bar + value.
class _MeterRow extends StatelessWidget {
  const _MeterRow({
    required this.label,
    required this.value,
    required this.max,
    this.suffix = '',
  });

  final String label;
  final num value;
  final num max;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final fraction = max <= 0 ? 0.0 : (value / max).clamp(0, 1).toDouble();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall,
                ),
              ),
              Text(
                '${value % 1 == 0 ? value.toInt() : value.toStringAsFixed(1)}$suffix',
                style: text.labelMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 8,
              backgroundColor: scheme.surfaceContainerHighest,
            ),
          ),
        ],
      ),
    );
  }
}

class _VideosPanel extends StatelessWidget {
  const _VideosPanel({required this.videos});

  final List<AdminRecord> videos;

  @override
  Widget build(BuildContext context) {
    if (videos.isEmpty) return const _Panel(child: _NoData());
    final max = videos
        .map((v) => v.number(['views_count', 'views', 'watch_count']) ?? 0)
        .fold<num>(1, (m, v) => v > m ? v : m);
    return _Panel(
      child: Column(
        children: [
          for (final v in videos)
            _MeterRow(
              label: [
                v.title,
                if (v.nestedName('subject') case final s?) '($s)',
              ].join(' '),
              value: v.number(['views_count', 'views', 'watch_count']) ?? 0,
              max: max,
            ),
        ],
      ),
    );
  }
}
