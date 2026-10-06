import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:itaaleem/core/error/failure.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';
import 'package:itaaleem/core/widgets/app_button.dart';
import 'package:itaaleem/core/widgets/app_card.dart';
import 'package:itaaleem/core/widgets/app_empty_state.dart';
import 'package:itaaleem/core/widgets/app_input.dart';
import 'package:itaaleem/core/widgets/app_shimmer.dart';
import 'package:itaaleem/features/admin/data/models/admin_models.dart';
import 'package:itaaleem/features/admin/presentation/providers/admin_provider.dart';
import 'package:itaaleem/features/admin/presentation/widgets/admin_widgets.dart';

/// Days in display order (the Egyptian week starts on Saturday), as
/// [AdminSchedule.dayOfWeek] values (0 = Sunday … 6 = Saturday).
const _weekOrder = [6, 0, 1, 2, 3, 4, 5];

const _dayNames = {
  0: 'الأحد',
  1: 'الاثنين',
  2: 'الثلاثاء',
  3: 'الأربعاء',
  4: 'الخميس',
  5: 'الجمعة',
  6: 'السبت',
};

/// [DateTime.weekday] (1 = Monday … 7 = Sunday) → [AdminSchedule.dayOfWeek].
int _todayDayOfWeek() => DateTime.now().weekday % 7;

/// Weekly timetable — one tab per day, today's selected first. Add with the
/// FAB (on the selected day), edit by tapping a slot, delete from its menu.
class AdminScheduleScreen extends ConsumerWidget {
  const AdminScheduleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schedules = ref.watch(adminSchedulesProvider);
    return DefaultTabController(
      length: 7,
      initialIndex: _weekOrder.indexOf(_todayDayOfWeek()),
      child: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('المواعيد والجدول'),
            bottom: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [for (final day in _weekOrder) Tab(text: _dayNames[day])],
            ),
          ),
          floatingActionButton: schedules.hasValue
              ? FloatingActionButton.extended(
                  onPressed: () {
                    final tab = DefaultTabController.of(context).index;
                    _openForm(context, ref, day: _weekOrder[tab]);
                  },
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('إضافة موعد'),
                )
              : null,
          body: schedules.when(
            loading: () => const ShimmerList(count: 4),
            error: (e, _) => AdminErrorView(
              error: e,
              onRetry: () => ref.invalidate(adminSchedulesProvider),
              panelPath: 'schedules',
            ),
            data: (items) => TabBarView(
              children: [
                for (final day in _weekOrder)
                  _DayList(
                    slots: items.where((s) => s.dayOfWeek == day).toList()
                      ..sort((a, b) => a.startTime.compareTo(b.startTime)),
                    onEdit: (s) => _openForm(context, ref, existing: s),
                    onDelete: (s) => _delete(context, ref, s),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Future<void> _openForm(
    BuildContext context,
    WidgetRef ref, {
    int? day,
    AdminSchedule? existing,
  }) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) =>
          _ScheduleForm(existing: existing, initialDay: day ?? 6),
    );
    if (saved == true) ref.invalidate(adminSchedulesProvider);
  }

  static Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    AdminSchedule s,
  ) async {
    final confirmed = await confirmAdminAction(
      context,
      title: 'حذف الموعد',
      message:
          'حذف موعد ${s.subjectName} يوم ${_dayNames[s.dayOfWeek]} ${s.startTime}؟',
      confirmLabel: 'حذف',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    final ok = await runAdminAction(
      context,
      () => ref.read(adminRepositoryProvider).deleteSchedule(s.id),
      successMessage: 'تم حذف الموعد',
    );
    if (ok) ref.invalidate(adminSchedulesProvider);
  }
}

class _DayList extends ConsumerWidget {
  const _DayList({
    required this.slots,
    required this.onEdit,
    required this.onDelete,
  });

  final List<AdminSchedule> slots;
  final ValueChanged<AdminSchedule> onEdit;
  final ValueChanged<AdminSchedule> onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () => ref.refresh(adminSchedulesProvider.future),
      child: slots.isEmpty
          ? const AdminScrollable(
              child: AppEmptyState(
                icon: Icons.event_available_rounded,
                title: 'لا توجد مواعيد في هذا اليوم',
              ),
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenHorizontal,
                AppSpacing.base,
                AppSpacing.screenHorizontal,
                96,
              ),
              itemCount: slots.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: AppSpacing.listItemSpacing),
              itemBuilder: (context, i) => _SlotCard(
                slot: slots[i],
                onEdit: () => onEdit(slots[i]),
                onDelete: () => onDelete(slots[i]),
              ),
            ),
    );
  }
}

class _SlotCard extends StatelessWidget {
  const _SlotCard({
    required this.slot,
    required this.onEdit,
    required this.onDelete,
  });

  final AdminSchedule slot;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final s = slot;
    return AppCard(
      onTap: onEdit,
      child: Row(
        children: [
          Container(
            width: 64,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  s.startTime,
                  style: text.titleSmall?.copyWith(
                    color: cs.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  s.endTime,
                  style: text.bodySmall?.copyWith(
                    color: cs.onPrimaryContainer.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.subjectName.isEmpty
                      ? 'مادة #${s.subjectId}'
                      : s.subjectName,
                  style: text.titleSmall,
                ),
                if (s.teacherName != null)
                  _Line(icon: Icons.person_rounded, text: s.teacherName!),
                if (s.location != null)
                  _Line(icon: Icons.place_rounded, text: s.location!),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'edit', child: Text('تعديل')),
              PopupMenuItem(
                value: 'delete',
                child: Text('حذف', style: TextStyle(color: cs.error)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// Add/edit sheet: subject, teacher, day, start/end time, place.
class _ScheduleForm extends ConsumerStatefulWidget {
  const _ScheduleForm({this.existing, required this.initialDay});

  final AdminSchedule? existing;
  final int initialDay;

  @override
  ConsumerState<_ScheduleForm> createState() => _ScheduleFormState();
}

class _ScheduleFormState extends ConsumerState<_ScheduleForm> {
  late final _teacher = TextEditingController(
    text: widget.existing?.teacherName,
  );
  late final _location = TextEditingController(text: widget.existing?.location);
  late int? _subjectId = widget.existing?.subjectId;
  late int _day = widget.existing?.dayOfWeek ?? widget.initialDay;
  late TimeOfDay? _start = _parse(widget.existing?.startTime);
  late TimeOfDay? _end = _parse(widget.existing?.endTime);
  bool _saving = false;
  String? _error;

  static TimeOfDay? _parse(String? hhmm) {
    final parts = hhmm?.split(':');
    if (parts == null || parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    return h == null || m == null ? null : TimeOfDay(hour: h, minute: m);
  }

  static String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  void dispose() {
    _teacher.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _pickTime({required bool start}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime:
          (start ? _start : _end) ??
          (start
              ? const TimeOfDay(hour: 16, minute: 0)
              : TimeOfDay(hour: ((_start?.hour ?? 16) + 1) % 24, minute: 0)),
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _start = picked;
      } else {
        _end = picked;
      }
      _error = null;
    });
  }

  Future<void> _save() async {
    final start = _start;
    final end = _end;
    if (_subjectId == null || start == null || end == null) {
      setState(() => _error = 'اختر المادة ووقت البداية والنهاية');
      return;
    }
    if (end.hour * 60 + end.minute <= start.hour * 60 + start.minute) {
      setState(() => _error = 'وقت النهاية لازم يكون بعد وقت البداية');
      return;
    }
    final data = {
      'subject_id': _subjectId,
      'teacher_name': _teacher.text.trim().isEmpty
          ? null
          : _teacher.text.trim(),
      'day_of_week': _day,
      'start_time': _fmt(start),
      'end_time': _fmt(end),
      'location': _location.text.trim().isEmpty ? null : _location.text.trim(),
    };
    setState(() => _saving = true);
    final repo = ref.read(adminRepositoryProvider);
    final existing = widget.existing;
    final ok = await runAdminAction(
      context,
      () => existing == null
          ? repo.createSchedule(data)
          : repo.updateSchedule(existing.id, data),
      successMessage: existing == null ? 'تمت إضافة الموعد' : 'تم حفظ التعديل',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final subjects = ref.watch(adminSubjectsProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.screenHorizontal,
        right: AppSpacing.screenHorizontal,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.base,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.existing == null ? 'إضافة موعد' : 'تعديل الموعد',
              style: text.titleMedium,
            ),
            const SizedBox(height: AppSpacing.base),
            subjects.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text(
                failureOf(e).message,
                style: text.bodySmall?.copyWith(color: cs.error),
              ),
              data: (items) => DropdownButtonFormField<int>(
                // Keep a since-deleted subject from crashing the dropdown.
                initialValue: items.any((s) => s.id == _subjectId)
                    ? _subjectId
                    : null,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'المادة'),
                items: [
                  for (final s in items)
                    DropdownMenuItem(value: s.id, child: Text(s.name)),
                ],
                onChanged: (v) => setState(() => _subjectId = v),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppInput(
              label: 'المعلم (اختياري)',
              controller: _teacher,
              prefixIcon: Icons.person_rounded,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<int>(
              initialValue: _day,
              decoration: const InputDecoration(labelText: 'اليوم'),
              items: [
                for (final d in _weekOrder)
                  DropdownMenuItem(value: d, child: Text(_dayNames[d]!)),
              ],
              onChanged: (v) => setState(() => _day = v ?? _day),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickTime(start: true),
                    icon: const Icon(Icons.schedule_rounded),
                    label: Text(_start == null ? 'من' : 'من ${_fmt(_start!)}'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickTime(start: false),
                    icon: const Icon(Icons.schedule_rounded),
                    label: Text(_end == null ? 'إلى' : 'إلى ${_fmt(_end!)}'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            AppInput(
              label: 'المكان (اختياري)',
              hint: 'مثلاً: قاعة 2',
              controller: _location,
              prefixIcon: Icons.place_rounded,
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(_error!, style: text.bodySmall?.copyWith(color: cs.error)),
            ],
            const SizedBox(height: AppSpacing.xl),
            AppButton.primary(
              widget.existing == null ? 'إضافة' : 'حفظ',
              loading: _saving,
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}
