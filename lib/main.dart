import 'dart:async';

import 'package:itaaleem/app/app.dart';
import 'package:itaaleem/core/services/notification_service.dart';
import 'package:itaaleem/features/settings/presentation/providers/theme_mode_provider.dart';
import 'package:itaaleem/features/splash/presentation/providers/app_startup.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

void main() async {
  // Silence every debug log in release builds (logs can leak data and cost
  // time on busy screens).
  if (kReleaseMode) debugPrint = (String? message, {int? wrapWidth}) {};
  WidgetsFlutterBinding.ensureInitialized();
  // Keep the native launch screen up until the Flutter splash's logo is
  // decoded (SplashScreen releases it; it also self-releases after 1.5s).
  FirstFrameGate.hold();
  MediaKit.ensureInitialized();
  // Firebase setup is slow (platform channels) and nothing on the first
  // screens needs it, so it runs in the background instead of delaying the
  // first frame. `NotificationService.getToken` awaits it when needed.
  unawaited(NotificationService.bootstrap());
  final initialThemeMode = await loadStoredThemeMode();
  runApp(
    ProviderScope(
      overrides: [initialThemeModeProvider.overrideWithValue(initialThemeMode)],
      child: const App(),
    ),
  );
}
