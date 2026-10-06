import 'package:flutter/material.dart';
import 'package:itaaleem/core/theme/app_radius.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';

/// Settings bottom sheet shared by [YoutubeMediaKitPlayer] and
/// [AdvancedDirectPlayer]: playback speed, plus the video qualities when the
/// player has more than nothing to offer. Selecting an option closes the sheet
/// first, then calls back.
class PlayerSettingsSheet extends StatelessWidget {
  const PlayerSettingsSheet({
    super.key,
    required this.currentSpeed,
    required this.onSpeedChanged,
    this.qualities,
    this.currentQuality,
    this.onQualityChanged,
    this.qualityNote,
    this.pendingQuality,
  });

  final double currentSpeed;
  final ValueChanged<double> onSpeedChanged;

  /// Labels of the qualities the source really offers; `null`/empty hides
  /// the section.
  final List<String>? qualities;
  final String? currentQuality;
  final ValueChanged<String>? onQualityChanged;

  /// Optional hint under the qualities (e.g. "the source has nothing higher").
  final String? qualityNote;

  /// A quality still loading in the background (the current one keeps
  /// playing meanwhile) — shown with a small spinner.
  final String? pendingQuality;

  static const speeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

  static String speedLabel(double speed) =>
      speed == 1.0 ? 'عادي' : '${speed}x'.replaceAll('.0x', 'x');

  static Future<void> show(
    BuildContext context, {
    required double currentSpeed,
    required ValueChanged<double> onSpeedChanged,
    List<String>? qualities,
    String? currentQuality,
    ValueChanged<String>? onQualityChanged,
    String? qualityNote,
    String? pendingQuality,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      // Draws its own rounded container + handle on a transparent sheet.
      showDragHandle: false,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PlayerSettingsSheet(
        currentSpeed: currentSpeed,
        onSpeedChanged: onSpeedChanged,
        qualities: qualities,
        currentQuality: currentQuality,
        onQualityChanged: onQualityChanged,
        qualityNote: qualityNote,
        pendingQuality: pendingQuality,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final qualities = this.qualities ?? const <String>[];

    Widget chips<T>(
      List<T> values,
      bool Function(T) isSelected,
      String Function(T) label,
      ValueChanged<T> onTap, {
      bool showCheck = false,
      bool Function(T)? isPending,
      String Function(T, {required bool selected, required bool pending})?
      semanticsLabel,
    }) {
      return Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (final value in values)
            Builder(
              builder: (context) {
                final selected = isSelected(value);
                final pending = isPending?.call(value) ?? false;
                final chip = ChoiceChip(
                  label: Text(label(value)),
                  selected: selected,
                  showCheckmark: false,
                  avatar: pending
                      ? SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: cs.primary,
                          ),
                        )
                      : selected && showCheck
                      ? Icon(Icons.check_rounded, size: 18, color: cs.onPrimary)
                      : null,
                  selectedColor: cs.primary,
                  backgroundColor: cs.surfaceContainerLow,
                  labelStyle: text.labelLarge?.copyWith(
                    color: selected ? cs.onPrimary : cs.onSurface,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.chip),
                  ),
                  side: BorderSide(color: selected ? cs.primary : cs.outline),
                  onSelected: (_) {
                    Navigator.of(context).pop();
                    onTap(value);
                  },
                );
                if (semanticsLabel == null) return chip;
                return Semantics(
                  label: semanticsLabel(
                    value,
                    selected: selected,
                    pending: pending,
                  ),
                  excludeSemantics: true,
                  button: true,
                  selected: selected,
                  child: chip,
                );
              },
            ),
        ],
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.bottomSheet),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.base,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cs.onSurface.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('سرعة التشغيل', style: text.titleMedium),
                const SizedBox(height: AppSpacing.md),
                chips<double>(
                  speeds,
                  (s) => (s - currentSpeed).abs() < 0.01,
                  speedLabel,
                  onSpeedChanged,
                ),
                if (qualities.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xl),
                  Text('جودة الفيديو', style: text.titleMedium),
                  const SizedBox(height: AppSpacing.md),
                  chips<String>(
                    qualities,
                    (q) => q == currentQuality,
                    (q) => q,
                    (q) => onQualityChanged?.call(q),
                    showCheck: true,
                    isPending: (q) => q == pendingQuality,
                    semanticsLabel:
                        (q, {required selected, required pending}) =>
                            'جودة $q${selected ? '، الجودة الحالية' : ''}'
                            '${pending ? '، جاري التحميل' : ''}',
                  ),
                  if (qualityNote != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      qualityNote!,
                      style: text.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
