import 'package:itaaleem/core/theme/app_colors.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:itaaleem/core/theme/app_radius.dart';
import 'package:flutter/material.dart';

/// A subject's `icon_url`, or the Navy [Icons.menu_book_rounded] fallback
/// when there's none (or it fails to load) — shared by every place a
/// subject is listed (home tab, "موادي", a subject's own detail header),
/// so they all render/cache the same way.
class SubjectIcon extends StatelessWidget {
  const SubjectIcon({
    super.key,
    required this.iconUrl,
    this.size = 56,
    this.iconSize = 26,
    this.borderRadius,
    this.seed = 0,
    this.name = '',
  });

  /// Picks the fallback colour from [_palette] (usually the subject's id).
  final int seed;

  /// Subject name, used to pick a matching fallback icon.
  final String name;

  static const _palette = AppColors.subjectPalette;

  /// The palette colour for [seed] — shared so cards can tint to match.
  static Color colorFor(int seed) => _palette[seed.abs() % _palette.length];

  IconData get _icon {
    final n = name.toLowerCase();
    bool has(List<String> k) => k.any(n.contains);
    if (has(['رياض', 'حساب', 'جبر', 'هندس', 'math'])) {
      return Icons.calculate_rounded;
    }
    if (has(['انجليز', 'إنجليز', 'عربي', 'لغة', 'لغه', 'فرنس', 'english'])) {
      return Icons.language_rounded;
    }
    if (has(['حاسب', 'برمج', 'كمبيوتر', 'computer'])) {
      return Icons.computer_rounded;
    }
    if (has(['علوم', 'فيزياء', 'كيمياء', 'أحياء', 'احياء', 'science'])) {
      return Icons.science_rounded;
    }
    return Icons.menu_book_rounded;
  }

  final String? iconUrl;
  final double size;
  final double iconSize;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(AppRadius.md + 2);
    final url = iconUrl;

    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        width: size,
        height: size,
        child: (url == null || url.isEmpty)
            ? _fallback()
            : CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                memCacheWidth: (size * MediaQuery.devicePixelRatioOf(context))
                    .round(),
                placeholder: (context, url) => _fallback(loading: true),
                errorWidget: (context, url, error) => _fallback(),
              ),
      ),
    );
  }

  Widget _fallback({bool loading = false}) {
    final color = _palette[seed.abs() % _palette.length];
    return DecoratedBox(
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15)),
      child: Center(
        child: loading
            ? SizedBox(
                width: iconSize * 0.7,
                height: iconSize * 0.7,
                child: CircularProgressIndicator(strokeWidth: 2, color: color),
              )
            : Icon(_icon, color: color, size: iconSize),
      ),
    );
  }
}
