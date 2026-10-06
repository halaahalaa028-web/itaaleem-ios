/// App-wide settings from `GET /public/settings`: contact/social links,
/// the "about" text, and the maintenance-mode gate.
class AppSettings {
  const AppSettings({
    this.appName,
    this.whatsappGroup,
    this.whatsappNumber,
    this.facebookUrl,
    this.youtubeUrl,
    this.telegramUrl,
    this.websiteUrl,
    this.supportPhone,
    this.supportEmail,
    this.aboutText,
    this.maintenanceMode = false,
    this.maintenanceMessage,
    this.aiEnabled = false,
    this.sequentialMode = false,
  });

  final String? appName;
  final String? whatsappGroup;
  final String? whatsappNumber;
  final String? facebookUrl;
  final String? youtubeUrl;
  final String? telegramUrl;
  final String? websiteUrl;
  final String? supportPhone;
  final String? supportEmail;
  final String? aboutText;
  final bool maintenanceMode;
  final String? maintenanceMessage;

  /// Whether "المساعد الذكي" (`POST /ai/ask`) is turned on server-side.
  final bool aiEnabled;

  /// Whether a lecture stays locked until the previous one in its list is
  /// completed — see `isSequentiallyLocked`. Off (every unlocked lecture
  /// playable in any order) until the backend turns it on.
  final bool sequentialMode;
}
