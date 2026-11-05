/// Re-export so services can size images without importing `dart:ui` directly.
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

/// Reads an image's intrinsic size without keeping the bitmap.
Future<({int width, int height})> decodeImageSize(Uint8List bytes) async {
  try {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final size = (width: frame.image.width, height: frame.image.height);
    frame.image.dispose();
    codec.dispose();
    return size;
  } catch (e) {
    throw ArgumentError('unsupported or corrupt image: $e');
  }
}

/// Downscales an image to a max dimension and returns JPEG bytes.
Future<Uint8List?> resizedJpeg(
  Uint8List bytes, {
  required int maxDimension,
  int quality = 88,
}) async {
  final codec = await ui.instantiateImageCodec(
    bytes,
    targetWidth: maxDimension,
    allowUpscaling: false,
  );
  final frame = await codec.getNextFrame();
  final data = await frame.image.toByteData(
      format: ui.ImageByteFormat.rawStraightRgba);
  frame.image.dispose();
  codec.dispose();
  return data?.buffer.asUint8List();
}
