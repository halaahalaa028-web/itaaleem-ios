import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:itaaleem/features/video/data/offline/encryption_manager.dart';
import 'package:itaaleem/features/video/data/offline/offline_database.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

/// Serves a downloaded, encrypted lecture video back to media_kit as plain
/// MP4 bytes over `http://127.0.0.1:{port}/video/{lessonId}` — decrypting
/// only the AES-CTR chunks (see [EncryptionManager]) that overlap whatever
/// byte range the player actually asked for, so seeking doesn't mean
/// decrypting from byte 0 every time, and a full unencrypted copy of the
/// video is never written to disk.
///
/// One server instance is meant to live for as long as offline playback is
/// on screen — [start] binds an OS-assigned loopback-only port, [stop]
/// closes it. Safe to call [start] again after [stop].
class LocalRangeServer {
  LocalRangeServer({required OfflineDatabase db, required EncryptionManager encryption})
    : _db = db,
      _encryption = encryption;

  final OfflineDatabase _db;
  final EncryptionManager _encryption;

  HttpServer? _server;

  /// Random per-launch secret every request must carry (`?t=`). The server is
  /// loopback-only, but any other app on the device could still reach
  /// 127.0.0.1 — without this it could read the decrypted video.
  final String _token = base64Url.encode(
    List<int>.generate(24, (_) => Random.secure().nextInt(256)),
  );

  int? get port => _server?.port;

  bool get isRunning => _server != null;

  Future<void> start() async {
    if (_server != null) return;
    final router = Router()
      ..get('/video/<lessonId>', _handleVideo)
      ..head('/video/<lessonId>', _handleVideo);
    _server = await shelf_io.serve(router.call, InternetAddress.loopbackIPv4, 0);
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  /// The URL to hand media_kit for [lessonId] — throws if [start] hasn't
  /// completed yet.
  String urlFor(int lessonId) {
    final boundPort = port;
    if (boundPort == null) {
      throw StateError('LocalRangeServer.start() has not completed yet');
    }
    return 'http://127.0.0.1:$boundPort/video/$lessonId?t=$_token';
  }

  Future<Response> _handleVideo(Request request) async {
    if (request.url.queryParameters['t'] != _token) return Response.forbidden('forbidden');
    final lessonId = int.tryParse(request.params['lessonId'] ?? '');
    if (lessonId == null) return Response.notFound('not found');

    final row = await _db.getByLessonId(lessonId);
    if (row == null || row.downloadStatus != 'completed') {
      return Response.notFound('not found');
    }
    if (row.localPath.isEmpty) return Response.notFound('not found');

    final file = File(row.localPath);
    if (!await file.exists()) return Response.notFound('not found');

    // The encrypted file is always exactly the same size as the plain
    // video — see EncryptionManager's class doc (AES-CTR, no padding).
    final totalSize = await file.length();
    if (totalSize == 0) return Response.notFound('not found');

    final rangeHeader = request.headers['range'];
    var start = 0;
    var end = totalSize - 1;
    if (rangeHeader != null) {
      final match = RegExp(r'^bytes=(\d*)-(\d*)$').firstMatch(rangeHeader.trim());
      if (match == null) {
        return Response(416, headers: {'Content-Range': 'bytes */$totalSize'});
      }
      final startGroup = match.group(1);
      final endGroup = match.group(2);
      if (startGroup == null || startGroup.isEmpty) {
        // Suffix range, e.g. "bytes=-500" — the last 500 bytes.
        final suffixLength = int.parse(endGroup!);
        start = totalSize - suffixLength;
        end = totalSize - 1;
      } else {
        start = int.parse(startGroup);
        end = (endGroup != null && endGroup.isNotEmpty)
            ? int.parse(endGroup)
            : totalSize - 1;
      }
    }
    start = start.clamp(0, totalSize - 1);
    end = end.clamp(start, totalSize - 1);
    final length = end - start + 1;

    if (kDebugMode) {
      debugPrint(
        '[LocalRangeServer] ${request.method} lesson=$lessonId '
        'range=$rangeHeader -> $start-$end/$totalSize',
      );
    }
    // Streamed chunk by chunk: a player's opening `Range: bytes=0-` covers
    // the whole file, and decrypting all of it before sending a single byte
    // makes the player time out.
    final Object body = request.method == 'HEAD'
        ? const <int>[]
        : _decryptedStream(row, file, start, length);

    final headers = <String, String>{
      'Content-Type': 'video/mp4',
      'Accept-Ranges': 'bytes',
      'Content-Length': '$length',
    };
    if (rangeHeader != null) {
      headers['Content-Range'] = 'bytes $start-$end/$totalSize';
      return Response(206, body: body, headers: headers);
    }
    return Response.ok(body, headers: headers);
  }

  /// Yields the decrypted bytes of [start, start+length), one whole chunk at
  /// a time (only the chunk(s) the range overlaps) — chunks are always
  /// decrypted from their own start (see [EncryptionManager.chunkIvFor]),
  /// never from an arbitrary mid-chunk offset.
  Stream<List<int>> _decryptedStream(
    OfflineVideo row,
    File file,
    int start,
    int length,
  ) async* {
    final chunkSize = EncryptionManager.chunkSize;
    final totalSize = await file.length();
    final firstChunk = start ~/ chunkSize;
    final lastChunk = (start + length - 1) ~/ chunkSize;
    final rangeEnd = start + length;

    final raf = await file.open(mode: FileMode.read);
    try {
      for (var chunkIndex = firstChunk; chunkIndex <= lastChunk; chunkIndex++) {
        final chunkStart = chunkIndex * chunkSize;
        final chunkEnd = chunkStart + chunkSize < totalSize
            ? chunkStart + chunkSize
            : totalSize;
        await raf.setPosition(chunkStart);
        final encryptedChunk = await raf.read(chunkEnd - chunkStart);
        final iv = _encryption.chunkIvFor(row.encryptionIv, chunkIndex).base64;
        final decryptedChunk = await _encryption.decryptChunk(
          Uint8List.fromList(encryptedChunk),
          iv,
        );
        // Trim to the requested range (only matters for the first/last chunk).
        final from = start > chunkStart ? start - chunkStart : 0;
        final to = rangeEnd < chunkEnd ? rangeEnd - chunkStart : chunkEnd - chunkStart;
        yield Uint8List.sublistView(decryptedChunk, from, to);
      }
    } finally {
      await raf.close();
    }
  }
}

final localRangeServerProvider = Provider<LocalRangeServer>((ref) {
  final server = LocalRangeServer(
    db: ref.watch(offlineDatabaseProvider),
    encryption: ref.watch(encryptionManagerProvider),
  );
  ref.onDispose(() => server.stop());
  return server;
});
