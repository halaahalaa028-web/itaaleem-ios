import 'package:cached_network_image/cached_network_image.dart';
import 'package:itaaleem/core/widgets/secure_screen.dart';
import 'package:flutter/material.dart';

/// Full-screen viewer for a tapped channel message image: black background,
/// pinch-to-zoom via [InteractiveViewer], and a close button. Pushed as a
/// normal route (not a tab), so [SecureScreen]'s own `initState`/`dispose`
/// correctly toggle `FLAG_SECURE` on entry/exit here — unlike the channel
/// tab itself, this screen isn't kept alive in an `IndexedStack`. There is
/// no download/share button and no long-press handler anywhere in this
/// widget, so there's nothing here to save the image with.
class ChannelImageViewerScreen extends StatelessWidget {
  const ChannelImageViewerScreen({super.key, required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return SecureScreen(
      child: Scaffold(
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
      ),
    );
  }
}
