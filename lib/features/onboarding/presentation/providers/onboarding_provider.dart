import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _seenKey = 'onboarding_seen';

/// Whether the first-open feature-intro onboarding (search/learn/chat) has
/// already been shown — persisted locally so it only ever appears once per
/// install, ahead of [PermissionsOnboardingScreen] in the splash redirect
/// chain.
class OnboardingController extends AsyncNotifier<bool> {
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

final onboardingSeenProvider =
    AsyncNotifierProvider<OnboardingController, bool>(OnboardingController.new);
