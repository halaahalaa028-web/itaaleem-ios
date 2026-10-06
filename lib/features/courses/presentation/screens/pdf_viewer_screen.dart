import 'dart:io';

import 'package:itaaleem/app/theme/app_theme.dart';
import 'package:itaaleem/core/network/dio_client.dart';
import 'package:itaaleem/core/services/download_service.dart';
import 'package:itaaleem/core/widgets/app_toast.dart';
import 'package:itaaleem/core/widgets/error_view.dart';
import 'package:itaaleem/core/widgets/secure_screen.dart';
import 'package:itaaleem/features/auth/presentation/providers/auth_controller.dart';
import 'package:itaaleem/features/courses/domain/entities/lecture_details.dart';
import 'package:itaaleem/features/courses/domain/usecases/post_pdf_progress_usecase.dart';
import 'package:itaaleem/features/courses/presentation/providers/courses_providers.dart';
import 'package:itaaleem/features/courses/presentation/widgets/identity_watermark.dart';
import 'package:dio/dio.dart' as dio;
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:itaaleem/core/widgets/content_watermark.dart';
import 'package:flutter/material.dart';
import 'package:itaaleem/core/theme/app_palette.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:itaaleem/core/theme/app_radius.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';

/// `GET /lectures/{id}`: renders the lecture's PDF attachment with pdfrx
/// (PDFium) — in-document text search, pinch/button zoom, a scroll thumb —
/// tracking the current page and reporting reading progress to
/// `POST /pdfs/{id}/progress` on every page turn and again on exit.
/// [SecureScreen] blocks screenshots/recording (`FLAG_SECURE`) and the
/// identifying watermark overlays the page, same as the video player.
///
/// TODO: re-add annotations (highlight / underline / strikethrough) — pdfrx
/// has no API for creating them.
class PdfViewerScreen extends ConsumerWidget {
  const PdfViewerScreen({
    super.key,
    required this.lectureId,
    required this.pdfId,
    this.initialTitle,
  });

  final int lectureId;
  final int pdfId;
  final String? initialTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailsAsync = ref.watch(lectureDetailsProvider(lectureId));

    return SecureScreen(
      child: Scaffold(
        backgroundColor: AppColors.darkBackground,
        body: SafeArea(
          child: Column(
            children: [
              _Header(
                title: initialTitle ?? detailsAsync.valueOrNull?.title ?? '',
              ),
              Expanded(
                child: detailsAsync.when(
                  loading: () => Center(
                    child: CircularProgressIndicator(
                      color: context.palette.primaryOnDark,
                    ),
                  ),
                  error: (error, stackTrace) => ErrorView(
                    message: 'تعذر تحميل الملف، حاول مرة أخرى',
                    retryLabel: 'إعادة المحاولة',
                    onRetry: () =>
                        ref.invalidate(lectureDetailsProvider(lectureId)),
                  ),
                  data: (details) {
                    final pdf =
                        _findPdf(details.pdfs, pdfId) ?? details.primaryPdf;
                    if (kDebugMode) {
                      debugPrint(
                        '[PdfViewerScreen] lecture $lectureId requested pdfId=$pdfId: '
                        '${details.pdfs.length} pdf(s) available, resolved=${pdf?.id}',
                      );
                    }
                    if (pdf == null) {
                      return const Center(
                        child: Text(
                          'لا يوجد ملف PDF لهذا الدرس',
                          style: TextStyle(color: AppColors.darkTextPrimary),
                        ),
                      );
                    }
                    return _PdfBody(key: ValueKey('pdf-${pdf.id}'), pdf: pdf);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  LecturePdf? _findPdf(List<LecturePdf> pdfs, int id) {
    for (final pdf in pdfs) {
      if (pdf.id == id) return pdf;
    }
    return null;
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(gradient: context.palette.brandGradient),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.pop(),
            icon: const BackButtonIcon(),
            color: AppColors.darkTextPrimary,
          ),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.darkTextPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xxxl),
        ],
      ),
    );
  }
}

class _PdfBody extends ConsumerStatefulWidget {
  const _PdfBody({super.key, required this.pdf});

  final LecturePdf pdf;

  @override
  ConsumerState<_PdfBody> createState() => _PdfBodyState();
}

class _PdfBodyState extends ConsumerState<_PdfBody> {
  final _pdfController = PdfViewerController();
  final _searchFieldController = TextEditingController();
  late int _currentPage;
  int _totalPages = 0;
  File? _file;
  dio.CancelToken? _cancelToken;
  String? _loadError;
  double? _loadProgress;
  bool _downloading = false;
  double? _downloadProgress;

  bool _searchOpen = false;
  // Created once the viewer is ready (it needs the attached controller).
  PdfTextSearcher? _textSearcher;
  String _lastQuery = '';

  // `ref` throws once the element is disposed, so the use case must be
  // grabbed eagerly in initState — dispose() reports final progress and
  // can't call ref.read at that point (see the same fix in
  // LecturePlayerScreen for the video-progress equivalent).
  late final PostPdfProgressUseCase _postProgressUseCase;

  @override
  void initState() {
    super.initState();
    _postProgressUseCase = ref.read(postPdfProgressUseCaseProvider);
    _currentPage = widget.pdf.lastPage < 1 ? 1 : widget.pdf.lastPage;
    _loadFile();
  }

  /// Cached on disk under the app's private cache dir, keyed by pdf id —
  /// re-opening the same lecture's PDF (very common: students flip back to
  /// re-read) then costs a disk read instead of a full re-download.
  Future<File> _cacheFile() async {
    final cacheDir = await getTemporaryDirectory();
    return File('${cacheDir.path}/pdf_cache/${widget.pdf.id}.pdf');
  }

  /// True for a real, non-empty PDF: starts with the `%PDF` magic bytes.
  /// Only the first few bytes are read — never the whole file.
  Future<bool> _isValidPdf(File file) async {
    try {
      if (await file.length() < 8) return false;
      final raf = await file.open();
      try {
        final head = await raf.read(5);
        return head.length == 5 &&
            head[0] == 0x25 && // %
            head[1] == 0x50 && // P
            head[2] == 0x44 && // D
            head[3] == 0x46; // F
      } finally {
        await raf.close();
      }
    } catch (_) {
      return false;
    }
  }

  /// Streams the PDF to disk (never into memory) through the authenticated
  /// Dio client — with progress, atomically (`.part` then rename) so a killed
  /// download can't leave a truncated file in the cache — and shows it with
  /// `PdfViewer.file`. An already-cached, valid file is opened straight
  /// away; a corrupt cached one is discarded and re-downloaded.
  Future<void> _loadFile() async {
    if (mounted) {
      setState(() {
        _loadError = null;
        _loadProgress = null;
      });
    }
    File? partial;
    try {
      final target = await _cacheFile();
      if (await target.exists()) {
        if (await _isValidPdf(target)) {
          if (kDebugMode) {
            debugPrint(
              '[PdfViewerScreen] pdf ${widget.pdf.id}: opened from cache',
            );
          }
          if (mounted) setState(() => _file = target);
          return;
        }
        await target.delete();
      }

      if (kDebugMode) {
        debugPrint(
          '[PdfViewerScreen] downloading pdf ${widget.pdf.id} from ${widget.pdf.fileUrl}',
        );
      }
      await target.parent.create(recursive: true);
      partial = File('${target.path}.part');
      _cancelToken = dio.CancelToken();
      await ref
          .read(dioClientProvider)
          .download(
            widget.pdf.fileUrl,
            partial.path,
            cancelToken: _cancelToken,
            onReceiveProgress: (received, total) {
              if (!mounted) return;
              if (total > 0) {
                final next = received / total;
                // Repaint at ~1% steps instead of on every network chunk.
                if (_loadProgress == null || next - _loadProgress! >= 0.01) {
                  setState(() => _loadProgress = next);
                }
              }
            },
          );
      if (!await _isValidPdf(partial)) {
        throw const FormatException('downloaded file is not a valid PDF');
      }
      await partial.rename(target.path);
      if (mounted) setState(() => _file = target);
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          '[PdfViewerScreen] pdf ${widget.pdf.id} failed to load: $e\n$stackTrace',
        );
      }
      try {
        if (partial != null && await partial.exists()) await partial.delete();
      } catch (_) {}
      if (e is dio.DioException && e.type == dio.DioExceptionType.cancel) {
        return;
      }
      if (mounted) setState(() => _loadError = _messageFor(e));
    }
  }

  /// A corrupt file made it past the header check — drop it from the cache so
  /// "إعادة المحاولة" downloads a fresh copy instead of failing forever.
  Future<void> _onViewerFailed(String description) async {
    if (kDebugMode) {
      debugPrint('[PdfViewerScreen] PdfViewer load failed: $description');
    }
    try {
      final cache = await _cacheFile();
      if (await cache.exists()) await cache.delete();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _file = null;
      _loadError = 'الملف تالف أو غير مدعوم';
    });
  }

  String _messageFor(Object error) {
    if (error is dio.DioException) {
      final statusCode = error.response?.statusCode;
      if (statusCode == 404) return 'الملف غير موجود على السيرفر';
      if (error.type == dio.DioExceptionType.connectionTimeout ||
          error.type == dio.DioExceptionType.receiveTimeout ||
          error.type == dio.DioExceptionType.connectionError) {
        return 'تعذر الاتصال بالسيرفر، تحقق من الإنترنت';
      }
    }
    if (error is FormatException) return 'الملف تالف أو غير صالح';
    if (error is FileSystemException) {
      return 'مساحة التخزين غير كافية أو تعذر حفظ الملف';
    }
    return 'تعذر عرض الملف';
  }

  @override
  void dispose() {
    _cancelToken?.cancel();
    _reportProgress();
    _textSearcher
      ?..removeListener(_onSearchChanged)
      ..dispose();
    _searchFieldController.dispose();
    super.dispose();
  }

  void _reportProgress() {
    final total = _totalPages;
    final percentage = total > 0
        ? (_currentPage / total * 100).clamp(0, 100).toDouble()
        : 0.0;
    _postProgressUseCase(
      widget.pdf.id,
      lastPage: _currentPage,
      readPercentage: percentage,
    );
  }

  void _onPageChanged(int? pageNumber) {
    if (pageNumber == null || pageNumber == _currentPage) return;
    setState(() => _currentPage = pageNumber);
    _reportProgress();
  }

  void _onViewerReady(PdfDocument document, PdfViewerController controller) {
    _textSearcher ??= PdfTextSearcher(controller)
      ..addListener(_onSearchChanged);
    setState(() => _totalPages = document.pages.length);
  }

  /// Paints the search-match highlights on each page; a stable tear-off, so
  /// the viewer's params don't change when the searcher is created.
  void _paintSearchMatches(Canvas canvas, Rect pageRect, PdfPage page) {
    _textSearcher?.pageTextMatchPaintCallback(canvas, pageRect, page);
  }

  void _toggleSearch() {
    setState(() {
      _searchOpen = !_searchOpen;
      if (!_searchOpen) _clearSearch();
    });
  }

  void _runSearch(String query) {
    final trimmed = query.trim();
    final searcher = _textSearcher;
    if (trimmed.isEmpty || searcher == null) return;
    setState(() => _lastQuery = trimmed);
    searcher.startTextSearch(trimmed, searchImmediately: true);
  }

  void _onSearchChanged() {
    if (mounted) setState(() {});
  }

  void _clearSearch() {
    _textSearcher?.resetTextSearch();
    _searchFieldController.clear();
    _lastQuery = '';
  }

  void _zoomIn() => _pdfController.zoomUp();

  void _zoomOut() => _pdfController.zoomDown();

  /// "Jump to page" dialog, opened by tapping the page counter.
  Future<void> _showGoToPageDialog() async {
    final total = _totalPages;
    if (total <= 0 || !_pdfController.isReady) return;
    final field = TextEditingController(text: '$_currentPage');
    final page = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        void submit() {
          final value = int.tryParse(field.text.trim());
          Navigator.of(dialogContext).pop(value?.clamp(1, total).toInt());
        }

        return AlertDialog(
          title: const Text('الانتقال إلى صفحة'),
          content: TextField(
            controller: field,
            autofocus: true,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.go,
            onSubmitted: (_) => submit(),
            decoration: InputDecoration(hintText: '1 - $total'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('إلغاء'),
            ),
            FilledButton(onPressed: submit, child: const Text('انتقال')),
          ],
        );
      },
    );
    if (page != null && mounted) {
      await _pdfController.goToPage(pageNumber: page);
    }
  }

  /// Downloads the PDF's bytes (same authenticated Dio client the in-app
  /// viewer uses, tracking progress) and hands them to [DownloadService] to
  /// save straight into the device's Downloads folder — no browser, no
  /// server URL ever shown to the student.
  Future<void> _download() async {
    if (_downloading) return;
    setState(() {
      _downloading = true;
      _downloadProgress = null;
    });

    try {
      // The viewer already streamed the file into the cache — reuse it
      // instead of downloading the whole PDF a second time.
      final cached = _file;
      if (cached == null) throw StateError('pdf not loaded yet');
      final bytes = await cached.readAsBytes();
      if (bytes.isEmpty) throw StateError('empty pdf file');

      final savedPath = await ref
          .read(downloadServiceProvider)
          .saveToDownloads(
            fileName: _fileName,
            mimeType: 'application/pdf',
            bytes: bytes,
          );
      if (!mounted) return;
      if (savedPath != null) {
        AppToast.showSuccess(
          context,
          'تم التحميل بنجاح — الملف في مجلد التنزيلات',
          actionLabel: 'فتح الملف',
          onAction: () => OpenFilex.open(savedPath),
        );
      } else {
        AppToast.showError(context, 'تعذر حفظ الملف على الجهاز');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('[PdfViewerScreen] download failed: $e\n$stackTrace');
      }
      if (mounted) AppToast.showError(context, _messageFor(e));
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  String get _fileName {
    final uri = Uri.tryParse(widget.pdf.fileUrl);
    final last = (uri != null && uri.pathSegments.isNotEmpty)
        ? uri.pathSegments.last
        : null;
    if (last != null && last.isNotEmpty) return last;
    final title = widget.pdf.title.trim();
    return '${title.isEmpty ? 'document' : title}.pdf';
  }

  @override
  Widget build(BuildContext context) {
    final student = ref.watch(authControllerProvider).valueOrNull;

    return Column(
      children: [
        _Toolbar(
          searchOpen: _searchOpen,
          onSearchTap: _file == null ? null : _toggleSearch,
          onZoomIn: _file == null ? null : _zoomIn,
          onZoomOut: _file == null ? null : _zoomOut,
        ),
        if (_searchOpen)
          _SearchBar(
            controller: _searchFieldController,
            searcher: _textSearcher,
            hasQuery: _lastQuery.isNotEmpty,
            onSubmit: _runSearch,
            onNext: () => _textSearcher?.goToNextMatch(),
            onPrevious: () => _textSearcher?.goToPrevMatch(),
            onClose: _toggleSearch,
          ),
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildViewer(),
              if (student != null && _file != null) ...[
                Positioned.fill(
                  child: ContentWatermark(
                    studentName: student.fullName,
                    studentPhone: student.mobile,
                  ),
                ),
                Positioned.fill(
                  child: IdentityWatermark(
                    studentName: student.fullName,
                    studentMobile: student.mobile,
                  ),
                ),
              ],
            ],
          ),
        ),
        _BottomBar(
          currentPage: _currentPage,
          totalPages: _totalPages > 0 ? _totalPages : null,
          isDownloadable: widget.pdf.isDownloadable,
          isDownloading: _downloading,
          downloadProgress: _downloadProgress,
          onDownload: _download,
          onPageTap: _file == null ? null : _showGoToPageDialog,
        ),
      ],
    );
  }

  Widget _buildViewer() {
    if (_loadError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _loadError!,
              style: const TextStyle(color: AppColors.darkTextPrimary),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed: _loadFile,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      );
    }
    final file = _file;
    if (file == null) {
      final progress = _loadProgress;
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                color: context.palette.primaryOnDark,
                value: progress,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              progress != null
                  ? 'جاري تحميل الملف... ${(progress * 100).round()}٪'
                  : 'جاري تحميل الملف...',
              style: const TextStyle(
                color: AppColors.darkTextSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }
    return PdfViewer.file(
      file.path,
      controller: _pdfController,
      initialPageNumber: _currentPage,
      params: PdfViewerParams(
        maxScale: 5,
        backgroundColor: AppColors.darkBackground,
        onViewerReady: _onViewerReady,
        onPageChanged: _onPageChanged,
        onDocumentLoadFinished: (documentRef, loadSucceeded) {
          if (loadSucceeded) return;
          _onViewerFailed(
            '${documentRef.resolveListenable().error ?? 'unknown error'}',
          );
        },
        pagePaintCallbacks: [_paintSearchMatches],
        viewerOverlayBuilder: (context, size, handleLinkTap) => [
          PdfViewerScrollThumb(
            controller: _pdfController,
            orientation: ScrollbarOrientation.right,
          ),
        ],
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.searchOpen,
    required this.onSearchTap,
    required this.onZoomIn,
    required this.onZoomOut,
  });

  final bool searchOpen;
  final VoidCallback? onSearchTap;
  final VoidCallback? onZoomIn;
  final VoidCallback? onZoomOut;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.darkBackground,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 6,
        ),
        child: Row(
          children: [
            // TODO: re-add annotations (تظليل / تسطير / شطب) — pdfrx can't
            // create highlight/underline/strikethrough annotations.
            _ToolButton(
              icon: Icons.zoom_out_rounded,
              label: 'تصغير',
              onTap: onZoomOut,
            ),
            _ToolButton(
              icon: Icons.zoom_in_rounded,
              label: 'تكبير',
              onTap: onZoomIn,
            ),
            Container(
              width: 1,
              height: 24,
              margin: const EdgeInsetsDirectional.symmetric(
                horizontal: AppSpacing.xs,
              ),
              color: AppColors.darkSurfaceVariant,
            ),
            _ToolButton(
              icon: Icons.search_rounded,
              label: 'بحث',
              isActive: searchOpen,
              onTap: onSearchTap,
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 6),
      child: Material(
        color: isActive
            ? context.palette.primaryOnDark.withValues(alpha: 0.3)
            : AppColors.darkTextPrimary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: disabled
                      ? AppColors.darkSurfaceVariant
                      : (isActive
                            ? context.palette.primaryOnDark
                            : AppColors.darkTextPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: disabled
                        ? AppColors.darkSurfaceVariant
                        : (isActive
                              ? context.palette.primaryOnDark
                              : AppColors.darkTextSecondary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.searcher,
    required this.hasQuery,
    required this.onSubmit,
    required this.onNext,
    required this.onPrevious,
    required this.onClose,
  });

  final TextEditingController controller;
  final PdfTextSearcher? searcher;

  /// A search has been run (so "no results" can be told apart from "idle").
  final bool hasQuery;
  final ValueChanged<String> onSubmit;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final activeResult = searcher;
    final String countLabel;
    if (activeResult == null || !hasQuery) {
      countLabel = '';
    } else if (activeResult.hasMatches) {
      countLabel =
          '${(activeResult.currentIndex ?? 0) + 1}/${activeResult.matches.length}';
    } else if (activeResult.isSearching) {
      countLabel = 'جاري البحث...';
    } else {
      countLabel = 'لا نتائج';
    }
    final canStep = activeResult != null && activeResult.matches.isNotEmpty;

    return Container(
      color: AppColors.darkBackground,
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              style: const TextStyle(color: AppColors.darkTextPrimary),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'ابحث في النص...',
                hintStyle: const TextStyle(color: AppColors.darkTextTertiary),
                filled: true,
                fillColor: AppColors.darkTextPrimary.withValues(alpha: 0.08),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: onSubmit,
            ),
          ),
          if (countLabel.isNotEmpty) ...[
            const SizedBox(width: AppSpacing.sm),
            Text(
              countLabel,
              style: const TextStyle(
                color: AppColors.darkTextSecondary,
                fontSize: 12,
              ),
            ),
          ],
          IconButton(
            onPressed: canStep ? onPrevious : null,
            icon: const Icon(
              Icons.keyboard_arrow_up_rounded,
              color: AppColors.darkTextPrimary,
            ),
          ),
          IconButton(
            onPressed: canStep ? onNext : null,
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppColors.darkTextPrimary,
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(
              Icons.close_rounded,
              color: AppColors.darkTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.currentPage,
    required this.totalPages,
    required this.isDownloadable,
    required this.isDownloading,
    required this.downloadProgress,
    required this.onDownload,
    required this.onPageTap,
  });

  final int currentPage;
  final int? totalPages;
  final bool isDownloadable;
  final bool isDownloading;
  final double? downloadProgress;
  final VoidCallback onDownload;

  /// Opens the "jump to page" dialog; `null` while the file isn't loaded.
  final VoidCallback? onPageTap;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.darkBackground,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isDownloading)
            LinearProgressIndicator(
              value: downloadProgress,
              minHeight: 3,
              backgroundColor: AppColors.darkSurfaceVariant,
              valueColor: AlwaysStoppedAnimation(context.palette.primaryOnDark),
            ),
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.base,
              vertical: 10,
            ),
            child: Row(
              children: [
                InkWell(
                  onTap: onPageTap,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xs,
                    ),
                    child: Text(
                      totalPages != null
                          ? 'صفحة $currentPage من $totalPages'
                          : 'صفحة $currentPage',
                      style: const TextStyle(
                        color: AppColors.darkTextSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                if (isDownloadable)
                  if (isDownloading)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: context.palette.primaryOnDark,
                            value: downloadProgress,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          downloadProgress != null
                              ? 'جاري التحميل ${(downloadProgress! * 100).round()}٪'
                              : 'جاري التحميل...',
                          style: TextStyle(
                            color: context.palette.primaryOnDark,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    )
                  else
                    TextButton.icon(
                      onPressed: onDownload,
                      icon: Icon(
                        Icons.download_rounded,
                        color: context.palette.primaryOnDark,
                      ),
                      label: Text(
                        'تحميل',
                        style: TextStyle(color: context.palette.primaryOnDark),
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
