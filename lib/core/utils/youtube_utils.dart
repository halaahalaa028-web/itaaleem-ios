/// Helpers for recognising and embedding YouTube links.
final _idPatterns = <RegExp>[
  RegExp(r'[?&]v=([_\-a-zA-Z0-9]{11})'),
  RegExp(r'youtu\.be/([_\-a-zA-Z0-9]{11})'),
  RegExp(r'youtube(?:-nocookie)?\.com/(?:shorts|embed|live|v)/([_\-a-zA-Z0-9]{11})'),
];

bool isYouTubeUrl(String? url) {
  if (url == null || url.isEmpty) return false;
  final host = Uri.tryParse(url.trim())?.host.toLowerCase() ?? '';
  return host == 'youtu.be' ||
      host == 'youtube.com' ||
      host.endsWith('.youtube.com') ||
      host == 'youtube-nocookie.com' ||
      host.endsWith('.youtube-nocookie.com');
}

/// A YouTube link or a bare 11-character video id.
bool looksLikeYouTube(String? url) {
  if (url == null) return false;
  final t = url.trim();
  return isYouTubeUrl(t) ||
      (!t.contains('/') && RegExp(r'^[_\-a-zA-Z0-9]{11}$').hasMatch(t));
}

/// The 11-character video id of any common YouTube URL form, or `null`.
String? extractYouTubeId(String url) {
  final trimmed = url.trim();
  if (!trimmed.contains('http') && RegExp(r'^[_\-a-zA-Z0-9]{11}$').hasMatch(trimmed)) {
    return trimmed;
  }
  for (final pattern in _idPatterns) {
    final match = pattern.firstMatch(trimmed);
    if (match != null) return match.group(1);
  }
  return null;
}

/// `https://www.youtube.com/embed/<id>?autoplay=1&rel=0&modestbranding=1`,
/// or `null` if [url] has no recognisable id.
String? getYouTubeEmbedUrl(String url, {Duration startAt = Duration.zero}) {
  final id = extractYouTubeId(url);
  if (id == null) return null;
  final start = startAt.inSeconds > 0 ? '&start=${startAt.inSeconds}' : '';
  return 'https://www.youtube.com/embed/$id'
      '?autoplay=1&rel=0&modestbranding=1&playsinline=1&fs=0$start';
}
