import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// The installed build's name/version, read once per app session — shared
/// by anything that needs to display it (account screen footer, "عن
/// التطبيق" dialog) instead of each reading the platform channel itself.
final packageInfoProvider = FutureProvider<PackageInfo>(
  (ref) => PackageInfo.fromPlatform(),
);
