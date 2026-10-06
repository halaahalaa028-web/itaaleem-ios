// Back-compat re-export: the real Design System now lives under
// `lib/core/theme/` (app_colors.dart, app_text_styles.dart, app_spacing.dart,
// app_radius.dart, app_theme.dart). Kept so the many existing
// `package:itaaleem/app/theme/app_theme.dart` imports across the app
// keep resolving without a repo-wide import rewrite.
export 'package:itaaleem/core/theme/app_colors.dart';
export 'package:itaaleem/core/theme/app_theme.dart';
