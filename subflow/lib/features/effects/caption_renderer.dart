import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'caption_effect.dart';
import 'caption_preset.dart';

/// The single caption renderer used by the gallery previews *and* the editor
/// overlay. Phase 6 sends the same `CaptionPreset` (`toMap()`) to the native
/// renderer instead of re-implementing the effect, so preview and export cannot
/// drift apart.
///
/// Painting order: background box -> active-word backdrop -> glow -> shadow ->
/// stroke -> fill. Each layer is a separately laid-out `TextPainter` because a
/// span colour would override a parent `foreground` paint (a Flutter detail that
/// silently breaks multi-layer text if ignored).
class CaptionPainter extends CustomPainter {
  CaptionPainter({
    required this.preset,
    required this.text,
    this.enter = 1,
    this.exit = 0,
    this.activeWord = -1,
    this.wordFills = const <double>[],
    this.pulsePhase = 0,
  });

  final CaptionPreset preset;
  final String text;

  /// 0..1 entrance / exit progress.
  final double enter;
  final double exit;

  /// Index of the word being spoken, -1 when the project has no word timings.
  final int activeWord;
  final List<double> wordFills;
  final double pulsePhase;

  static const double _activeBoost = 0.14;

  @override
  void paint(Canvas canvas, Size size) {
    if (text.trim().isEmpty || size.isEmpty) return;

    final double shortEdge = size.shortestSide;
    final double baseSize = (shortEdge * preset.fontScale).clamp(10.0, size.height * 0.42).toDouble();
    final double k = preset.effects.intensity.clamp(0.2, 2.5).toDouble();
    final Curve curve = preset.effects.easing.curve;
    final double e = curve.transform(enter.clamp(0.0, 1.0).toDouble());
    final double x = curve.transform(exit.clamp(0.0, 1.0).toDouble());

    double scale = 1;
    double rotation = 0;
    double opacity = 1;
    double blurSigma = 0;
    Offset shift = Offset.zero;

    switch (preset.effects.enter) {
      case CaptionAnimation.none:
        break;
      case CaptionAnimation.fade:
        opacity *= e;
        break;
      case CaptionAnimation.slideUp:
        shift += Offset(0, (1 - e) * 0.09 * shortEdge * k);
        opacity *= e;
        break;
      case CaptionAnimation.slideDown:
        shift += Offset(0, -(1 - e) * 0.09 * shortEdge * k);
        opacity *= e;
        break;
      case CaptionAnimation.slideLeft:
        shift += Offset(-(1 - e) * 0.14 * size.width * k, 0);
        opacity *= e;
        break;
      case CaptionAnimation.slideRight:
        shift += Offset((1 - e) * 0.14 * size.width * k, 0);
        opacity *= e;
        break;
      case CaptionAnimation.zoomIn:
        scale = 0.55 + 0.45 * e;
        opacity *= e;
        break;
      case CaptionAnimation.zoomOut:
        scale = 1.45 - 0.45 * e;
        opacity *= e;
        break;
      case CaptionAnimation.pop:
        scale = 0.35 + 0.65 * e;
        opacity *= math.min(1.0, e * 1.6);
        break;
      case CaptionAnimation.bounce:
        shift += Offset(0, -(1 - e) * 0.12 * shortEdge * k);
        opacity *= math.min(1.0, e * 1.8);
        break;
      case CaptionAnimation.rotate:
        rotation = (1 - e) * 0.22 * k;
        scale = 1 + (1 - e) * 0.14;
        opacity *= e;
        break;
      case CaptionAnimation.blurIn:
        blurSigma = (1 - e) * 9 * k;
        opacity *= e;
        break;
      case CaptionAnimation.elastic:
        scale = 0.45 + 0.55 * e;
        opacity *= math.min(1.0, e * 2);
        break;
      case CaptionAnimation.shake:
        shift += Offset(math.sin(enter * math.pi * 8) * 0.018 * size.width * k * (1 - e), 0);
        opacity *= math.min(1.0, e * 2);
        break;
      case CaptionAnimation.glowPulse:
      case CaptionAnimation.typewriter:
      case CaptionAnimation.wordReveal:
        opacity *= math.min(1.0, e * 2);
        break;
    }

    switch (preset.effects.exit) {
      case CaptionExit.none:
        break;
      case CaptionExit.fadeOut:
        opacity *= 1 - x;
        break;
      case CaptionExit.zoomOut:
        scale *= 1 - 0.22 * x;
        opacity *= 1 - x;
        break;
      case CaptionExit.slideDown:
        shift += Offset(0, x * 0.08 * shortEdge * k);
        opacity *= 1 - x;
        break;
      case CaptionExit.slideUp:
        shift += Offset(0, -x * 0.08 * shortEdge * k);
        opacity *= 1 - x;
        break;
      case CaptionExit.zoomIn:
        scale *= 1 + 0.22 * x;
        opacity *= 1 - x;
        break;
      case CaptionExit.rotateOut:
        rotation += x * 0.18 * k;
        opacity *= 1 - x;
        break;
      case CaptionExit.popOut:
        scale *= 1 - 0.45 * x;
        opacity *= 1 - Curves.easeInCubic.transform(x.clamp(0.0, 1.0).toDouble());
        break;
      case CaptionExit.blurOut:
        blurSigma += x * 10 * k;
        opacity *= 1 - x;
        break;
    }

    final _Prepared prepared = _prepare(baseSize, size.width * preset.widthFraction, e);
    if (prepared.fill.width <= 0) return;

    final Offset origin = Offset(
      (size.width - prepared.fill.width) / 2,
      (size.height * preset.positionY - prepared.fill.height / 2)
          .clamp(0.0, math.max(0.0, size.height - prepared.fill.height))
          .toDouble(),
    );
    final Rect textRect = origin & prepared.fill.size;
    final Offset center = textRect.center;

    canvas.save();
    if (opacity < 0.999) {
      canvas.saveLayer(
        Offset.zero & size,
        Paint()..color = Colors.white.withOpacity(opacity.clamp(0.0, 1.0).toDouble()),
      );
    }
    canvas.translate(center.dx + shift.dx, center.dy + shift.dy);
    if (rotation != 0) canvas.rotate(rotation);
    if (scale != 1) canvas.scale(scale);
    canvas.translate(-center.dx, -center.dy);

    if (preset.boxBackground) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          textRect.inflate(baseSize * 0.28),
          Radius.circular(
            preset.backgroundRadius == 0 ? baseSize * 0.15 : preset.backgroundRadius,
          ),
        ),
        Paint()
          ..color = Color(preset.backgroundColor).withOpacity(preset.backgroundOpacity.clamp(0.0, 1.0).toDouble()),
      );
    }

    if (preset.effects.wordEffect == CaptionWordEffect.activeBackground &&
        activeWord >= 0 &&
        activeWord < prepared.wordRects.length) {
      final Rect? rect = prepared.wordRects[activeWord];
      if (rect != null) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect.inflate(baseSize * 0.12), Radius.circular(baseSize * 0.16)),
          Paint()..color = preset.accent.withOpacity(0.92),
        );
      }
    }

    if (preset.effects.wordEffect == CaptionWordEffect.activeUnderline &&
        activeWord >= 0 &&
        activeWord < prepared.wordRects.length) {
      final Rect? rect = prepared.wordRects[activeWord];
      if (rect != null) {
        final double thickness = math.max(2.0, baseSize * 0.09);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(rect.left, rect.bottom + thickness * 0.6, rect.width, thickness),
            Radius.circular(thickness),
          ),
          Paint()..color = preset.accent,
        );
      }
    }

    final double pulse = preset.effects.pulse
        ? 1 + 0.35 * (0.5 + 0.5 * math.sin(pulsePhase * math.pi * 2))
        : 1.0;

    if (preset.glowRadius > 0) {
      _layer(canvas, prepared.glow, origin, blurSigma + preset.glowRadius * 0.45 * pulse);
    }
    if (preset.shadowBlur > 0) {
      _layer(
        canvas,
        prepared.shadow,
        origin,
        blurSigma + preset.shadowBlur * 0.3,
        offset: Offset(0, preset.shadowOffsetY),
      );
    }
    if (preset.strokeWidth > 0) {
      _layer(canvas, prepared.stroke, origin, blurSigma);
    }
    _layer(canvas, prepared.fill, origin, blurSigma);

    if (opacity < 0.999) canvas.restore();
    canvas.restore();
  }

  void _layer(Canvas canvas, TextPainter painter, Offset origin, double sigma, {Offset offset = Offset.zero}) {
    if (sigma > 0.05) {
      canvas.saveLayer(
        (origin & painter.size).inflate(sigma * 3 + offset.dy.abs() + 8),
        Paint()
          ..imageFilter = ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma, tileMode: TileMode.decal),
      );
      painter.paint(canvas, origin + offset);
      canvas.restore();
    } else {
      painter.paint(canvas, origin + offset);
    }
  }

  // ---------------------------------------------------------------- building
  _Prepared _prepare(double fontSize, double maxWidth, double easedEnter) {
    final List<_Token> tokens = _tokenize(preset.uppercase ? text.toUpperCase() : text);
    final int wordCount = tokens.where((_Token t) => !t.isSpace).length;

    int revealLimit = wordCount;
    if (preset.effects.enter == CaptionAnimation.wordReveal) {
      revealLimit = (wordCount * easedEnter).ceil();
    }
    int typeBudget = -1;
    final String display = preset.uppercase ? text.toUpperCase() : text;
    if (preset.effects.enter == CaptionAnimation.typewriter) {
      typeBudget = (display.length * easedEnter).floor();
    }

    final _Visibility visibility = _Visibility(
      revealLimit: revealLimit,
      typeBudget: typeBudget,
      wordEffect: preset.effects.wordEffect,
      activeWord: activeWord,
      wordFills: wordFills,
      accent: preset.accent,
      primary: preset.primary,
      gradientActive: preset.hasGradient && preset.effects.wordEffect == CaptionWordEffect.none,
    );

    double sizeOf(int wordIndex) {
      final bool isActive = wordIndex == activeWord;
      switch (preset.effects.wordEffect) {
        case CaptionWordEffect.activeScale:
          return isActive ? fontSize * (1 + _activeBoost) : fontSize;
        case CaptionWordEffect.wordPop:
          return isActive ? fontSize * (1 + _activeBoost * 1.5) : fontSize;
        default:
          return fontSize;
      }
    }

    // `colorOf == null` leaves the span colour unset so the layer's own
    // foreground paint (stroke) or solid colour wins. Setting both a span colour
    // and a parent `foreground` is ambiguous in SkParagraph, so it is avoided.
    List<InlineSpan> spansFor(Color? Function(int wordIndex)? colorOf) {
      final List<InlineSpan> spans = <InlineSpan>[];
      int offset = 0;
      int wordIndex = 0;
      for (final _Token token in tokens) {
        if (token.isSpace) {
          spans.add(TextSpan(text: token.text));
          offset += token.text.length;
          continue;
        }
        final bool hidden = visibility.isHidden(wordIndex, offset);
        String content = token.text;
        if (visibility.isPartial(wordIndex, offset)) {
          content = token.text.substring(0, visibility.visibleChars(offset));
        } else if (hidden) {
          content = '';
        }
        spans.add(TextSpan(
          text: content,
          style: TextStyle(
            fontFamily: preset.fontFamily,
            fontSize: sizeOf(wordIndex),
            fontWeight: _fontWeight(preset.fontWeight),
            height: preset.lineHeight,
            letterSpacing: preset.letterSpacing,
            color: colorOf == null || content.isEmpty ? null : colorOf(wordIndex),
          ),
        ));
        wordIndex++;
        offset += token.text.length;
      }
      return spans;
    }

    TextPainter layout(List<InlineSpan> spans, TextStyle style) => TextPainter(
          text: TextSpan(style: style, children: spans),
          textDirection: preset.direction,
          textAlign: TextAlign.center,
          maxLines: 6,
          ellipsis: '…',
        )..layout(maxWidth: maxWidth);

    final TextStyle baseStyle = TextStyle(
      fontFamily: preset.fontFamily,
      fontSize: fontSize,
      fontWeight: _fontWeight(preset.fontWeight),
      height: preset.lineHeight,
      letterSpacing: preset.letterSpacing,
    );

    final Paint fillPaint = Paint()
      ..isAntiAlias = true
      ..color = preset.primary;
    if (visibility.gradientActive) {
      fillPaint.shader = LinearGradient(
        colors: <Color>[preset.primary, Color(preset.gradientEnd!)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, maxWidth, fontSize * 2.4));
    }

    final TextPainter fill = layout(
      visibility.gradientActive
          ? spansFor(null)
          : spansFor((int index) => visibility.colorFor(index)),
      visibility.gradientActive
          ? baseStyle.copyWith(foreground: fillPaint)
          : baseStyle.copyWith(color: preset.primary),
    );

    final TextPainter stroke = preset.strokeWidth > 0
        ? layout(
            spansFor(null),
            baseStyle.copyWith(
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = preset.strokeWidth
                ..strokeJoin = StrokeJoin.round
                ..isAntiAlias = true
                ..color = Color(preset.strokeColor),
            ),
          )
        : fill;

    final TextPainter shadow = preset.shadowBlur > 0
        ? layout(spansFor(null), baseStyle.copyWith(color: Color(preset.shadowColor)))
        : fill;

    final TextPainter glow = preset.glowRadius > 0
        ? layout(spansFor(null), baseStyle.copyWith(color: Color(preset.glowColor)))
        : fill;

    final List<Rect?> wordRects = List<Rect?>.filled(wordCount, null);
    final bool needsWordRects = preset.effects.wordEffect == CaptionWordEffect.activeBackground ||
        preset.effects.wordEffect == CaptionWordEffect.activeUnderline;
    if (needsWordRects && easedEnter >= 0.999) {
      int offset = 0;
      int wordIndex = 0;
      for (final _Token token in tokens) {
        if (token.isSpace) {
          offset += token.text.length;
          continue;
        }
        final int end = math.min(offset + token.text.length, display.length);
        try {
          final List<TextBox> boxes = fill.getBoxesForSelection(
            TextSelection(baseOffset: offset, extentOffset: end),
          );
          if (boxes.isNotEmpty) {
            Rect rect = boxes.first.toRect();
            for (final TextBox box in boxes) {
              rect = rect.expandToInclude(box.toRect());
            }
            wordRects[wordIndex] = rect;
          }
        } on Object {
          // Out-of-range selection is not fatal: the backdrop is decoration.
        }
        wordIndex++;
        offset = end;
      }
    }

    return _Prepared(fill: fill, stroke: stroke, shadow: shadow, glow: glow, wordRects: wordRects);
  }

  static FontWeight _fontWeight(int weight) {
    switch (weight) {
      case 300:
        return FontWeight.w300;
      case 400:
        return FontWeight.w400;
      case 500:
        return FontWeight.w500;
      case 600:
        return FontWeight.w600;
      case 800:
        return FontWeight.w800;
      case 900:
        return FontWeight.w900;
      default:
        return FontWeight.w700;
    }
  }

  static List<_Token> _tokenize(String input) {
    final List<_Token> tokens = <_Token>[];
    int index = 0;
    while (index < input.length) {
      final bool space = _isSpace(input.codeUnitAt(index));
      final int start = index;
      while (index < input.length && _isSpace(input.codeUnitAt(index)) == space) {
        index++;
      }
      tokens.add(_Token(input.substring(start, index), space));
    }
    return tokens;
  }

  static bool _isSpace(int codeUnit) =>
      codeUnit == 0x20 || codeUnit == 0x09 || codeUnit == 0x0A || codeUnit == 0x0D || codeUnit == 0x00A0;

  @override
  bool shouldRepaint(CaptionPainter old) =>
      old.text != text ||
      old.preset.id != preset.id ||
      old.enter != enter ||
      old.exit != exit ||
      old.activeWord != activeWord ||
      old.pulsePhase != pulsePhase;

  @override
  bool hitTest(Offset position) => false;
}

class _Token {
  const _Token(this.text, this.isSpace);

  final String text;
  final bool isSpace;
}

/// Per-word visibility and colour decisions, shared by every layer so metrics
/// stay identical across the stroke/shadow/fill painters.
class _Visibility {
  const _Visibility({
    required this.revealLimit,
    required this.typeBudget,
    required this.wordEffect,
    required this.activeWord,
    required this.wordFills,
    required this.accent,
    required this.primary,
    required this.gradientActive,
  });

  final int revealLimit;
  final int typeBudget;
  final CaptionWordEffect wordEffect;
  final int activeWord;
  final List<double> wordFills;
  final Color accent;
  final Color primary;
  final bool gradientActive;

  bool isHidden(int wordIndex, int offset) {
    if (wordIndex >= revealLimit) return true;
    if (typeBudget >= 0 && offset >= typeBudget) return true;
    return false;
  }

  bool isPartial(int wordIndex, int offset) =>
      typeBudget >= 0 && offset < typeBudget && offset + length > typeBudget;

  int visibleChars(int offset) => (typeBudget - offset).clamp(0, 1 << 20).toInt();

  Color colorFor(int wordIndex) {
    final bool isActive = wordIndex == activeWord;
    final bool past = wordIndex < activeWord;
    switch (wordEffect) {
      case CaptionWordEffect.none:
        return primary;
      case CaptionWordEffect.karaokeFill:
        if (isActive) {
          final double fill = wordIndex < wordFills.length ? wordFills[wordIndex] : 0;
          return Color.lerp(primary, accent, fill.clamp(0.0, 1.0).toDouble()) ?? accent;
        }
        return past ? accent : primary;
      case CaptionWordEffect.activeColor:
      case CaptionWordEffect.activeScale:
      case CaptionWordEffect.wordPop:
        return isActive ? accent : primary;
      case CaptionWordEffect.activeBackground:
        return isActive ? _contrastOn(accent) : primary;
      case CaptionWordEffect.activeUnderline:
        return isActive ? accent : primary;
      case CaptionWordEffect.neighborDim:
        return isActive
            ? primary
            : primary.withOpacity(activeWord >= 0 ? 0.42 : 1.0);
    }
  }

  static Color _contrastOn(Color background) {
    final double luminance = background.computeLuminance();
    return luminance > 0.55 ? const Color(0xFF101010) : Colors.white;
  }
}

class _Prepared {
  const _Prepared({
    required this.fill,
    required this.stroke,
    required this.shadow,
    required this.glow,
    required this.wordRects,
  });

  final TextPainter fill;
  final TextPainter stroke;
  final TextPainter shadow;
  final TextPainter glow;
  final List<Rect?> wordRects;
}

/// Stateless caption surface driven by explicit animation progress.
class CaptionSurface extends StatelessWidget {
  const CaptionSurface({
    required this.preset,
    required this.text,
    super.key,
    this.enter = 1,
    this.exit = 0,
    this.activeWord = -1,
    this.wordFills = const <double>[],
    this.pulsePhase = 0,
  });

  final CaptionPreset preset;
  final String text;
  final double enter;
  final double exit;
  final int activeWord;
  final List<double> wordFills;
  final double pulsePhase;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: CaptionPainter(
          preset: preset,
          text: text,
          enter: enter,
          exit: exit,
          activeWord: activeWord,
          wordFills: wordFills,
          pulsePhase: pulsePhase,
        ),
        size: Size.infinite,
      ),
    );
  }
}

/// Looping audition used by the gallery: enter, hold with word highlight, exit.
class AnimatedCaptionPreview extends StatefulWidget {
  const AnimatedCaptionPreview({
    required this.preset,
    required this.text,
    super.key,
    this.cycleMs = 2600,
    this.animate = true,
  });

  final CaptionPreset preset;
  final String text;
  final int cycleMs;
  final bool animate;

  @override
  State<AnimatedCaptionPreview> createState() => _AnimatedCaptionPreviewState();
}

class _AnimatedCaptionPreviewState extends State<AnimatedCaptionPreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: widget.cycleMs),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        final double t = widget.animate ? _controller.value : 0.7;
        const double enterSpan = 0.18;
        const double exitStart = 0.86;
        final double enterT = (t / enterSpan).clamp(0.0, 1.0).toDouble();
        final double exitT = ((t - exitStart) / (1 - exitStart)).clamp(0.0, 1.0).toDouble();
        final double body = ((t - enterSpan) / (exitStart - enterSpan)).clamp(0.0, 1.0).toDouble();
        final int wordCount =
            widget.text.split(RegExp(r'\s+')).where((String w) => w.isNotEmpty).length;
        final int active =
            wordCount == 0 ? -1 : (body * wordCount).floor().clamp(0, wordCount - 1).toInt();
        return CaptionSurface(
          preset: widget.preset,
          text: widget.text,
          enter: enterT,
          exit: exitT,
          activeWord: active,
          wordFills: List<double>.filled(wordCount, 1),
          pulsePhase: t,
        );
      },
    );
  }
}
