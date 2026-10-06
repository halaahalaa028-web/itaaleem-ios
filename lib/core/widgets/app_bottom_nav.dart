import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:itaaleem/core/theme/app_radius.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';

class AppBottomNavItem {
  const AppBottomNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// The shell's bottom navigation bar, Material 3 style: flat (no shadow)
/// with a hairline top divider, every destination labelled, and the active
/// one marked by a pill indicator that grows in behind its icon while the
/// icon and label switch to the brand color.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  final List<AppBottomNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: scheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 72,
            child: Row(
              children: [
                for (var i = 0; i < items.length; i++)
                  Expanded(
                    child: _NavItem(
                      item: items[i],
                      selected: i == currentIndex,
                      onTap: () {
                        if (i != currentIndex) HapticFeedback.selectionClick();
                        onTap(i);
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final AppBottomNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final iconColor = selected
        ? scheme.onPrimaryContainer
        : scheme.onSurfaceVariant;
    final labelColor = selected ? scheme.primary : scheme.onSurfaceVariant;

    return Semantics(
      selected: selected,
      button: true,
      label: item.label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 36,
        highlightShape: BoxShape.rectangle,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // M3 indicator: a 64×32 pill that expands from the center.
            SizedBox(
              width: 64,
              height: 32,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedContainer(
                    duration: AppMotion.short,
                    curve: AppMotion.standard,
                    width: selected ? 64 : 24,
                    height: 32,
                    decoration: BoxDecoration(
                      color: selected
                          ? scheme.primaryContainer
                          : scheme.primaryContainer.withValues(alpha: 0),
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: AppMotion.short,
                    transitionBuilder: (child, animation) => ScaleTransition(
                      scale: Tween<double>(begin: 0.8, end: 1).animate(
                        CurvedAnimation(
                          parent: animation,
                          curve: AppMotion.emphasized,
                        ),
                      ),
                      child: FadeTransition(opacity: animation, child: child),
                    ),
                    child: Icon(
                      selected ? item.selectedIcon : item.icon,
                      key: ValueKey(selected),
                      size: AppIconSize.md,
                      color: iconColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            AnimatedDefaultTextStyle(
              duration: AppMotion.short,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                height: 1.2,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: labelColor,
              ),
              child: Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
