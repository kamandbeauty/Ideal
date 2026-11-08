import 'dart:math' as math;
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import '../../core/time_us.dart';
import '../../models/subtitle.dart';
import '../../features/effects/caption_preset.dart';
import '../../shared/theme/app_colors.dart';

/// The pieces of the editing screen, laid out like the reference sheet: stage on
/// top, transport strip, timeline with a waveform, a tool row, then the style and
/// colour rows. Each widget is dumb - the screen owns the state - so the layout
/// can be reordered without touching behaviour.

/// Back arrow on the right (RTL), purple export pill on the left.
class StudioTopBar extends StatelessWidget {
  const StudioTopBar({
    required this.onBack,
    required this.onExport,
    this.exporting = false,
    this.title = '',
    super.key,
  });

  final VoidCallback onBack;
  final VoidCallback? onExport;
  final bool exporting;
  final String title;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Row(
        children: <Widget>[
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
            color: AppColors.textPrimary,
            tooltip: 'بازگشت',
          ),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 14),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onExport,
                borderRadius: BorderRadius.circular(20),
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: AppColors.accentGradient,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          exporting ? Icons.hourglass_top_rounded : Icons.ios_share_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          exporting ? 'در حال خروجی' : 'خروجی',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The video with the live caption on top and a selection frame around it - the
/// frame is what makes the preview read as "this caption is selected".
class CaptionStage extends StatelessWidget {
  const CaptionStage({
    required this.player,
    required this.caption,
    required this.hasCaption,
    this.onTap,
    super.key,
  });

  final Widget player;
  final Widget caption;
  final bool hasCaption;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: ColoredBox(
          color: Colors.black,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              player,
              if (hasCaption)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Center(
                      child: FractionallySizedBox(
                        widthFactor: 0.94,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.white.withOpacity(0.85),
                              width: 1.1,
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: caption,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Play/pause, position, undo/redo and fullscreen.
class StudioTransportRow extends StatelessWidget {
  const StudioTransportRow({
    required this.playing,
    required this.positionUs,
    required this.durationUs,
    required this.onPlayPause,
    required this.canUndo,
    required this.canRedo,
    required this.onUndo,
    required this.onRedo,
    required this.onFullscreen,
    super.key,
  });

  final bool playing;
  final int positionUs;
  final int durationUs;
  final VoidCallback onPlayPause;
  final bool canUndo;
  final bool canRedo;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onFullscreen;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Row(
        children: <Widget>[
          IconButton(
            onPressed: onPlayPause,
            icon: Icon(
              playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              size: 30,
            ),
            color: Colors.white,
            tooltip: playing ? 'توقف' : 'پخش',
          ),
          const SizedBox(width: 4),
          Text(
            '${TimeUs.compact(positionUs)} / ${TimeUs.compact(durationUs)}',
            textDirection: TextDirection.ltr,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary,
              fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
          const Spacer(),
          _IconTap(
            icon: Icons.undo_rounded,
            onTap: canUndo ? onUndo : null,
            tooltip: 'واگرد',
          ),
          _IconTap(
            icon: Icons.redo_rounded,
            onTap: canRedo ? onRedo : null,
            tooltip: 'ازنو',
          ),
          _IconTap(
            icon: Icons.fullscreen_rounded,
            onTap: onFullscreen,
            tooltip: 'تمام‌صفحه',
          ),
        ],
      ),
    );
  }
}

class _IconTap extends StatelessWidget {
  const _IconTap({required this.icon, required this.onTap, required this.tooltip});

  final IconData icon;
  final VoidCallback? onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, size: 21),
      color: onTap == null ? AppColors.textMuted : AppColors.textSecondary,
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
    );
  }
}

/// Filmstrip + caption blocks + playhead + waveform, and drag-to-seek.
class StudioTimeline extends StatelessWidget {
  const StudioTimeline({
    required this.segments,
    required this.durationUs,
    required this.positionUs,
    required this.onSeek,
    required this.onBlockTap,
    required this.waveform,
    required this.strip,
    super.key,
  });

  final List<SubtitleSegment> segments;
  final int durationUs;
  final int positionUs;
  final ValueChanged<int> onSeek;
  final ValueChanged<SubtitleSegment> onBlockTap;
  final List<int> waveform;
  final Widget strip;

  @override
  Widget build(BuildContext context) {
    final double progress =
        durationUs <= 0 ? 0 : (positionUs / durationUs).clamp(0.0, 1.0).toDouble();
    return SizedBox(
      height: 128,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double width = constraints.maxWidth;
          void seekTo(double dx) =>
              onSeek((durationUs * (dx / width)).round().clamp(0, durationUs).toInt());

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (TapDownDetails details) => seekTo(details.localPosition.dx),
            onHorizontalDragUpdate: (DragUpdateDetails details) =>
                seekTo(details.localPosition.dx),
            child: Stack(
              children: <Widget>[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const SizedBox(height: 10),
                    // Film strip.
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: SizedBox(height: 62, child: strip),
                    ),
                    const SizedBox(height: 6),
                    // Timeline ruler.
                    SizedBox(
                      height: 12,
                      child: Row(
                        children: List<Widget>.generate(9, (int index) {
                          return Expanded(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                width: 1,
                                height: index % 3 == 0 ? 7 : 4,
                                color: AppColors.outline,
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    // Audio waveform.
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: ColoredBox(
                          color: const Color(0xFF0B1430),
                          child: CustomPaint(
                            painter: WaveformPainter(
                              values: waveform,
                              progress: progress,
                            ),
                            size: Size.infinite,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
                // Caption blocks sit on the film strip.
                Positioned(
                  top: 10,
                  left: 0,
                  right: 0,
                  height: 30,
                  child: _CaptionBlocks(
                    segments: segments,
                    durationUs: durationUs,
                    width: width,
                    onTap: onBlockTap,
                  ),
                ),
                // Playhead.
                Positioned(
                  top: 2,
                  bottom: 14,
                  left: (width * progress - 1).clamp(0.0, width - 2),
                  child: const _Playhead(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Playhead extends StatelessWidget {
  const _Playhead();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Container(
          width: 3,
          height: 10,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const Expanded(
          child: SizedBox(
            width: 1.6,
            child: ColoredBox(color: Colors.white),
          ),
        ),
      ],
    );
  }
}

class _CaptionBlocks extends StatelessWidget {
  const _CaptionBlocks({
    required this.segments,
    required this.durationUs,
    required this.width,
    required this.onTap,
  });

  final List<SubtitleSegment> segments;
  final int durationUs;
  final double width;
  final ValueChanged<SubtitleSegment> onTap;

  @override
  Widget build(BuildContext context) {
    if (durationUs <= 0 || segments.isEmpty) return const SizedBox.shrink();
    return Stack(
      children: segments.take(24).map((SubtitleSegment segment) {
        final double left = width * (segment.startUs / durationUs).clamp(0.0, 1.0);
        final double right = width * (segment.endUs / durationUs).clamp(0.0, 1.0);
        final double blockWidth = math.max(28.0, right - left);
        return Positioned(
          left: left.clamp(0.0, math.max(0.0, width - 28)),
          top: 0,
          child: GestureDetector(
            onTap: () => onTap(segment),
            child: Container(
              width: blockWidth,
              height: 30,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                gradient: AppColors.accentGradient,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Row(
                children: <Widget>[
                  const Text(
                    'T',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      segment.text.isEmpty ? 'زیرنویس' : segment.text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(growable: false),
    );
  }
}

/// Bars for the audio track: played part blue, the rest dim.
class WaveformPainter extends CustomPainter {
  const WaveformPainter({required this.values, required this.progress});

  final List<int> values;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final int count = values.isEmpty ? 64 : values.length;
    final double barWidth = size.width / count;
    final Paint paint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < count; i++) {
      final double normalised = values.isEmpty
          ? (0.25 + 0.6 * ((math.sin(i * 1.7) + 1) / 2))
          : (values[i] / 1000).clamp(0.03, 1.0).toDouble();
      final double height = math.max(2.0, normalised * size.height * 0.92);
      paint.color = (i / count) <= progress
          ? const Color(0xFF5B8CFF)
          : const Color(0xFF2A3B66);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(i * barWidth + barWidth * 0.2, (size.height - height) / 2,
              math.max(1.2, barWidth * 0.6), height),
          const Radius.circular(2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant WaveformPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.progress != progress;
}

/// The five tools from the reference: style, colour, animation, position, more.
enum StudioTool { style, color, animation, position, more }

class StudioToolRow extends StatelessWidget {
  const StudioToolRow({required this.tool, required this.onSelect, super.key});

  final StudioTool tool;
  final ValueChanged<StudioTool> onSelect;

  static const List<(StudioTool, IconData, String)> _tools = <(StudioTool, IconData, String)>[
    (StudioTool.style, Icons.text_fields_rounded, 'استایل'),
    (StudioTool.color, Icons.palette_outlined, 'رنگ'),
    (StudioTool.animation, Icons.auto_awesome_outlined, 'انیمیشن'),
    (StudioTool.position, Icons.crop_free_rounded, 'جایگاه'),
    (StudioTool.more, Icons.more_horiz_rounded, 'بیشتر'),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 76,
      child: Row(
        children: <Widget>[
          for (final (StudioTool id, IconData icon, String label) in _tools)
            Expanded(
              child: GestureDetector(
                onTap: () => onSelect(id),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: tool == id ? AppColors.surfaceHigher : AppColors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: tool == id ? AppColors.primary : AppColors.outline,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Icon(
                        icon,
                        size: 19,
                        color: tool == id ? AppColors.primarySoft : AppColors.textSecondary,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: tool == id ? FontWeight.w700 : FontWeight.w500,
                          color: tool == id ? AppColors.textPrimary : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// "Aa" tiles for the presets, drawn in each preset's own font and colours.
class StudioPresetRow extends StatelessWidget {
  const StudioPresetRow({
    required this.presets,
    required this.currentId,
    required this.onPick,
    super.key,
  });

  final List<CaptionPreset> presets;
  final String currentId;
  final ValueChanged<CaptionPreset> onPick;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 62,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: presets.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (BuildContext context, int index) {
          final CaptionPreset preset = presets[index];
          final bool selected = preset.id == currentId;
          return GestureDetector(
            onTap: () => onPick(preset),
            child: Container(
              width: 58,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.outline,
                  width: selected ? 1.6 : 1,
                ),
              ),
              child: Text(
                'Aa',
                style: TextStyle(
                  fontFamily: preset.fontFamily,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF000000 | preset.textColor),
                  shadows: <Shadow>[
                    Shadow(
                      color: Color(0xFF000000 | preset.accentColor),
                      offset: const Offset(1.4, 1.4),
                      blurRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Colour swatches: none, white, yellow, pink, blue, green, rainbow.
class StudioColorRow extends StatelessWidget {
  const StudioColorRow({
    required this.current,
    required this.onPick,
    this.rainbowSelected = false,
    super.key,
  });

  final int current;
  final ValueChanged<int> onPick;
  final bool rainbowSelected;

  static const List<int> _colors = <int>[
    0xFFFFFF,
    0xFFD400,
    0xFF5C8A,
    0x4B7BFF,
    0x3DDC97,
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: <Widget>[
          _Swatch(
            selected: current == 0 && !rainbowSelected,
            onTap: () => onPick(0),
            child: const Icon(Icons.block_rounded, size: 18, color: AppColors.textMuted),
          ),
          ..._colors.map((int color) => _Swatch(
                selected: !rainbowSelected && current == color,
                onTap: () => onPick(color),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0xFF000000 | color),
                    shape: BoxShape.circle,
                  ),
                ),
              )),
          _Swatch(
            selected: rainbowSelected,
            onTap: () => onPick(-1),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: AppColors.rainbow,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.selected, required this.onTap, required this.child});

  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.outline,
            width: selected ? 1.8 : 1,
          ),
        ),
        child: child,
      ),
    );
  }
}
