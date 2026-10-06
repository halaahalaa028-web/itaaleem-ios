import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt_explode;

/// HLS resolution is disabled for YouTube VOD content.
/// hlsManifestUrl returns NULL for non-live videos.
/// Kept for potential future use with live streams.

/// One video rendition of a YouTube HLS master playlist.
class HlsVariant {
  const HlsVariant({required this.height, required this.bandwidth});

  final int height;

  /// The variant's `BANDWIDTH` — what mpv's `hls-bitrate` matches against.
  final int bandwidth;
}

/// A YouTube video's HLS master playlist plus the renditions it offers.
class HlsSource {
  const HlsSource({required this.masterUrl, required this.variants});

  final String masterUrl;

  /// H.264 renditions only (one per height, tallest first).
  final List<HlsVariant> variants;
}

/// Resolves a video's HLS master playlist through the same iOS player client
/// youtube_explode uses.
///
/// youtube_explode's own `getHttpLiveStreamUrl` only works for live streams,
/// and its manifest exposes just the per-variant playlists — which are
/// video-only (audio lives in a separate `#EXT-X-MEDIA` group). Playing a
/// variant directly would be silent, so the *master* playlist is what gets
/// played, and the rendition is picked with mpv's `hls-bitrate`.
class YoutubeHlsResolver {
  const YoutubeHlsResolver._();

  static const _heightCap = 1080;

  /// `null` when the video has no HLS playlist or anything goes wrong — the
  /// caller then falls back to the muxed stream.
  static Future<HlsSource?> resolve(String videoId) async {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
      ),
    );
    try {
      final iosClient = yt_explode.YoutubeApiClient.ios;
      final userAgent =
          (iosClient.payload['context'] as Map)['client']['userAgent']
              as String;
      final headers = <String, dynamic>{
        ...iosClient.headers,
        'User-Agent': userAgent,
        'Content-Type': 'application/json',
      };

      final response = await dio.post<Map<String, dynamic>>(
        iosClient.apiUrl,
        data: {
          ...iosClient.payload,
          'videoId': videoId,
          'contentCheckOk': true,
          'racyCheckOk': true,
        },
        options: Options(headers: headers),
      );
      final body = response.data;
      final status = body?['playabilityStatus']?['status'];
      final masterUrl = body?['streamingData']?['hlsManifestUrl'] as String?;
      if (kDebugMode) {
        if (masterUrl == null) {
          debugPrint('>>> YT HLS: hlsManifestUrl is NULL');
        } else {
          debugPrint('>>> YT HLS: hlsManifestUrl = $masterUrl');
        }
      }
      if (status != 'OK' || masterUrl == null || masterUrl.isEmpty) {
        if (kDebugMode) {
          debugPrint('>>> YT HLS: no master playlist (status=$status)');
        }
        return null;
      }

      final playlist = await dio.get<String>(
        masterUrl,
        options: Options(
          headers: {'User-Agent': userAgent},
          responseType: ResponseType.plain,
        ),
      );
      if (kDebugMode) {
        final text = playlist.data ?? '';
        debugPrint(
          '>>> YT HLS: response status=${playlist.statusCode}, body (first 500): '
          '${text.substring(0, math.min(500, text.length))}',
        );
      }
      final variants = parseVariants(playlist.data ?? '');
      if (kDebugMode) {
        debugPrint(
          '>>> YT HLS: master ok, variants: '
          '${variants.map((v) => '${v.height}p@${v.bandwidth}').join(', ')}',
        );
      }
      if (variants.isEmpty) return null;
      return HlsSource(masterUrl: masterUrl, variants: variants);
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('>>> YT HLS: resolve failed = $e\n$stackTrace');
      }
      return null;
    } finally {
      dio.close();
    }
  }

  /// The H.264 (`avc1`) `#EXT-X-STREAM-INF` entries up to 1080p, best
  /// bandwidth per height, tallest first. VP9 is skipped: it decodes slower on
  /// the CPU and every height has an H.264 twin up to 1080p.
  @visibleForTesting
  static List<HlsVariant> parseVariants(String master) {
    final byHeight = <int, HlsVariant>{};
    for (final line in master.split('\n')) {
      if (!line.startsWith('#EXT-X-STREAM-INF:')) continue;
      final resolution = RegExp(r'RESOLUTION=(\d+)x(\d+)').firstMatch(line);
      final bandwidth = RegExp(r'[:,]BANDWIDTH=(\d+)').firstMatch(line);
      if (resolution == null || bandwidth == null) continue;
      if (!line.contains('avc1')) continue;
      final height = int.parse(resolution.group(2)!);
      if (height > _heightCap) continue;
      final variant = HlsVariant(
        height: height,
        bandwidth: int.parse(bandwidth.group(1)!),
      );
      final best = byHeight[height];
      if (best == null || variant.bandwidth > best.bandwidth) {
        byHeight[height] = variant;
      }
    }
    return byHeight.values.toList()
      ..sort((a, b) => b.height.compareTo(a.height));
  }
}
