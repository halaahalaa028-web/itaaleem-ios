/// `GET /public/app-version` — the currently published app version and
/// whether updating to it is mandatory.
class AppVersionInfo {
  const AppVersionInfo({
    required this.latestVersion,
    this.forceUpdate = false,
    this.updateUrl,
    this.message,
  });

  final String latestVersion;
  final bool forceUpdate;
  final String? updateUrl;
  final String? message;
}
