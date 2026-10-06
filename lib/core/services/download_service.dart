import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// Reduces a server-supplied file name to a safe, plain file name: drops any
/// directory components (`/` or `\`, including ones that were percent-encoded
/// in a URL), strips characters other than letters (any script — Arabic
/// included), digits, spaces, `-`, `_` and `.`, removes leading dots so the
/// result can never be `..` or a hidden file, caps the length while keeping
/// the extension, and falls back to `download` if nothing is left.
String sanitizeFilename(String name) {
  var cleaned = name.split('/').last.split(r'\').last;
  cleaned = cleaned.replaceAll(
    RegExp(r'[^\p{L}\p{M}\p{N} \-_.]', unicode: true),
    '',
  );
  cleaned = cleaned.trim().replaceFirst(RegExp(r'^\.+'), '').trim();
  const maxLength = 120;
  if (cleaned.length > maxLength) {
    final dot = cleaned.lastIndexOf('.');
    final extension = (dot > 0 && cleaned.length - dot <= 10)
        ? cleaned.substring(dot)
        : '';
    cleaned = cleaned.substring(0, maxLength - extension.length) + extension;
  }
  return cleaned.isEmpty ? 'download' : cleaned;
}

/// Saves already-downloaded file bytes into the app's own private storage
/// directory (not the public Downloads folder) — this needs no runtime
/// permission on any Android version, since the space is exclusively
/// accessible to the app itself, and it's what lets open_filex open the
/// file back up without requesting READ_EXTERNAL_STORAGE/READ_MEDIA_*.
class DownloadService {
  /// Returns the saved file's absolute path on success, or `null` on
  /// failure — the Dart side hands that path straight to open_filex.
  Future<String?> saveToDownloads({
    required String fileName,
    required String mimeType,
    required Uint8List bytes,
  }) async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final downloadsDir = Directory('${docsDir.path}/downloads');
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }
      final file = File('${downloadsDir.path}/${sanitizeFilename(fileName)}');
      await file.writeAsBytes(bytes);
      return file.path;
    } catch (e) {
      if (kDebugMode) debugPrint('[DownloadService] saveToDownloads failed: $e');
      return null;
    }
  }

  /// Like [saveToDownloads], but for a file that's already on disk (e.g. a
  /// finished `Dio.download` `.part` file): it is *moved* into the downloads
  /// folder — `rename`, falling back to copy + delete across volumes — so the
  /// bytes never pass through memory. [fileName] is sanitized the same way.
  /// Returns the final path, or `null` on failure; [sourcePath] is gone on
  /// success.
  Future<String?> saveFileToDownloads({
    required String sourcePath,
    required String fileName,
  }) async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final downloadsDir = Directory('${docsDir.path}/downloads');
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }
      final source = File(sourcePath);
      final targetPath = '${downloadsDir.path}/${sanitizeFilename(fileName)}';
      try {
        return (await source.rename(targetPath)).path;
      } on FileSystemException {
        final copied = await source.copy(targetPath);
        await source.delete();
        return copied.path;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[DownloadService] saveFileToDownloads failed: $e');
      }
      return null;
    }
  }
}

final downloadServiceProvider = Provider<DownloadService>(
  (ref) => DownloadService(),
);
