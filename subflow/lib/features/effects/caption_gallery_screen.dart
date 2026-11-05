import 'package:flutter/material.dart';

import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/sf_button.dart';
import '../../shared/widgets/sf_card.dart';
import '../../shared/widgets/sf_scaffold.dart';
import 'caption_fonts.dart';
import 'caption_labels.dart';
import 'caption_preset.dart';
import 'caption_renderer.dart';
import 'presets_library.dart';

/// Caption look gallery. Every tile is painted by the *same* `CaptionPainter`
/// the editor overlays on the video and the same `CaptionPreset` data the native
/// renderer will consume, so what a user auditions here is what gets burned in.
class CaptionGalleryScreen extends StatefulWidget {
  const CaptionGalleryScreen({super.key, this.initialSelection});

  final String? initialSelection;

  @override
  State<CaptionGalleryScreen> createState() => _CaptionGalleryScreenState();
}

class _CaptionGalleryScreenState extends State<CaptionGalleryScreen> {
  String _language = 'fa';
  String _category = 'همه';

  String get _sample => _language == 'fa'
      ? 'این یک نمونه زیرنویس فارسی است'
      : 'THIS IS A SAMPLE CAPTION';

  @override
  Widget build(BuildContext context) {
    final List<CaptionPreset> presets = PresetsLibrary.forCategory(_category, _language);
    return SfScaffold(
      appBar: AppBar(
        title: const Text('استایل زیرنویس'),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: _LanguageToggle(
              language: _language,
              onChanged: (String value) => setState(() => _language = value),
            ),
          ),
        ],
      ),
      child: Column(
        children: <Widget>[
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: PresetsLibrary.categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (BuildContext context, int index) {
                final String category = PresetsLibrary.categories[index];
                final bool selected = category == _category;
                return ChoiceChip(
                  selected: selected,
                  label: Text(category),
                  onSelected: (_) => setState(() => _category = category),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : AppColors.textSecondary,
                  ),
                  selectedColor: AppColors.primary,
                  backgroundColor: AppColors.surfaceHigh,
                  side: const BorderSide(color: AppColors.outline),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.only(bottom: 28),
              itemCount: presets.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (BuildContext context, int index) {
                final CaptionPreset preset = presets[index];
                return _PresetCard(
                  preset: preset,
                  sample: _sample,
                  selected: preset.id == widget.initialSelection,
                  onTap: () => _openSheet(preset),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openSheet(CaptionPreset preset) async {
    final CaptionPreset? chosen = await showModalBottomSheet<CaptionPreset>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext context) => _PresetSheet(preset: preset, sample: _sample),
    );
    if (!mounted || chosen == null) return;
    Navigator.of(context).pop(chosen);
  }
}

class _LanguageToggle extends StatelessWidget {
  const _LanguageToggle({required this.language, required this.onChanged});

  final String language;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget item(String code, String label) {
      final bool selected = code == language;
      return GestureDetector(
        onTap: () => onChanged(code),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[item('fa', 'فارسی'), item('en', 'English')],
      ),
    );
  }
}

class _PresetCard extends StatelessWidget {
  const _PresetCard({
    required this.preset,
    required this.sample,
    required this.selected,
    required this.onTap,
  });

  final CaptionPreset preset;
  final String sample;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final CaptionFont font = CaptionFonts.byFamily(preset.fontFamily);
    return SfCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _PreviewStage(preset: preset, sample: sample, height: 132),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      preset.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${preset.category} • ${font.label} • ${captionAnimationLabel(preset.effects.enter)}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20)
              else
                const Icon(Icons.chevron_left_rounded, color: AppColors.textMuted, size: 20),
            ],
          ),
        ],
      ),
    );
  }
}

/// Stand-in "video frame" so a caption can be judged against a dark, contrasty
/// image instead of a flat card. Purely decorative - it is not the preview
/// engine, the caption on top of it is.
class _PreviewStage extends StatelessWidget {
  const _PreviewStage({required this.preset, required this.sample, required this.height});

  final CaptionPreset preset;
  final String sample;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[Color(0xFF1B2440), Color(0xFF0A0E1A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            Positioned(
              top: -20,
              right: -10,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: <Color>[
                      AppColors.secondary.withOpacity(0.35),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            AnimatedCaptionPreview(preset: preset, text: sample),
          ],
        ),
      ),
    );
  }
}

class _PresetSheet extends StatelessWidget {
  const _PresetSheet({required this.preset, required this.sample});

  final CaptionPreset preset;
  final String sample;

  @override
  Widget build(BuildContext context) {
    final CaptionFont font = CaptionFonts.byFamily(preset.fontFamily);
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 18,
        bottom: 20 + MediaQuery.of(context).viewPadding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(preset.name, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            '${preset.category} • ${font.label} (${preset.fontWeight}) • ${font.license}',
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 14),
          _PreviewStage(preset: preset, sample: sample, height: 180),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _Meta(label: 'ورود: ${captionAnimationLabel(preset.effects.enter)}'),
              _Meta(label: 'خروج: ${captionExitLabel(preset.effects.exit)}'),
              _Meta(label: 'کلمه: ${captionWordEffectLabel(preset.effects.wordEffect)}'),
              _Meta(label: '${preset.effects.durationMs} ms • ${captionEasingLabel(preset.effects.easing)}'),
              if (preset.strokeWidth > 0) _Meta(label: 'دورخط ${preset.strokeWidth.toStringAsFixed(0)}'),
              if (preset.shadowBlur > 0) _Meta(label: 'سایه ${preset.shadowBlur.toStringAsFixed(0)}'),
              if (preset.glowRadius > 0) _Meta(label: 'درخشش ${preset.glowRadius.toStringAsFixed(0)}'),
              if (preset.hasGradient) const _Meta(label: 'گرادیان متن'),
              if (preset.boxBackground) const _Meta(label: 'کادر پس‌زمینه'),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: SfPrimaryButton(
              label: 'انتخاب این استایل',
              icon: Icons.check_rounded,
              onPressed: () => Navigator.of(context).pop(preset),
            ),
          ),
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.outline),
      ),
      child: Text(label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
    );
  }
}
