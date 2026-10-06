import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:itaaleem/features/auth/presentation/providers/auth_controller.dart';
import 'package:itaaleem/features/center/presentation/providers/center_providers.dart';

// ignore: deprecated_member_use
extension CacheFor on AutoDisposeRef<Object?> {
  /// Runs [load] and, only if it succeeds, keeps the result for [duration]
  /// after the last listener goes away so re-opening a screen doesn't
  /// refetch. A failure (e.g. a 403 before the student is activated) is
  /// never cached — the next watch retries.
  ///
  /// Also watches the logged-in student's id and joined center/grade, so a
  /// login as someone else or a join/leave/grade switch reloads everything
  /// straight away.
  Future<T> cached<T>(
    FutureOr<T> Function() load, {
    Duration duration = const Duration(minutes: 5),
  }) async {
    watch(authControllerProvider.select((s) => s.valueOrNull?.id));
    watch(
      centerMembershipProvider.select(
        (s) => (s.valueOrNull?.centerId, s.valueOrNull?.gradeId),
      ),
    );
    final result = await load();
    final link = keepAlive();
    final timer = Timer(duration, link.close);
    onDispose(timer.cancel);
    return result;
  }
}
