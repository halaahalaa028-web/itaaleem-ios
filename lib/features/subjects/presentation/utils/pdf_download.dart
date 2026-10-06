import 'dart:io';

import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:itaaleem/core/network/dio_client.dart';
import 'package:itaaleem/core/services/download_service.dart';
import 'package:itaaleem/core/widgets/app_toast.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

/// Downloads a subject/lesson PDF with the authenticated Dio client and saves
/// it via [DownloadService] (same flow as the courses [PdfViewerScreen]).
///
/// The body is streamed straight to a temporary `.part` file on disk
/// (`Dio.download`) instead of being buffered in memory, then the finished
/// file is *moved* into the downloads folder
/// ([DownloadService.saveFileToDownloads]). A failed or interrupted download
/// never leaves a half-written file behind.
Future<void> downloadPdf(
  BuildContext context,
  WidgetRef ref, {
  required String url,
  required String title,
}) async {
  if (url.isEmpty) return;
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(const SnackBar(content: Text('جاري تحميل الملف...')));
  final dio = ref.read(dioClientProvider);
  final downloads = ref.read(downloadServiceProvider);
  File? partial;
  try {
    final tempDir = await getTemporaryDirectory();
    partial = File(
      '${tempDir.path}/pdf_download_${DateTime.now().microsecondsSinceEpoch}.part',
    );
    await dio.download(url, partial.path);
    if (await partial.length() == 0) throw StateError('empty pdf');
    final savedPath = await downloads.saveFileToDownloads(
      sourcePath: partial.path,
      fileName: _fileNameFor(url, title),
    );
    if (!context.mounted) return;
    if (savedPath == null) {
      AppToast.showError(context, 'تعذر حفظ الملف على الجهاز');
      return;
    }
    AppToast.showSuccess(
      context,
      'تم تحميل الملف',
      actionLabel: 'فتح الملف',
      onAction: () => OpenFilex.open(savedPath),
    );
  } catch (e) {
    if (kDebugMode) debugPrint('[downloadPdf] failed: $e');
    if (context.mounted) AppToast.showError(context, 'تعذر تحميل الملف');
  } finally {
    // After a successful move the partial no longer exists; this only cleans
    // up after a failed download / save.
    try {
      if (partial != null && await partial.exists()) await partial.delete();
    } catch (_) {}
  }
}

String _fileNameFor(String url, String title) {
  final segments = Uri.tryParse(url)?.pathSegments ?? const [];
  if (segments.isNotEmpty && segments.last.toLowerCase().endsWith('.pdf')) {
    return segments.last;
  }
  final safe = title.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  return '${safe.isEmpty ? 'document' : safe}.pdf';
}
