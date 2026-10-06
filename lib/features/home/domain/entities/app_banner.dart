/// One banner from `GET /banners` — the joined center's home-screen
/// banners.
class AppBanner {
  const AppBanner({
    required this.id,
    required this.imageUrl,
    this.title,
    this.linkUrl,
  });

  final int id;
  final String imageUrl;
  final String? title;
  final String? linkUrl;
}
