import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Fires whenever the shared Dio client sees a 403 whose message indicates
/// the student's joined center itself was deactivated (as opposed to an
/// ordinary permission 403) — see [ErrorMappingInterceptor]. Consumed by
/// [centerDeactivatedProvider], which turns this one-shot event into the
/// sticky gate [AppRouter] redirects on.
class CenterDeactivatedEvents {
  final _controller = StreamController<void>.broadcast();

  Stream<void> get stream => _controller.stream;

  void notify() => _controller.add(null);

  void dispose() => _controller.close();
}

final centerDeactivatedEventsProvider = Provider<CenterDeactivatedEvents>((
  ref,
) {
  final events = CenterDeactivatedEvents();
  ref.onDispose(events.dispose);
  return events;
});

final centerDeactivatedStreamProvider = StreamProvider<void>((ref) {
  return ref.watch(centerDeactivatedEventsProvider).stream;
});
