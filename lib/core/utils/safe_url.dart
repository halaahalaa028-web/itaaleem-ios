import 'package:url_launcher/url_launcher.dart';

/// The only URL schemes the app will hand to the OS. Links come from the
/// backend (support/social/update URLs, attachments), so anything else —
/// `intent:`, `file:`, `javascript:`, `content:`, custom app schemes — is
/// refused instead of launched.
const _allowedLaunchSchemes = {'http', 'https', 'tel', 'mailto'};

bool isAllowedLaunchUri(Uri uri) =>
    _allowedLaunchSchemes.contains(uri.scheme.toLowerCase());

/// [launchUrl], but returns `false` without launching anything unless [uri]'s
/// scheme is http, https, tel or mailto. Same return contract as [launchUrl]
/// (`false` = couldn't open), so callers' existing "تعذر فتح الرابط" handling
/// covers a blocked scheme too.
Future<bool> launchUrlSafely(
  Uri uri, {
  LaunchMode mode = LaunchMode.platformDefault,
}) async {
  if (!isAllowedLaunchUri(uri)) return false;
  return launchUrl(uri, mode: mode);
}
