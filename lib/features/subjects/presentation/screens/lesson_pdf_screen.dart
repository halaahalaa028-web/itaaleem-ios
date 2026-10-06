import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:itaaleem/app/theme/app_theme.dart';
import 'package:itaaleem/core/widgets/secure_screen.dart';
import 'package:itaaleem/features/subjects/presentation/utils/pdf_download.dart';
import 'package:itaaleem/features/subjects/presentation/widgets/lesson_pdf_view.dart';

/// Views a subject lesson's own PDF from `SubjectLesson.pdfUrl` — the
/// download/cache/viewer logic lives in [LessonPdfView], shared with the
/// split view in `LessonVideoScreen`.
class LessonPdfScreen extends ConsumerWidget {
  const LessonPdfScreen({
    super.key,
    required this.title,
    required this.pdfUrl,
    this.downloadable = false,
  });

  final String title;
  final String? pdfUrl;

  /// The API's `is_downloadable`: the download button only shows when true.
  final bool downloadable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = pdfUrl;
    return SecureScreen(
      child: Scaffold(
        backgroundColor: AppColors.darkBackground,
        appBar: AppBar(
          backgroundColor: AppColors.darkSurface,
          foregroundColor: AppColors.darkTextPrimary,
          title: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 15),
          ),
          actions: [
            if (downloadable && url != null && url.isNotEmpty)
              IconButton(
                tooltip: 'تحميل',
                icon: const Icon(Icons.download_rounded),
                onPressed: () =>
                    downloadPdf(context, ref, url: url, title: title),
              ),
          ],
        ),
        body: LessonPdfView(pdfUrl: url),
      ),
    );
  }
}
