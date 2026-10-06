import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _seenKey = 'permissions_onboarding_seen';

/// Whether the first-open permissions screen has already been shown and
/// acknowledged — persisted locally so it only ever appears once per
/// install, never again after the user has gone through it.
class PermissionsOnboardingController extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_seenKey) ?? false;
  }

  Future<void> markSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_seenKey, true);
    state = const AsyncData(true);
  }
}

final permissionsOnboardingSeenProvider =
    AsyncNotifierProvider<PermissionsOnboardingController, bool>(
      PermissionsOnboardingController.new,
    );
