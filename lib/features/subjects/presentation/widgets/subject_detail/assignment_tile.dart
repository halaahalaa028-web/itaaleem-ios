import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:itaaleem/core/theme/app_palette.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';
import 'package:itaaleem/core/widgets/status_badge.dart';
import 'package:itaaleem/features/assignments/domain/entities/assignment.dart';
import 'package:itaaleem/features/subjects/presentation/widgets/subject_detail/subject_section.dart';

/// One assignment: title, due date and its status (لم يُسلم / متأخر /
/// تم التسليم / تم التقييم).
class AssignmentTile extends StatelessWidget {
  const AssignmentTile({super.key, required this.assignment, this.onTap});

  final Assignment assignment;
  final VoidCallback? onTap;

  String _num(num n) => n % 1 == 0 ? n.toInt().toString() : n.toString();

  @override
  Widget build(BuildContext context) {
    final a = assignment;
    final palette = context.palette;
    final graded = a.score != null;

    final (StatusBadge badge, Color iconColor) = graded
        ? (
            StatusBadge(
              type: StatusType.completed,
              label: a.maxScore == null
                  ? 'تم التقييم'
                  : '${_num(a.score!)}/${_num(a.maxScore!)}',
            ),
            palette.success,
          )
        : a.isSubmitted
        ? (
            const StatusBadge(type: StatusType.info, label: 'تم التسليم'),
            palette.info,
          )
        : a.isOverdue
        ? (
            const StatusBadge(type: StatusType.error, label: 'متأخر'),
            palette.error,
          )
        : (
            const StatusBadge(type: StatusType.pending, label: 'لم يُسلم'),
            palette.warning,
          );

    return SubjectTileShell(
      onTap: onTap,
      child: Row(
        children: [
          SubjectTileIcon(icon: Icons.assignment_rounded, color: iconColor),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  a.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: subjectTileTitleStyle,
                ),
                if (a.dueDate != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  SubjectTileMeta(
                    icon: Icons.event_rounded,
                    label:
                        'التسليم: ${DateFormat('d MMM yyyy', 'ar').format(a.dueDate!.toLocal())}',
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          badge,
        ],
      ),
    );
  }
}
