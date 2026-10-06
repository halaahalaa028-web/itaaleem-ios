import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// Platform-specific product rules.
class PlatformUtils {
  PlatformUtils._();

  static bool get isIOS => !kIsWeb && Platform.isIOS;

  /// Hide subscriptions/payments from the *student* UI (subscribe /
  /// renew / request buttons, prices, packages, the subscriptions screen)
  /// — App Store rules forbid steering to purchases outside In-App
  /// Purchase. `true` on iOS, `false` on Android (unchanged there). The
  /// center-admin dashboard is never affected.
  static bool get hideSubscriptions => isIOS;

  /// iOS sign-up lets the student pick phone *or* email (Android keeps
  /// both fields as before).
  static bool get flexibleSignUp => isIOS;
}

/// What a combined "phone or email" login field contains.
bool looksLikeEmail(String value) => value.trim().contains('@');
