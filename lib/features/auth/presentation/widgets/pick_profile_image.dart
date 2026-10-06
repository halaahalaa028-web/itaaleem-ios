import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Opens the photo gallery and returns the picked image, or `null` if the
/// student dismissed it without choosing one. Gallery only — the app has no
/// camera capture. Shared by [EditProfileScreen] and the account tab's own
/// tap-to-change avatar so both pick images the same way.
Future<XFile?> pickProfileImage(BuildContext context) {
  return ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 1024,
    imageQuality: 85,
  );
}
