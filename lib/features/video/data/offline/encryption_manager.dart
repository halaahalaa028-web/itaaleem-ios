import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// AES-256-CTR encryption for downloaded lecture videos.
///
/// The key is generated once (on the very first download) and kept in its
/// own [FlutterSecureStorage] entry — never hardcoded, never stored
/// alongside the video itself. Deliberately a separate secure-storage
/// instance from [SecureStorageService]/`auth_token`, so logging out (which
/// clears that one) can never make already-downloaded videos
/// undecryptable.
///
/// Every file gets its own random base IV (`generateIv()`, stored on its
/// `offline_videos` row — see `OfflineDatabase`), never the file's plain
/// bytes. CTR mode is used specifically so the video can be split into
/// independently-decryptable [chunkSize]-byte chunks: [chunkIvFor] derives
/// chunk N's own IV by advancing the file's base IV (as a 128-bit counter)
/// by N chunks' worth of AES blocks — mathematically identical to running
/// one continuous keystream across the whole file, which is what lets
/// `LocalRangeServer` decrypt an arbitrary byte range by seeking straight to
/// the chunk(s) that overlap it instead of replaying the file from byte 0.
class EncryptionManager {
  EncryptionManager({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _keyStorageKey = 'offline_video_aes256_key_v1';

  /// Plaintext bytes per independently-decryptable chunk. 1 MiB balances
  /// how much a range request may have to decrypt beyond what it actually
  /// asked for against per-chunk overhead.
  static const int chunkSize = 1 << 20;

  static const int _aesBlockSize = 16;
  static const int _blocksPerChunk = chunkSize ~/ _aesBlockSize;

  /// Generates a fresh AES-256 key and persists it, overwriting any
  /// previous one. Callers almost always want [getKey] instead, which only
  /// generates one the first time it's needed.
  Future<Key> generateKey() async {
    final generated = Key.fromSecureRandom(32);
    await _storage.write(key: _keyStorageKey, value: generated.base64);
    _cachedKey = generated;
    return generated;
  }

  /// The app's single AES key, generating (and persisting) one on first use.
  Future<Key> getKey() async {
    // Cached: playback asks for the key once per 1 MiB chunk, and every
    // secure-storage read is a platform-channel round trip.
    final cached = _cachedKey;
    if (cached != null) return cached;
    final stored = await _storage.read(key: _keyStorageKey);
    final key = (stored != null && stored.isNotEmpty)
        ? Key.fromBase64(stored)
        : await generateKey();
    return _cachedKey = key;
  }

  Key? _cachedKey;

  /// A fresh random base IV for one file (base64-encoded, ready to store on
  /// its `offline_videos.encryptionIv`).
  String generateIv() => IV.fromSecureRandom(_aesBlockSize).base64;

  /// Chunk [chunkIndex]'s own IV, derived from the file's base [iv] — see
  /// the class doc.
  IV chunkIvFor(String iv, int chunkIndex) {
    final base = base64Decode(iv);
    return IV(_advanceCounter(base, chunkIndex * _blocksPerChunk));
  }

  // Pure-Dart AES over a whole 1 MiB chunk is slow enough to freeze the UI
  // (and stall the local video server) if run on the main isolate, so both
  // directions run in a short-lived worker isolate.
  Future<Uint8List> encryptChunk(Uint8List plainBytes, String iv) async {
    final keyBytes = (await getKey()).bytes;
    return Isolate.run(() {
      final encrypter = Encrypter(AES(Key(keyBytes), mode: AESMode.ctr, padding: null));
      return encrypter.encryptBytes(plainBytes, iv: IV.fromBase64(iv)).bytes;
    });
  }

  Future<Uint8List> decryptChunk(Uint8List encryptedBytes, String iv) async {
    final keyBytes = (await getKey()).bytes;
    return Isolate.run(() {
      final encrypter = Encrypter(AES(Key(keyBytes), mode: AESMode.ctr, padding: null));
      return Uint8List.fromList(
        encrypter.decryptBytes(Encrypted(encryptedBytes), iv: IV.fromBase64(iv)),
      );
    });
  }

  /// Treats [base] (16 bytes) as a big-endian 128-bit counter and returns
  /// it advanced by [blockOffset] AES blocks, wrapping on overflow (never
  /// reached in practice for any real video's block count).
  static Uint8List _advanceCounter(Uint8List base, int blockOffset) {
    final baseInt = BigInt.parse(
      base.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
      radix: 16,
    );
    final mod = BigInt.one << 128;
    final result = (baseInt + BigInt.from(blockOffset)) % mod;
    final hex = result.toRadixString(16).padLeft(32, '0');
    return Uint8List.fromList([
      for (var i = 0; i < 32; i += 2) int.parse(hex.substring(i, i + 2), radix: 16),
    ]);
  }
}

final encryptionManagerProvider = Provider<EncryptionManager>((ref) {
  return EncryptionManager();
});
