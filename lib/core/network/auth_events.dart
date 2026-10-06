import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Fires once whenever the shared Dio client sees a 401 from an
/// authenticated endpoint outside login/register/the startup session
/// restore (`ErrorMappingInterceptor` skips those three — each already
/// handles its own 401 locally without a global logout). [App] listens via
/// [unauthorizedStreamProvider] and force-logs-out, since this core network
/// layer can't depend on the auth feature directly.
class UnauthorizedEvents {
  final _controller = StreamController<void>.broadcast();

  Stream<void> get stream => _controller.stream;

  void notify() => _controller.add(null);

  void dispose() => _controller.close();
}

final unauthorizedEventsProvider = Provider<UnauthorizedEvents>((ref) {
  final events = UnauthorizedEvents();
  ref.onDispose(events.dispose);
  return events;
});

final unauthorizedStreamProvider = StreamProvider<void>((ref) {
  return ref.watch(unauthorizedEventsProvider).stream;
});
