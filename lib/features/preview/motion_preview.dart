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

import 'package:flutter/material.dart';
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
      },
    );
    stream.addListener(listener);
  }

  /// Frees an image (called when a photo leaves the project).
  void evict(String photoId) {
    _images.remove(photoId)?.dispose();
    _streams.remove(photoId);
    _pending.remove(photoId);
  }

  @override
  void dispose() {
    _disposed = true;
    for (final img in _images.values) {
      img.dispose();
    }
    _images.clear();
    _streams.clear();
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
    final cam = motion.sample(t, fit, vp);

    final matrix = previewMatrix(
      cam: cam,
      fit: fit,
      vp: vp,
      outputSize: size,
      zoomMultiplier: draw.zoomMultiplier,
      offsetX: draw.offsetX,
      offsetY: draw.offsetY,
    );

    final paint = Paint()
      ..filterQuality = FilterQuality.medium
      ..isAntiAlias = true
      ..color = Colors.white.withValues(alpha: draw.alpha.clamp(0.0, 1.0));
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
      old.showMotionPath != showMotionPath;
}
