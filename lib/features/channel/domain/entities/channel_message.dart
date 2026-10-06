/// One broadcast message from `GET /channel` ("القناة"): text and/or an
/// image, optionally pinned to the top of the feed.
class ChannelMessage {
  const ChannelMessage({
    required this.id,
    required this.createdAt,
    this.text,
    this.imageUrl,
    this.isPinned = false,
  });

  final int id;
  final String? text;
  final String? imageUrl;
  final DateTime createdAt;
  final bool isPinned;
}
