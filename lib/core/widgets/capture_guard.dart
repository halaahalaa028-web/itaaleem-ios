import 'dart:async';

import 'package:flutter/material.dart';
import 'package:itaaleem/app/router/app_router.dart';
import 'package:itaaleem/core/services/screen_security_service.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';
import 'package:itaaleem/core/widgets/app_toast.dart';

/// App-wide capture protection, mounted in `MaterialApp.builder` — above the
/// Navigator, so it also covers dialogs and bottom sheets.
///
/// iOS: while the screen is recorded / mirrored / AirPlayed, the whole app
/// is covered by an opaque black notice. The native side (`AppDelegate`)
/// additionally puts a black `UIWindow` above everything — including native
/// views like the video surface — so this is the Flutter-level fallback.
/// Players pause themselves via [ScreenSecurityService.events] and are not
/// resumed automatically. A screenshot shows a toast.
///
/// Android has no capture events (FLAG_SECURE, per protected screen, makes
/// captures black instead), so this stays transparent there.
class CaptureGuard extends StatefulWidget {
  const CaptureGuard({super.key, required this.child});

  final Widget child;

  @override
  State<CaptureGuard> createState() => _CaptureGuardState();
}

class _CaptureGuardState extends State<CaptureGuard>
    with WidgetsBindingObserver {
  StreamSubscription<SecurityEvent>? _events;
  bool _captured = ScreenSecurityService.isCaptured;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _events = ScreenSecurityService.events.listen(_onEvent);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _events?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Recording may have started/stopped while the app was in background.
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final captured = await ScreenSecurityService.refreshCaptured();
    if (mounted && captured != _captured) setState(() => _captured = captured);
  }

  void _onEvent(SecurityEvent event) {
    if (!mounted) return;
    switch (event) {
      case SecurityEvent.screenRecordingStarted:
        setState(() => _captured = true);
      case SecurityEvent.screenRecordingStopped:
        setState(() => _captured = false);
      case SecurityEvent.screenshot:
        final context = rootNavigatorKey.currentContext;
        if (context != null) {
          AppToast.showError(context, 'التقاط الشاشة غير مسموح');
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Kept mounted underneath so nothing loses its state.
        widget.child,
        if (_captured) const _CaptureBlockedScreen(),
      ],
    );
  }
}

class _CaptureBlockedScreen extends StatelessWidget {
  const _CaptureBlockedScreen();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    // Absorbs every touch — nothing underneath is reachable.
    return Semantics(
      liveRegion: true,
      label: 'تسجيل الشاشة غير مسموح. يرجى إيقاف التسجيل للمتابعة',
      child: AbsorbPointer(
        child: Material(
          color: Colors.black,
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lock_rounded,
                      size: 80,
                      color: scheme.onInverseSurface,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      'تسجيل الشاشة غير مسموح',
                      textAlign: TextAlign.center,
                      style: text.titleLarge?.copyWith(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'يرجى إيقاف التسجيل للمتابعة',
                      textAlign: TextAlign.center,
                      style: text.bodyMedium?.copyWith(
                        fontFamily: 'Cairo',
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
