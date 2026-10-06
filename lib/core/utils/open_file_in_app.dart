import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:itaaleem/app/router/app_router.dart';
import 'package:itaaleem/app/router/route_args.dart';
import 'package:itaaleem/core/network/dio_client.dart';
import 'package:itaaleem/core/utils/safe_url.dart';
import 'package:itaaleem/core/widgets/app_toast.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart' show LaunchMode;

const _imageExtensions = {'png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp', 'heic'};

String _extensionOf(String url) {
  final path = Uri.tryParse(url)?.path ?? url.split('?').first;
  final dot = path.lastIndexOf('.');
  return dot < 0 ? '' : path.substring(dot + 1).toLowerCase();
}

/// Opens any file inside the app instead of the external browser:
/// * PDF → the in-app PDF viewer ([lessonPdfPath]).
/// * Image → the zoom/pan [imageViewerPath] (InteractiveViewer).
/// * Anything else → downloaded to a temp file and handed to the system
///   with `open_filex`; the browser is only the last resort.
///
/// [type] is the API's file type (e.g. `"pdf"`), when it sends one.
Future<void> openFileInApp(
  BuildContext context,
  String? url, {
  String title = 'ملف',
  String? type,
  bool downloadable = false,
}) async {
  if (url == null || url.trim().isEmpty) {
    AppToast.showError(context, 'تعذر فتح الملف');
    return;
  }
  final ext = _extensionOf(url);
  final declared = type?.trim().toLowerCase() ?? '';
  bool isA(bool Function(String) test) => test(ext) || test(declared);

  if (isA((e) => e == 'pdf')) {
    await context.push<void>(
      lessonPdfPath,
      extra: LessonPdfArgs(
        title: title,
        pdfUrl: url,
        downloadable: downloadable,
      ),
    );
    return;
  }
  if (isA(_imageExtensions.contains) || declared == 'image') {
    await context.push<void>(imageViewerPath, extra: url);
    return;
  }

  final dio = ProviderScope.containerOf(context).read(dioClientProvider);
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(const SnackBar(content: Text('جاري فتح الملف...')));
  try {
    final dir = await getTemporaryDirectory();
    final name = Uri.tryParse(url)?.pathSegments.lastOrNull ?? '';
    final path =
        '${dir.path}/${DateTime.now().microsecondsSinceEpoch}_'
        '${name.isEmpty ? 'file${ext.isEmpty ? '' : '.$ext'}' : name}';
    await dio.download(url, path);
    final result = await OpenFilex.open(path);
    if (result.type == ResultType.done) return;
    if (kDebugMode) debugPrint('[openFileInApp] open_filex: ${result.message}');
  } catch (e) {
    if (kDebugMode) debugPrint('[openFileInApp] download failed: $e');
  }
  // Fallback: let the system handle the link.
  final uri = Uri.tryParse(url);
  final ok =
      uri != null &&
      await launchUrlSafely(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) AppToast.showError(context, 'تعذر فتح الملف');
}
