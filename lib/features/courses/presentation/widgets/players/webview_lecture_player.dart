import 'package:itaaleem/features/courses/domain/entities/lecture_details.dart';
import 'package:itaaleem/features/courses/presentation/widgets/players/lecture_playback_handle.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Plays a `provider == 'bunny'` or `'vimeo'` lecture video by loading the
/// provider's own hosted player in a WebView. (`youtube` gets its own
/// chrome-free `YoutubeMediaKitPlayer` instead — this generic player can't
/// strip a provider's UI or branding.)
///
/// Neither Bunny nor Vimeo's iframe here exposes a JS bridge, so there's no
/// way to read real playback position back out — [WebviewLecturePlayer] can
/// only approximate it as elapsed wall-clock time since the page finished
/// loading, capped at the lecture's known `duration_seconds` (if the API
/// supplied one). This is the most complete tracking available without a
/// provider-specific postMessage integration.
class WebviewLecturePlayer extends StatefulWidget {
  const WebviewLecturePlayer({
    super.key,
    required this.video,
    required this.startAt,
    required this.onReady,
  });

  final LectureVideo video;
  final Duration startAt;
  final ValueChanged<LecturePlaybackHandle> onReady;

  /// The provider's hosted-player URL to embed, or `null` if neither
  /// `provider_video_id` nor `video_url` is usable. `youtube` never reaches
  /// this widget in practice (see [LecturePlayerScreen._buildPlayerFor]),
  /// but the switch stays exhaustive over the shared [VideoProvider] enum.
  static String? resolveEmbedUrl(
    LectureVideo video, {
    Duration startAt = Duration.zero,
  }) {
    switch (video.provider) {
      case VideoProvider.vimeo:
        final id = video.providerVideoId;
        if (id != null && id.isNotEmpty) {
          return 'https://player.vimeo.com/video/$id'
              '#t=${startAt.inSeconds}s';
        }
        return video.videoUrl;
      case VideoProvider.bunny:
        // Bunny Stream's dashboard-issued embed URL is expected to already
        // be a ready-to-load iframe page.
        return video.videoUrl ?? video.providerVideoId;
      case VideoProvider.youtube:
      case VideoProvider.privateServer:
      case VideoProvider.unknown:
        return video.videoUrl;
    }
  }

  @override
  State<WebviewLecturePlayer> createState() => _WebviewLecturePlayerState();
}

class _WebviewLecturePlayerState extends State<WebviewLecturePlayer> {
  late final WebViewController _controller;
  final _handle = _WebviewHandle();

  /// The embed URL's own host — the only host this WebView is ever allowed
  /// to navigate to (see [_onNavigationRequest]). Subresource loads (video
  /// segments, CDN assets, etc.) aren't affected, since `NavigationDelegate`
  /// only intercepts actual navigations, not those.
  String? _allowedHost;

  @override
  void initState() {
    super.initState();
    _handle.startAt = widget.startAt;
    _handle.knownDuration = widget.video.durationSeconds != null
        ? Duration(seconds: widget.video.durationSeconds!)
        : null;

    final url = WebviewLecturePlayer.resolveEmbedUrl(
      widget.video,
      startAt: widget.startAt,
    );
    if (kDebugMode) {
      debugPrint(
        '[WebviewLecturePlayer] initState — mounting for provider=${widget.video.provider} url=$url',
      );
    }
    _allowedHost = url != null ? Uri.tryParse(url)?.host : null;
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: _onNavigationRequest,
          onPageFinished: (_) {
            _handle.startedAt = DateTime.now();
            widget.onReady(_handle);
          },
        ),
      );
    if (url != null && url.isNotEmpty) {
      _controller.loadRequest(Uri.parse(url));
    }
  }

  /// Blocks any navigation away from the embedded player's own host — e.g.
  /// an ad click or a redirect inside Bunny/Vimeo's hosted page trying to
  /// escape to an external site. Never opens a browser; just refuses the
  /// navigation outright.
  NavigationDecision _onNavigationRequest(NavigationRequest request) {
    final uri = Uri.tryParse(request.url);
    final host = _allowedHost;
    if (uri != null && host != null && uri.host == host) {
      return NavigationDecision.navigate;
    }
    if (kDebugMode) {
      debugPrint('[WebviewLecturePlayer] blocked navigation to ${request.url}');
    }
    return NavigationDecision.prevent;
  }

  @override
  Widget build(BuildContext context) {
    final url = WebviewLecturePlayer.resolveEmbedUrl(
      widget.video,
      startAt: widget.startAt,
    );
    if (url == null || url.isEmpty) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: Text(
            'تعذر تحميل الفيديو',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ColoredBox(
        color: Colors.black,
        child: WebViewWidget(controller: _controller),
      ),
    );
  }
}

class _WebviewHandle extends LecturePlaybackHandle {
  Duration startAt = Duration.zero;
  DateTime? startedAt;
  Duration? knownDuration;

  @override
  Duration get position {
    final started = startedAt;
    if (started == null) return startAt;
    final elapsed = startAt + DateTime.now().difference(started);
    final total = knownDuration;
    if (total != null && elapsed > total) return total;
    return elapsed;
  }

  @override
  Duration? get duration => knownDuration;
}
