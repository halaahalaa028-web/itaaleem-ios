import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the device currently reports any network connectivity (WiFi or
/// cellular radio up) — not a guarantee the internet is actually reachable,
/// just what [Connectivity] can tell us, per the plan. Emits an initial
/// value from [Connectivity.checkConnectivity] then follows
/// [Connectivity.onConnectivityChanged].
final connectivityStatusProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();
  yield _isOnline(await connectivity.checkConnectivity());
  yield* connectivity.onConnectivityChanged.map(_isOnline);
});

bool _isOnline(List<ConnectivityResult> results) =>
    results.any((result) => result != ConnectivityResult.none);
