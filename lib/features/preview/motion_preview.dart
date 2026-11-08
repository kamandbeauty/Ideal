/// Live motion preview.
///
/// This is the visible proof that preview and export share one motion model:
/// each timeline layer is drawn with the transform derived in
/// `preview_transform.dart` (verified numerically against the native renderer),
/// using the same `sampleKeyframes` + `clampCamera` pipeline the export request
/// is built from. Only the pixel resolution differs.
library;

import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

// Viewport/ImageFit are the camera_math.dart classes, not the Flutter ones.
import 'package:flutter/material.dart' hide Viewport, ImageFit;
import 'package:flutter/painting.dart' show MatrixUtils;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/photo_item.dart';
import '../../core/models/project.dart';
import '../motion/camera_math.dart';
import '../transitions/timeline_engine.dart';
import 'playback_controller.dart';
import 'preview_transform.dart';

/// Decoded preview images, kept alive across frames and disposed with the app.
class PreviewImageCache extends ChangeNotifier {
  final Map<String, ui.Image> _images = <String, ui.Image>{};
  final Map<String, ImageStream> _streams = <String, ImageStream>{};
  final Map<String, ImageStreamListener> _listeners =
      <String, ImageStreamListener>{};
  final Set<String> _pending = <String>{};
  bool _disposed = false;

  ui.Image? imageFor(String photoId) => _images[photoId];

  bool isReady(String photoId) => _images.containsKey(photoId);

  void request(String photoId, ImageProvider provider) {
    if (_images.containsKey(photoId) || _pending.contains(photoId)) return;
    _pending.add(photoId);
    final stream = provider.resolve(const ImageConfiguration());
    _streams[photoId] = stream;
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (ImageInfo info, bool synchronouslyLoaded) {
        _listeners.remove(photoId);
        if (_disposed) {
          info.dispose();
          return;
        }
        _images[photoId]?.dispose();
        _images[photoId] = info.image;
        _pending.remove(photoId);
        notifyListeners();
      },
      onError: (Object error, StackTrace? st) {
        _pending.remove(photoId);
        _streams.remove(photoId)?.removeListener(listener);
        _listeners.remove(photoId);
      },
    );
    _listeners[photoId] = listener;
    stream.addListener(listener);
  }

  /// Frees an image (called when a photo leaves the project).
  void evict(String photoId) {
    _images.remove(photoId)?.dispose();
    _detachStream(photoId);
    _pending.remove(photoId);
  }

  /// Unsubscribes the decode listener so a late callback can neither leak the
  /// decoded image nor resurrect an evicted entry.
  void _detachStream(String photoId) {
    final listener = _listeners.remove(photoId);
    final stream = _streams.remove(photoId);
    if (listener != null && stream != null) stream.removeListener(listener);
  }

  @override
  void dispose() {
    _disposed = true;
    for (final key in _images.keys.toList()) {
      _detachStream(key);
    }
    for (final img in _images.values) {
      img.dispose();
    }
    _images.clear();
    super.dispose();
  }
}

final previewImageCacheProvider = ChangeNotifierProvider<PreviewImageCache>(
  (ref) => PreviewImageCache(),
);

/// Draws the composite frame for a project at a point in time.
class MotionPreview extends ConsumerWidget {
  const MotionPreview({
    required this.project,
    required this.frame,
    this.imageFor,
    this.showSafeFrame = false,
    this.showMotionPath = false,
    this.activePhotoIndex,
    this.activeLocalTime,
    this.fillViewport = false,
    super.key,
  });

  final Project project;
  final FrameState frame;

  /// Resolves the display image for a photo. Defaults to the project thumbnail
  /// (cheap) and the preview screen can opt into full-resolution sources.
  final ImageProvider? Function(PhotoItem photo)? imageFor;

  final bool showSafeFrame;

  /// Overlays the camera path of the active photo (motion editor only).
  final bool showMotionPath;
  final int? activePhotoIndex;
  final double? activeLocalTime;

  /// When true the widget fills its parent instead of preserving aspect ratio.
  final bool fillViewport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cache = ref.watch(previewImageCacheProvider);
    final resolver = imageFor ?? _defaultImage(project);
    // Warm the cache for the photos that are about to be drawn.
    for (final layer in frame.layers) {
      if (layer.photoIndex < 0 || layer.photoIndex >= project.photos.length) {
        continue;
      }
      final photo = project.photos[layer.photoIndex];
      final provider = resolver(photo);
      if (provider != null) cache.request(photo.id, provider);
    }

    final painter = Stack(
      fit: StackFit.expand,
      children: <Widget>[
        const ColoredBox(color: Colors.black),
        RepaintBoundary(
          child: CustomPaint(
            painter: _TimelinePainter(
              project: project,
              frame: frame,
              cache: cache,
              resolver: resolver,
              showSafeFrame: showSafeFrame,
              showMotionPath: showMotionPath,
              activePhotoIndex: activePhotoIndex,
              activeLocalTime: activeLocalTime,
            ),
          ),
        ),
      ],
    );

    if (fillViewport) return ClipRect(child: painter);
    return AspectRatio(
      aspectRatio: project.outputAspect,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: painter,
      ),
    );
  }

  /// Default image source: the cached thumbnail when available (cheap, always
  /// present once imported), otherwise the original file.
  static ImageProvider? Function(PhotoItem) _defaultImage(Project project) {
    return (PhotoItem photo) {
      final thumb = photo.thumbnailPath;
      if (thumb != null && thumb.isNotEmpty) return FileImage(File(thumb));
      final src = photo.sourceUri;
      if (src.isNotEmpty && !src.startsWith('content://')) {
        final f = File(src);
        if (f.existsSync()) return FileImage(f);
      }
      return null;
    };
  }
}

/// Paints every visible timeline layer with the verified camera transform.
class _TimelinePainter extends CustomPainter {
  _TimelinePainter({
    required this.project,
    required this.frame,
    required this.cache,
    required this.resolver,
    required this.showSafeFrame,
    required this.showMotionPath,
    required this.activePhotoIndex,
    required this.activeLocalTime,
  });

  final Project project;
  final FrameState frame;
  final PreviewImageCache cache;
  final ImageProvider? Function(PhotoItem photo) resolver;
  final bool showSafeFrame;
  final bool showMotionPath;
  final int? activePhotoIndex;
  final double? activeLocalTime;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final vp = Viewport(size.width / size.height);

    if (frame.layers.isEmpty) {
      _paintPlaceholder(canvas, size);
      return;
    }

    final draws = <DrawLayer>[];
    if (frame.layers.length == 1) {
      final l = frame.layers.first;
      draws.add(DrawLayer(photoIndex: l.photoIndex, localTime: l.localTime));
    } else {
      draws.addAll(transitionDrawLayers(frame.layers));
    }

    for (final draw in draws) {
      if (draw.alpha <= 0.002) continue;
      if (draw.photoIndex < 0 || draw.photoIndex >= project.photos.length) {
        continue;
      }
      _paintLayer(canvas, size, vp, draw);
    }

    _paintWatermark(canvas, size);

    if (showSafeFrame) {
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white24;
      canvas.drawRect(
          Rect.fromLTWH(0.75, 0.75, size.width - 1.5, size.height - 1.5), p);
    }
    if (showMotionPath && activePhotoIndex != null) {
      _paintMotionPath(canvas, size, vp);
    }
  }

  void _paintLayer(Canvas canvas, Size size, Viewport vp, DrawLayer draw) {
    final photo = project.photos[draw.photoIndex];
    final motion = photo.motion;
    final image = cache.imageFor(photo.id);
    if (motion == null || image == null) {
      _paintMissing(canvas, size, photo);
      return;
    }
    final fit = ImageFit.make(photo.width, photo.height, vp);
    final t = draw.freezeMotion
        ? photo.duration
        : draw.localTime.clamp(0.0, photo.duration);
    CameraState cam = motion.sample(t, fit, vp);

    // User zoom on top of the camera scale, clamped so zoom-out stops at
    // exact cover (the frame never reveals empty space).
    if (photo.zoomFactor != 1.0) {
      final minScale = minScaleAtRotation(fit, vp, cam.rotation);
      cam = cam.copyWith(
          scale: (cam.scale * photo.zoomFactor).clamp(minScale, 8.0).toDouble());
    }

    final matrix = previewMatrix(
      cam: cam,
      fit: fit,
      vp: vp,
      outputSize: size,
      zoomMultiplier: draw.zoomMultiplier,
      offsetX: draw.offsetX,
      offsetY: draw.offsetY,
    );

    final layerAlpha = (draw.alpha * photo.opacity).clamp(0.0, 1.0).toDouble();
    final paint = Paint()
      ..filterQuality = FilterQuality.medium
      ..isAntiAlias = true
      ..color = Colors.white.withValues(alpha: layerAlpha);
    if (draw.blurRadius > 0.5) {
      final sigma = draw.blurRadius * (size.height / 1080.0) * 0.55;
      paint.imageFilter = ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma);
    }

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.transform(matrix.storage);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      const Rect.fromLTWH(0, 0, 1, 1),
      paint,
    );
    canvas.restore();
  }

  /// Text watermark with its dark chip (spec: WatermarkSpec — the native
  /// renderer draws the identical layout from the same contract).
  void _paintWatermark(Canvas canvas, Size size) {
    final w = project.watermark;
    if (w == null || !w.visibleAt(frame.time)) return;

    final fontSize = (w.fontScale.clamp(0.01, 0.25) * size.height).toDouble();
    final tp = TextPainter(
      text: TextSpan(
        text: w.text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          color: Colors.white
              .withValues(alpha: w.opacity.clamp(0.0, 1.0).toDouble()),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final padX = fontSize * 0.5;
    final padY = fontSize * 0.3;
    final chip = Rect.fromLTWH(-padX, -padY, tp.width + padX * 2,
        tp.height + padY * 2);
    final margin = 0.02;
    double x;
    switch (w.col) {
      case 0:
        x = size.width * margin;
        break;
      case 2:
        x = size.width - size.width * margin - tp.width;
        break;
      default:
        x = (size.width - tp.width) / 2;
    }
    double y;
    switch (w.row) {
      case 0:
        y = size.height * margin;
        break;
      case 2:
        y = size.height - size.height * margin - tp.height;
        break;
      default:
        y = (size.height - tp.height) / 2;
    }

    canvas.save();
    canvas.translate(x, y);
    final chipPaint = Paint()
      ..color = Colors.black
          .withValues(alpha: (w.opacity * 0.45).clamp(0.0, 1.0).toDouble());
    canvas.drawRRect(
        RRect.fromRectAndRadius(chip, Radius.circular(fontSize * 0.3)), chipPaint);
    tp.paint(canvas, Offset.zero);
    canvas.restore();
  }

  void _paintMissing(Canvas canvas, Size size, PhotoItem photo) {
    final p = Paint()..color = const Color(0xFF1A1A24);
    canvas.drawRect(Offset.zero & size, p);
    final tp = TextPainter(
      text: TextSpan(
        text: photo.missing ? 'missing' : 'loading',
        style: const TextStyle(color: Colors.white24, fontSize: 12),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
        canvas, Offset((size.width - tp.width) / 2, (size.height - tp.height) / 2));
  }

  void _paintPlaceholder(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF111119));
  }

  /// Draws the camera path of the current shot: a dashed polyline through the
  /// sampled camera centres, with a dot for each keyframe.
  void _paintMotionPath(Canvas canvas, Size size, Viewport vp) {
    final index = activePhotoIndex!;
    if (index < 0 || index >= project.photos.length) return;
    final photo = project.photos[index];
    final motion = photo.motion;
    if (motion == null) return;
    final fit = ImageFit.make(photo.width, photo.height, vp);
    final path = Path();
    const steps = 64;
    for (var i = 0; i <= steps; i++) {
      final t = photo.duration * i / steps;
      final cam = motion.sample(t, fit, vp);
      // Camera centre in output pixels: the image point (cam.x, cam.y) maps
      // through the inverse of the camera transform, i.e. the viewport centre
      // plus the offset of that image point from the camera centre.
      final uv = imageToUv(cam.x, cam.y, fit);
      final m = previewMatrix(
          cam: cam, fit: fit, vp: vp, outputSize: size);
      final off = MatrixUtils.transformPoint(
          m, Offset(uv.u, uv.v));
      if (i == 0) {
        path.moveTo(off.dx, off.dy);
      } else {
        path.lineTo(off.dx, off.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = const Color(0xFF9B7BFF).withValues(alpha: 0.85),
    );
    // Keyframe markers
    for (final k in motion.keyframes) {
      final cam = motion.sample(k.time, fit, vp);
      final uv = imageToUv(cam.x, cam.y, fit);
      final m = previewMatrix(
          cam: cam, fit: fit, vp: vp, outputSize: size);
      final p = MatrixUtils.transformPoint(m, Offset(uv.u, uv.v));
      final isActive = activeLocalTime != null &&
          (activeLocalTime! - k.time).abs() < 0.05;
      canvas.drawCircle(
        p,
        isActive ? 6 : 4,
        Paint()
          ..color = isActive
              ? const Color(0xFF35D6A4)
              : const Color(0xFF7C5CFF),
      );
      canvas.drawCircle(
        p,
        isActive ? 6 : 4,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(_TimelinePainter old) =>
      old.frame.time != frame.time ||
      old.frame.playing != frame.playing ||
      !identical(old.project, project) ||
      old.activeLocalTime != activeLocalTime ||
      old.activePhotoIndex != activePhotoIndex ||
      old.showMotionPath != showMotionPath;
}
