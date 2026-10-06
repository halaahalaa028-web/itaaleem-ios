import 'dart:async';

import 'package:flutter/material.dart';
import 'package:itaaleem/core/services/screen_security_service.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';

/// Wrap a screen that shows protected content in this:
///
/// * Android — `FLAG_SECURE` for as long as it's mounted (screenshots and
///   recordings come out black), re-applied when the app resumes, and
///   switched off once the last protected screen is left.
/// * iOS — while the screen is being recorded or mirrored, the content is
///   covered by a notice; a screenshot shows a warning toast. The child stays
///   mounted under the cover, so a playing video keeps its state.
class SecureScreen extends StatefulWidget {
  const SecureScreen({super.key, required this.child, this.enabled = true});

  final Widget child;
  final bool enabled;

  @override
  State<SecureScreen> createState() => _SecureScreenState();
}

class _SecureScreenState extends State<SecureScreen>
    with WidgetsBindingObserver {
  StreamSubscription<SecurityEvent>? _events;
  bool _captured = false;

  @override
  void initState() {
    super.initState();
    if (widget.enabled) _start();
  }

  @override
  void didUpdateWidget(covariant SecureScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled) {
      widget.enabled ? _start() : _stop();
    }
  }

  @override
  void dispose() {
    if (widget.enabled) _stop();
    super.dispose();
  }

  void _start() {
    ScreenSecurityService.enable();
    WidgetsBinding.instance.addObserver(this);
    _captured = ScreenSecurityService.isCaptured;
    _events = ScreenSecurityService.events.listen(_onEvent);
    ScreenSecurityService.refreshCaptured().then((captured) {
      if (mounted && captured != _captured) {
        setState(() => _captured = captured);
      }
    });
  }

  void _stop() {
    ScreenSecurityService.disable();
    WidgetsBinding.instance.removeObserver(this);
    _events?.cancel();
    _events = null;
    _captured = false;
  }

  void _onEvent(SecurityEvent event) {
    if (!mounted) return;
    switch (event) {
      case SecurityEvent.screenRecordingStarted:
        setState(() => _captured = true);
      case SecurityEvent.screenRecordingStopped:
        setState(() => _captured = false);
      case SecurityEvent.screenshot:
        // The app-wide CaptureGuard shows the toast.
        break;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ScreenSecurityService.reapply();
      ScreenSecurityService.refreshCaptured().then((captured) {
        if (mounted && captured != _captured) {
          setState(() => _captured = captured);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return Stack(
      fit: StackFit.expand,
      children: [widget.child, if (_captured) const _CaptureBlockedCover()],
    );
  }
}

/// Opaque notice shown over protected content while the screen is captured.
class _CaptureBlockedCover extends StatelessWidget {
  const _CaptureBlockedCover();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Material(
      color: Colors.black,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.videocam_off_rounded, size: 64, color: scheme.error),
                const SizedBox(height: AppSpacing.base),
                Text(
                  'تم إيقاف العرض',
                  textAlign: TextAlign.center,
                  style: text.titleLarge?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'يُرجى إيقاف تسجيل الشاشة أو مشاركتها لمتابعة المشاهدة',
                  textAlign: TextAlign.center,
                  style: text.bodyMedium?.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
