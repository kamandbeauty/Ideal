import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:subflow/features/effects/caption_fonts.dart';
import 'package:subflow/features/effects/caption_preset.dart';
import 'package:subflow/features/effects/presets_library.dart';
import 'package:subflow/features/subtitles/emoji_suggester.dart';
import 'package:subflow/features/subtitles/subtitle_document.dart';
import 'package:subflow/features/subtitles/subtitle_editor_model.dart';
import 'package:subflow/models/enums.dart';
import 'package:subflow/models/subtitle.dart';

/// Per-caption customisation is the feature that can rot silently: the database
/// column, the JSON round-trip, the undo step and the emoji pass all have to
/// agree, and none of them shows up in a screenshot when they break.
void main() {
  SubtitleSegment segment(String id, String text, {int startUs = 0, int endUs = 2000000}) =>
      SubtitleSegment(
        id: id,
        trackId: 'track',
        ordinal: 0,
        startUs: startUs,
        endUs: endUs,
        text: text,
        source: SubtitleSource.manual,
        createdAtMs: 0,
        updatedAtMs: 0,
      );

  SubtitleDocument threeLines() => SubtitleDocument(
        trackId: 'track',
        segments: <SubtitleSegment>[
          segment('a', 'سلام دنیا'),
          segment('b', 'این خط عشق است', startUs: 2100000, endUs: 4000000),
          segment('c', 'خط سوم', startUs: 4100000, endUs: 6000000),
        ],
      );

  group('preset serialisation', () {
    test('toMap/fromMap round-trips every field', () {
      final CaptionPreset original = PresetsLibrary.byId('mirza-gold-fa');
      final CaptionPreset restored =
          CaptionPreset.fromMap(jsonDecode(jsonEncode(original.toMap())) as Map<String, Object?>);

      expect(restored.fontFamily, original.fontFamily);
      expect(restored.fontWeight, original.fontWeight);
      expect(restored.fontScale, original.fontScale);
      expect(restored.textColor, original.textColor);
      expect(restored.accentColor, original.accentColor);
      expect(restored.gradientEnd, original.gradientEnd);
      expect(restored.positionY, original.positionY);
      expect(restored.widthFraction, original.widthFraction);
      expect(restored.effects.enter, original.effects.enter);
      expect(restored.effects.wordEffect, original.effects.wordEffect);
      expect(restored.effects.durationMs, original.effects.durationMs);
      expect(restored.effects.easing, original.effects.easing);
      expect(restored.toMap(), original.toMap());
    });

    test('a damaged map falls back instead of throwing', () {
      final CaptionPreset preset = CaptionPreset.fromMap(<String, Object?>{
        'fontFamily': 'Vazirmatn',
        'fontScale': 'not-a-number',
        'effects': <String, Object?>{'enter': 'made-up'},
      });
      expect(preset.fontScale, greaterThan(0));
      expect(preset.effects.enter.name, isNotEmpty);
    });
  });

  group('per-caption style', () {
    test('a single caption can carry its own style', () {
      final SubtitleDocument before = threeLines();
      final String style = jsonEncode(PresetsLibrary.byId('katibeh-fa').toMap());
      final SubtitleDocument after = before.withPreset('b', style);

      expect(after.byId('b')!.hasOwnStyle, isTrue);
      expect(after.byId('a')!.hasOwnStyle, isFalse);
      expect(after.byId('c')!.hasOwnStyle, isFalse);
      expect(CaptionPreset.fromMap(
        jsonDecode(after.byId('b')!.presetJson!) as Map<String, Object?>,
      ).fontFamily, 'Katibeh');
    });

    test('clearing a caption style returns it to the project style', () {
      final SubtitleDocument styled =
          threeLines().withPreset('b', jsonEncode(PresetsLibrary.byId('rakkas-fa').toMap()));
      final SubtitleDocument cleared = styled.withPreset('b', null);
      expect(cleared.byId('b')!.hasOwnStyle, isFalse);
    });

    test('"apply to the whole film" copies one caption style everywhere', () {
      final String style = jsonEncode(PresetsLibrary.byId('gulzar-fa').toMap());
      final SubtitleDocument doc = threeLines().withPreset('b', style).withPresetFrom('b');

      for (final SubtitleSegment s in doc.segments) {
        expect(s.hasOwnStyle, isTrue, reason: 'segment ${s.id}');
        expect(s.presetJson, style);
      }
    });

    test('copies survive the editor history and one undo reverts them all', () {
      final SubtitleEditorModel model = SubtitleEditorModel(document: threeLines());
      final String style = jsonEncode(PresetsLibrary.byId('katibeh-fa').toMap());
      expect(model.setSegmentPreset('a', style), isTrue);
      expect(model.applySegmentPresetToAll('a'), isTrue);
      expect(model.document.segments.every((SubtitleSegment s) => s.presetJson == style), isTrue);
      expect(model.undo(), isTrue);
      expect(model.document.byId('c')!.presetJson, isNull);
      expect(model.undo(), isTrue);
      expect(model.document.byId('a')!.presetJson, isNull);
    });

    test('the segment map carries the style to the database row', () {
      final String style = jsonEncode(PresetsLibrary.byId('naskh-fa').toMap());
      final SubtitleSegment segment =
          threeLines().withPreset('a', style).byId('a')!;
      expect(segment.toMap()['preset_json'], style);
      expect(SubtitleSegment.fromMap(segment.toMap()).presetJson, style);
    });
  });

  group('font pack', () {
    test('ships at least 24 families, most of them Persian-capable', () {
      expect(CaptionFonts.all.length, greaterThanOrEqualTo(24));
      expect(CaptionFonts.persianCapable().length, greaterThanOrEqualTo(20));
    });

    test('every catalogue font has a licence and unique family name', () {
      final Set<String> families = <String>{};
      for (final CaptionFont font in CaptionFonts.all) {
        expect(font.license, isNotEmpty, reason: font.family);
        expect(families.add(font.family), isTrue, reason: 'duplicate ${font.family}');
        expect(font.label, isNotEmpty);
        expect(font.weights, isNotEmpty);
      }
    });

    test('the catalogue grew with the classics pack', () {
      for (final String family in <String>[
        'Amiri',
        'ScheherazadeNew',
        'IBMPlexSansArabic',
        'Gulzar',
        'Katibeh',
      ]) {
        expect(
          CaptionFonts.all.any((CaptionFont font) => font.family == family),
          isTrue,
          reason: family,
        );
        expect(CaptionFonts.byFamily(family).supportsPersian, isTrue, reason: family);
      }
    });
  });

  group('look catalogue', () {
    test('every new look exists in both languages with a Persian-safe font', () {
      expect(PresetsLibrary.all.length, greaterThanOrEqualTo(68));
      for (final CaptionPreset preset in PresetsLibrary.forLanguage('fa')) {
        expect(CaptionFonts.byFamily(preset.fontFamily).supportsPersian, isTrue,
            reason: preset.id);
      }
      final Set<String> ids = PresetsLibrary.all.map((CaptionPreset p) => p.id).toSet();
      expect(ids.length, PresetsLibrary.all.length);
    });
  });

  group('auto emoji', () {
    test('appends the matching emoji once', () {
      expect(EmojiSuggester.decorate('امروز خیلی خنده‌دار بود'), endsWith('😂'));
      expect(EmojiSuggester.decorate('دوستت دارم'), endsWith('❤️'));
      final String once = EmojiSuggester.decorate('این غذا خوشمزه است');
      expect(once, endsWith('😋'));
      expect(EmojiSuggester.decorate(once), once);
    });

    test('leaves plain sentences and empty lines alone', () {
      expect(EmojiSuggester.decorate(''), '');
      expect(EmojiSuggester.decorate('یک جملهٔ بی‌کلیدواژه'), 'یک جملهٔ بی‌کلیدواژه');
    });

    test('one undo step reverts the whole emoji pass', () {
      final SubtitleEditorModel model = SubtitleEditorModel(
        document: SubtitleDocument(
          trackId: 'track',
          segments: <SubtitleSegment>[
            segment('a', 'امروز خیلی خنده‌دار بود'),
            segment('b', 'سلام به همه', startUs: 2100000, endUs: 4000000),
            segment('c', 'یک جملهٔ ساده', startUs: 4100000, endUs: 6000000),
          ],
        ),
      );
      final int changed = model.addEmojis(EmojiSuggester.decorate);
      expect(changed, 2);
      expect(model.document.byId('a')!.text, endsWith('😂'));
      expect(model.undo(), isTrue);
      expect(model.document.byId('a')!.text, 'امروز خیلی خنده‌دار بود');
    });
  });
}
