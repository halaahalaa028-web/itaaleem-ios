import 'dart:async';

import 'package:flutter/material.dart';
import 'package:itaaleem/core/theme/app_palette.dart';
import 'package:itaaleem/core/theme/app_radius.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';

enum _ToastKind { success, error }

/// Top-anchored success/error toast, replacing the default bottom
/// [SnackBar] everywhere in the app — inserted directly into the root
/// [Overlay] so it isn't tied to any particular [Scaffold] and always
/// appears near the top of the screen, below the status bar.
///
/// A soft card tinted with the semantic color (opaque, so it stays legible
/// over any content) with a solid icon badge — colors come from the active
/// theme, so it follows dark mode.
class AppToast {
  AppToast._();

  static void showSuccess(
    BuildContext context,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    _show(
      context,
      message,
      kind: _ToastKind.success,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  static void showError(BuildContext context, String message) {
    _show(context, message, kind: _ToastKind.error);
  }

  static void _show(
    BuildContext context,
    String message, {
    required _ToastKind kind,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    late final OverlayEntry entry;
    final removed = Completer<void>();
    entry = OverlayEntry(
      builder: (context) => _ToastCard(
        message: message,
        kind: kind,
        actionLabel: actionLabel,
        onAction: onAction,
        onDismissed: () {
          if (!removed.isCompleted) removed.complete();
          entry.remove();
        },
      ),
    );
    overlay.insert(entry);
  }
}

class _ToastCard extends StatefulWidget {
  const _ToastCard({
    required this.message,
    required this.kind,
    required this.onDismissed,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final _ToastKind kind;
  final VoidCallback onDismissed;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  State<_ToastCard> createState() => _ToastCardState();
}

class _ToastCardState extends State<_ToastCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _autoDismissTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.medium,
      reverseDuration: const Duration(milliseconds: 180),
    );
    _controller.forward();
    _autoDismissTimer = Timer(
      Duration(seconds: widget.actionLabel != null ? 6 : 3),
      _dismiss,
    );
  }

  Future<void> _dismiss() async {
    _autoDismissTimer?.cancel();
    if (!mounted) return;
    await _controller.reverse();
    widget.onDismissed();
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = context.palette;
    final (Color accent, IconData icon) = switch (widget.kind) {
      _ToastKind.success => (palette.success, Icons.check_rounded),
      _ToastKind.error => (scheme.error, Icons.priority_high_rounded),
    };
    // Opaque tint: the toast floats over arbitrary content.
    final background = Color.alphaBlend(
      accent.withValues(alpha: palette.isDark ? 0.18 : 0.10),
      scheme.surface,
    );
    // Light or dark glyph on the badge, whichever contrasts with [accent].
    final lightTone = palette.isDark ? scheme.onSurface : scheme.surface;
    final darkTone = palette.isDark ? scheme.surface : scheme.onSurface;
    final onAccent =
        ThemeData.estimateBrightnessForColor(accent) == Brightness.dark
        ? lightTone
        : darkTone;

    final curved = CurvedAnimation(
      parent: _controller,
      curve: AppMotion.emphasized,
      reverseCurve: Curves.easeIn,
    );
    return PositionedDirectional(
      top: MediaQuery.paddingOf(context).top + AppSpacing.sm,
      start: AppSpacing.base,
      end: AppSpacing.base,
      child: SafeArea(
        bottom: false,
        child: FadeTransition(
          opacity: _controller,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, -0.5),
              end: Offset.zero,
            ).animate(curved),
            child: Material(
              color: Colors.transparent,
              child: GestureDetector(
                onTap: _dismiss,
                // Swipe up to dismiss early.
                onVerticalDragEnd: (d) {
                  if ((d.primaryVelocity ?? 0) < 0) _dismiss();
                },
                child: Container(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.base,
                    AppSpacing.md,
                  ),
                  decoration: BoxDecoration(
                    color: background,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: accent.withValues(alpha: 0.35)),
                    boxShadow: [
                      BoxShadow(
                        color: scheme.shadow.withValues(
                          alpha: palette.isDark ? 0.4 : 0.12,
                        ),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: onAccent, size: 20),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          widget.message,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: scheme.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                      if (widget.actionLabel != null && widget.onAction != null)
                        TextButton(
                          onPressed: () {
                            widget.onAction!();
                            _dismiss();
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: accent,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: 6,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(widget.actionLabel!),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
