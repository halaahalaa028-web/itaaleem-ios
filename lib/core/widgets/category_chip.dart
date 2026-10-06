import 'package:flutter/material.dart';
import 'package:itaaleem/core/theme/app_palette.dart';
import 'package:itaaleem/core/theme/app_radius.dart';

/// Pill-shaped [ChoiceChip] for a horizontal filter strip: the selected one
/// is filled with the brand color and white text, the rest stay on the card
/// surface with a 1px border.
class CategoryChip extends StatelessWidget {
  const CategoryChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final scheme = Theme.of(context).colorScheme;

    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onSelected(),
      labelStyle: TextStyle(
        fontFamily: 'Cairo',
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: selected ? scheme.onPrimary : palette.textPrimary,
      ),
      selectedColor: palette.primary,
      backgroundColor: palette.surface,
      side: BorderSide(color: selected ? palette.primary : palette.border),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
    );
  }
}
