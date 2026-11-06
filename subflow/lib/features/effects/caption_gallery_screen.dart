import 'package:flutter/material.dart';

import '../../shared/theme/app_colors.dart';
import '../../shared/widgets/sf_button.dart';
import '../../shared/widgets/sf_scaffold.dart';
import 'caption_effect.dart';
import 'caption_fonts.dart';
import 'caption_labels.dart';
import 'caption_preset.dart';
import 'caption_renderer.dart';
import 'presets_library.dart';

/// Caption look picker.
///
/// Layout follows the familiar short-form-editor pattern: categories as a single
/// scrolling row, looks as a compact two-column grid, and one large, animated
/// audition inside the sheet. Every tile is painted by the *same*
/// `CaptionPainter` the editor overlays on the video, so what is auditioned here
/// is what gets burned in.
///
/// Two rendering rules are enforced by this screen:
///   * a tile never depends on an entrance animation to be legible - captions are
///     drawn at their held state, because a grid of looping fades used to look
///     like a grid of empty boxes;
///   * only the sheet animates, one preview at a time, so the list stays cheap.
class CaptionGalleryScreen extends StatefulWidget {
  const CaptionGalleryScreen({super.key, this.initialSelection, this.embedded = false});

  /// The style chosen when this screen was pushed as a picker (`null` when it is
  /// only being browsed).
  final String? initialSelection;

  /// True when the screen is a bottom-bar tab instead of a pushed picker: the
  /// sheet then offers "بستن" instead of returning a preset, because there is no
  /// caller waiting for one.
  final bool embedded;

  @override
  State<CaptionGalleryScreen> createState() => _CaptionGalleryScreenState();
}

class _CaptionGalleryScreenState extends State<CaptionGalleryScreen> {
  String _language = 'fa';
  String _category = PresetsLibrary.categories.first;

  String get _sample => _language == 'fa'
      ? 'این یک نمونه زیرنویس فارسی است'
      : 'THIS IS A SAMPLE CAPTION';

  @override
  Widget build(BuildContext context) {
    final List<CaptionPreset> presets = PresetsLibrary.forCategory(_category, _language);
    return SfScaffold(
      padded: false,
      appBar: AppBar(
        leadingWidth: 56,
        title: const Text('استایل زیرنویس'),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(left: 20, right: 4),
            child: _LanguageToggle(
              language: _language,
              onChanged: (String value) => setState(() => _language = value),
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(left: 20, right: 20, top: 2, bottom: 12),
            child: Text(
              '${presets.length} استایل برای ${_language == 'fa' ? 'زیرنویس فارسی' : 'English captions'}'
              ' • پیش‌نمایش با همان موتور استایل‌دهی ویدئو',
              style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted, height: 1.6),
            ),
          ),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: PresetsLibrary.categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (BuildContext context, int index) {
                final String category = PresetsLibrary.categories[index];
                return _CategoryChip(
                  label: category,
                  selected: category == _category,
                  onTap: () => setState(() => _category = category),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: presets.isEmpty
                ? const Center(
                    child: Text(
                      'برای این دسته استایلی ثبت نشده است.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.only(left: 20, right: 20, top: 2, bottom: 28),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.86,
                    ),
                    itemCount: presets.length,
                    itemBuilder: (BuildContext context, int index) {
                      final CaptionPreset preset = presets[index];
                      return _PresetTile(
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (BuildContext context) => _PresetSheet(
        preset: preset,
        sample: _sample,
        embedded: widget.embedded,
      ),
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
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            gradient: selected ? AppColors.accentGradient : null,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
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

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          gradient: selected ? AppColors.accentGradient : null,
          color: selected ? null : AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: selected ? Colors.transparent : AppColors.outline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (selected) ...<Widget>[
              const Icon(Icons.check_rounded, size: 13, color: Colors.white),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One look in the grid: a real caption painted over a still frame, the look's
/// name, and two facts that actually differ between presets.
class _PresetTile extends StatelessWidget {
  const _PresetTile({
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.outline,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: <Widget>[
                      Positioned.fill(
                        child: CaptionFrame(
                          preset: preset,
                          text: sample,
                          minFontSize: 12,
                          radius: 11,
                          compact: true,
                        ),
                      ),
                      if (selected)
                        Positioned(
                          top: 6,
                          left: 6,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check_rounded, size: 11, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Text(
                    preset.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Text(
                    '${font.label} • ${captionAnimationLabel(preset.effects.enter)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10, color: AppColors.textMuted, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A caption rendered over a representative still frame.
///
/// The frame is a bundled photograph (`assets/images/caption_frame.jpg`), cropped
/// the way a 9:16 clip would be, because a caption judged against a flat card is
/// not a caption judged against a video - contrast, drop shadow and stroke all
/// read differently.
class CaptionFrame extends StatelessWidget {
  const CaptionFrame({
    required this.preset,
    required this.text,
    super.key,
    this.minFontSize = 12,
    this.radius = 14,
    this.compact = false,
    this.animated = false,
    this.phase = 0,
  });

  final CaptionPreset preset;
  final String text;
  final double minFontSize;
  final double radius;
  final bool compact;
  final bool animated;
  final double phase;

  @override
  Widget build(BuildContext context) {
    final Widget caption = animated
        ? AnimatedCaptionPreview(
            preset: preset,
            text: text,
            minFontSize: minFontSize,
            phase: phase,
          )
        : CaptionSurface(
            preset: preset,
            text: text,
            enter: 1,
            exit: 0,
            activeWord: preset.effects.wordEffect == CaptionWordEffect.none ? -1 : 1,
            wordFills: const <double>[1, 1, 1, 1, 1, 1],
            minFontSize: minFontSize,
          );

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Image.asset(
            'assets/images/caption_frame.jpg',
            fit: BoxFit.cover,
            alignment: compact ? Alignment(0.2, 0.1) : Alignment.center,
            filterQuality: FilterQuality.medium,
          ),
          // Keeps white captions readable the way a graded clip does, and hides
          // the photograph's own busy mid-tones behind the text band.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  Colors.black.withOpacity(0.18),
                  Colors.black.withOpacity(0.05),
                  Colors.black.withOpacity(0.42),
                ],
                stops: const <double>[0, 0.45, 1],
              ),
            ),
          ),
          caption,
        ],
      ),
    );
  }
}

class _PresetSheet extends StatelessWidget {
  const _PresetSheet({required this.preset, required this.sample, required this.embedded});

  final CaptionPreset preset;
  final String sample;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final CaptionFont font = CaptionFonts.byFamily(preset.fontFamily);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(left: 20, right: 20, top: 14, bottom: 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    preset.name,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: AppColors.outline),
                  ),
                  child: Text(
                    preset.category,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${font.label} • وزن ${preset.fontWeight} • ${font.license}',
              style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
            ),
            const SizedBox(height: 14),
            AspectRatio(
              aspectRatio: 16 / 10,
              child: CaptionFrame(
                preset: preset,
                text: sample,
                minFontSize: 16,
                radius: 16,
                animated: true,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _Meta(label: 'ورود: ${captionAnimationLabel(preset.effects.enter)}'),
                _Meta(label: 'خروج: ${captionExitLabel(preset.effects.exit)}'),
                _Meta(label: 'کلمه: ${captionWordEffectLabel(preset.effects.wordEffect)}'),
                _Meta(label: '${preset.effects.durationMs} ms'),
                if (preset.strokeWidth > 0) _Meta(label: 'دورخط ${preset.strokeWidth.toStringAsFixed(0)}'),
                if (preset.shadowBlur > 0) _Meta(label: 'سایه ${preset.shadowBlur.toStringAsFixed(0)}'),
                if (preset.glowRadius > 0) _Meta(label: 'درخشش ${preset.glowRadius.toStringAsFixed(0)}'),
                if (preset.hasGradient) const _Meta(label: 'گرادیان متن'),
                if (preset.boxBackground) const _Meta(label: 'کادر پس‌زمینه'),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: SfPrimaryButton(
                label: embedded ? 'بستن' : 'انتخاب این استایل',
                icon: embedded ? Icons.expand_more_rounded : Icons.check_rounded,
                onPressed: () => Navigator.of(context).pop(embedded ? null : preset),
              ),
            ),
          ],
        ),
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
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppColors.outline),
      ),
      child: Text(label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
    );
  }
}
