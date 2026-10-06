import 'package:flutter/material.dart';
import 'package:itaaleem/core/theme/dynamic_theme.dart';

/// Parses a [CenterModel.primaryColor] hex string (e.g. `"#4338CA"`) into a
/// `Color`, falling back to the default brand color on a bad value. Kept out
/// of the entity itself, which stays UI-framework agnostic.
Color parseCenterColor(String hex) =>
    tryParseHexColor(hex) ?? defaultPrimaryColor;
