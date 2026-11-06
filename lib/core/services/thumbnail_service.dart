/// Thumbnail generation and caching.
///
/// Originals are never copied or resized in place: we write small JPEGs into the
/// app cache dir and keep the source untouched (product rule: preserve quality).
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:path/path.dart' as p;

class ThumbnailService {
  ThumbnailService({required this.cacheDir, this.targetWidth = 512});

  final Directory cacheDir;
  final int targetWidth;
  final Map<String, File> _memo = <String, File>{};
  /// One shared future per photo so concurrent callers await the same decode
  /// instead of racing two writes to the same file.
  final Map<String, Future<File>> _inFlight = <String, Future<File>>{};

  File fileFor(String photoId) =>
      File(p.join(cacheDir.path, 'thumb_$photoId.jpg'));

  /// Returns the cached file if present.
  File? cached(String photoId) {
    final f = _memo[photoId] ?? fileFor(photoId);
    if (f.existsSync()) {
      _memo[photoId] = f;
      return f;
    }
    return null;
  }

  /// Decodes [bytes] (already loaded by the caller from whatever URI scheme the
  /// platform handed us) at a reduced size and writes a JPEG thumbnail.
  ///
  /// Uses `instantiateImageCodec` with `targetWidth`, so a 50 MP photo never
  /// materialises at full size in memory just to draw a 96 px tile.
  Future<File> generate(String photoId, Uint8List bytes) async {
    final existing = cached(photoId);
    if (existing != null) return existing;
    final running = _inFlight[photoId];
    if (running != null) return running;
    final future = _decode(photoId, bytes);
    _inFlight[photoId] = future;
    try {
      return await future;
    } finally {
      _inFlight.remove(photoId);
    }
  }

  Future<File> _decode(String photoId, Uint8List bytes) async {
    final codec = await instantiateImageCodec(
      bytes,
      targetWidth: targetWidth,
      allowUpscaling: false,
    );
    try {
      final frame = await codec.getNextFrame();
      final image = frame.image;
      try {
        final data = await image.toByteData(format: ImageByteFormat.png);
        if (data == null) {
          // Corrupt input: surface an error instead of caching a missing file.
          throw const FileSystemException(
              'thumbnail encode produced no data');
        }
        await cacheDir.create(recursive: true);
        final out = fileFor(photoId);
        await out.writeAsBytes(data.buffer.asUint8List(), flush: true);
        _memo[photoId] = out;
        return out;
      } finally {
        image.dispose();
      }
    } finally {
      codec.dispose();
    }
  }

  /// Removes a single cached thumbnail (called when a photo leaves a project).
  Future<void> evict(String photoId) async {
    _memo.remove(photoId);
    final f = fileFor(photoId);
    if (f.existsSync()) {
      try {
        await f.delete();
      } on FileSystemException catch (e) {
        debugPrint('thumbnail evict failed: $e');
      }
    }
  }

  /// Clears the whole cache (Settings -> manage cache).
  Future<int> clearAll() async {
    var freed = 0;
    if (!cacheDir.existsSync()) return 0;
    for (final e in cacheDir.listSync()) {
      if (e is File && p.basename(e.path).startsWith('thumb_')) {
        try {
          freed += e.lengthSync();
          e.deleteSync();
        } on FileSystemException catch (err) {
          debugPrint('cache clear failed for ${e.path}: $err');
        }
      }
    }
    _memo.clear();
    return freed;
  }

  Future<int> cacheSizeBytes() async {
    var total = 0;
    if (!cacheDir.existsSync()) return 0;
    for (final e in cacheDir.listSync()) {
      if (e is File && p.basename(e.path).startsWith('thumb_')) {
        total += e.lengthSync();
      }
    }
    return total;
  }

  /// Reads an image file's intrinsic size without decoding the full bitmap.
  static Future<({int width, int height})> decodeSize(Uint8List bytes) async {
    final codec = await instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final size = (width: frame.image.width, height: frame.image.height);
    frame.image.dispose();
    codec.dispose();
    return size;
  }
}
