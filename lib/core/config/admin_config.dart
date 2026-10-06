import 'package:itaaleem/core/network/api_endpoints.dart';

/// Admin access config for the in-app dashboard.
///
/// The live API sends `role: "student"` on every regular account; admins are
/// recognized by `role` first (see `Student.isAdmin`). [adminPhones] is the
/// temporary fallback for admin accounts whose `role` the API doesn't send
/// yet — to be removed once it does.
class AdminConfig {
  AdminConfig._();

  /// Admin phone numbers (any format — compared digits-only, so
  /// `+20 100 000 0000` and `01000000000` both match).
  static const adminPhones = <String>{
    // '01000000000',
  };

  /// The full Filament panel, opened in the browser from the dashboard.
  /// Override with `--dart-define=ADMIN_PANEL_URL=...`.
  static String get panelUrl {
    const override = String.fromEnvironment('ADMIN_PANEL_URL');
    if (override.isNotEmpty) return override;
    return Uri.parse(ApiEndpoints.baseUrl).replace(path: '/admin').toString();
  }

  static bool isAdmin(String? phone) {
    final cleaned = _digits(phone);
    // Too short to be a real number — never let a near-empty profile field
    // suffix-match an admin's phone.
    if (cleaned.length < 8) return false;
    return adminPhones.any((admin) {
      final cleanedAdmin = _digits(admin);
      if (cleanedAdmin.length < 8) return false;
      return cleaned.endsWith(cleanedAdmin) || cleanedAdmin.endsWith(cleaned);
    });
  }

  /// Digits only, with a leading `0` dropped so `010...` (local) and
  /// `+2010...` (international) compare by their shared suffix.
  static String _digits(String? phone) {
    final digits = (phone ?? '').replaceAll(RegExp(r'\D'), '');
    return digits.startsWith('0') ? digits.substring(1) : digits;
  }
}
