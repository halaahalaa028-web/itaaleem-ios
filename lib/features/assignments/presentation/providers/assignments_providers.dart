import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:itaaleem/core/providers/cache_for.dart';
import 'package:itaaleem/features/assignments/data/assignments_remote_data_source.dart';
import 'package:itaaleem/features/assignments/domain/entities/assignment.dart';
import 'package:itaaleem/features/subjects/presentation/providers/subjects_providers.dart';

/// `GET /courses/{subject}/assignments`.
final subjectAssignmentsProvider = FutureProvider.autoDispose
    .family<List<Assignment>, int>((ref, subjectId) {
      return ref.cached(
        () => ref
            .read(assignmentsRemoteDataSourceProvider)
            .getForSubject(subjectId),
      );
    });

/// Every subject's assignments, fetched in parallel; a subject whose call
/// fails is skipped rather than failing the whole list.
final allAssignmentsProvider = FutureProvider.autoDispose<List<Assignment>>((
  ref,
) async {
  final subjects = await ref.watch(subjectsListProvider.future);
  return ref.cached(() async {
    final source = ref.read(assignmentsRemoteDataSourceProvider);
    final lists = await Future.wait(
      subjects.map((s) async {
        try {
          final items = await source.getForSubject(s.id);
          return [
            for (final a in items)
              a.subjectName == null ? a.withSubject(s.name) : a,
          ];
        } catch (_) {
          return const <Assignment>[];
        }
      }),
    );
    return [for (final l in lists) ...l];
  });
});

/// `GET /assignments/{id}`.
final assignmentDetailsProvider = FutureProvider.autoDispose
    .family<Assignment, int>((ref, id) {
      return ref.cached(
        () => ref.read(assignmentsRemoteDataSourceProvider).getDetails(id),
        duration: const Duration(minutes: 1),
      );
    });

/// `GET /assignments/{id}/submission` — `null` until submitted.
final assignmentSubmissionProvider = FutureProvider.autoDispose
    .family<AssignmentSubmission?, int>((ref, id) {
      return ref.read(assignmentsRemoteDataSourceProvider).getSubmission(id);
    });
