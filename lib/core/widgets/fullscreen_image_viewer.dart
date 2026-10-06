import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:itaaleem/core/widgets/secure_screen.dart';

/// Full-screen viewer for a tapped image: black background, pinch-to-zoom
/// via [InteractiveViewer], and a close button. Used e.g. by the account
/// tab's profile picture.
class FullscreenImageViewer extends StatelessWidget {
  const FullscreenImageViewer({super.key, required this.imageUrl});

  final String imageUrl;

  static Route<void> route(String imageUrl) {
    return MaterialPageRoute(
      builder: (_) => FullscreenImageViewer(imageUrl: imageUrl),
    );
  }

  /// Lesson attachment images open here — protected like videos / PDFs.
  @override
  Widget build(BuildContext context) =>
      SecureScreen(child: _buildViewer(context));

  Widget _buildViewer(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 5,
              child: Center(
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                  placeholder: (context, url) => const Center(
                    child: CircularProgressIndicator(color: Colors.white38),
                  ),
                  errorWidget: (context, url, error) => const Icon(
                    Icons.broken_image_rounded,
                    color: Colors.white38,
                    size: 48,
                  ),
                ),
              ),
            ),
          ),
          PositionedDirectional(
            top: 8,
            end: 8,
            child: SafeArea(
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black45,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.close_rounded, size: 26),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
