import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:itaaleem/core/theme/dynamic_theme.dart';
import 'package:itaaleem/features/auth/presentation/providers/auth_controller.dart';
import 'package:itaaleem/features/center/presentation/providers/center_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _colorKey = 'branding_primary_color';
const _logoKey = 'branding_logo_url';

/// The joined center's brand color + logo — drives the dynamic theme and
/// the splash screen. Persisted so a cold start (before the center is
/// re-fetched) still shows the last-known branding; reset on logout.
@immutable
class Branding {
  const Branding({this.primary = defaultPrimaryColor, this.logoUrl});

  final Color primary;
  final String? logoUrl;

  @override
  bool operator ==(Object other) =>
      other is Branding && other.primary == primary && other.logoUrl == logoUrl;

  @override
  int get hashCode => Object.hash(primary, logoUrl);
}

class BrandingController extends Notifier<Branding> {
  Branding? _stored;
  bool _loaded = false;

  @override
  Branding build() {
    final loggedOut = ref.watch(
      authControllerProvider.select((a) => !a.isLoading && a.valueOrNull == null),
    );
    if (loggedOut) {
      _stored = null;
      _loaded = true;
      _persist(null);
      return const Branding();
    }

    final center = ref.watch(joinedCenterProvider);
    if (center != null) {
      final branding = Branding(
        primary: tryParseHexColor(center.primaryColor) ?? defaultPrimaryColor,
        logoUrl: center.logo,
      );
      _stored = branding;
      _loaded = true;
      _persist(branding);
      return branding;
    }

    if (!_loaded) _load();
    return _stored ?? const Branding();
  }

  Future<void> _load() async {
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final color = tryParseHexColor(prefs.getString(_colorKey));
      if (color == null) return;
      _stored = Branding(primary: color, logoUrl: prefs.getString(_logoKey));
      state = _stored!;
    } catch (_) {}
  }

  Future<void> _persist(Branding? branding) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (branding == null) {
        await prefs.remove(_colorKey);
        await prefs.remove(_logoKey);
        return;
      }
      final hex = branding.primary.toARGB32().toRadixString(16).substring(2);
      await prefs.setString(_colorKey, '#$hex');
      final logo = branding.logoUrl;
      if (logo == null || logo.isEmpty) {
        await prefs.remove(_logoKey);
      } else {
        await prefs.setString(_logoKey, logo);
      }
    } catch (_) {}
  }
}

final brandingProvider = NotifierProvider<BrandingController, Branding>(
  BrandingController.new,
);
