import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:subflow/features/effects/caption_effect.dart';
import 'package:subflow/features/effects/caption_fonts.dart';
import 'package:subflow/features/effects/caption_labels.dart';
import 'package:subflow/features/effects/caption_preset.dart';
import 'package:subflow/features/effects/caption_renderer.dart';
import 'package:subflow/features/effects/presets_library.dart';

/// The caption engine is the piece most likely to regress silently: a preset can
/// still serialise while the renderer throws on a specific enum value. These
/// tests therefore *paint* every animation, exit and word effect, and check the
/// data invariants the gallery and export path rely on.
void main() {
  group('preset catalogue', () {
    test('ships at least 30 looks, all with unique ids', () {
      expect(PresetsLibrary.all.length, greaterThanOrEqualTo(30));
      final Set<String> ids = PresetsLibrary.all.map((CaptionPreset p) => p.id).toSet();
      expect(ids.length, PresetsLibrary.all.length);
    });

    test('every look exists in Persian and English', () {
      final List<CaptionPreset> fa = PresetsLibrary.forLanguage('fa');
      final List<CaptionPreset> en = PresetsLibrary.forLanguage('en');
      expect(fa.length, en.length);
      final Set<String> faLooks = fa.map((CaptionPreset p) => p.id.replaceAll('-fa', '')).toSet();
      final Set<String> enLooks = en.map((CaptionPreset p) => p.id.replaceAll('-en', '')).toSet();
      expect(faLooks, enLooks);
    });

    test('Persian presets always use a Persian-capable font', () {
      for (final CaptionPreset preset in PresetsLibrary.forLanguage('fa')) {
        expect(
          CaptionFonts.byFamily(preset.fontFamily).supportsPersian,
          isTrue,
          reason: '${preset.id} uses ${preset.fontFamily}',
        );
        expect(preset.direction, TextDirection.rtl);
      }
    });

    test('every category in the picker resolves to at least one preset', () {
      for (final String category in PresetsLibrary.categories) {
        expect(
          PresetsLibrary.forCategory(category, 'fa'),
          isNotEmpty,
          reason: 'category $category is empty',
        );
      }
    });

    test('byId falls back to a real preset instead of null', () {
      expect(PresetsLibrary.byId(null).language, 'fa');
      expect(PresetsLibrary.byId('does-not-exist').id, isNotEmpty);
    });
  });

  group('effect model', () {
    test('CaptionEffects round-trips through its map for every enum value', () {
      for (final CaptionAnimation enter in CaptionAnimation.values) {
        for (final CaptionExit exit in <CaptionExit>[
          CaptionExit.none,
          CaptionExit.popOut,
          CaptionExit.blurOut,
        ]) {
          for (final CaptionWordEffect word in CaptionWordEffect.values) {
            final CaptionEffects effects = CaptionEffects(
              enter: enter,
              exit: exit,
              wordEffect: word,
              durationMs: 340,
              delayMs: 40,
              easing: CaptionEasing.easeOutBack,
              intensity: 1.4,
              pulse: true,
            );
            final CaptionEffects back = CaptionEffects.fromMap(effects.toMap());
            expect(back.enter, effects.enter);
            expect(back.exit, effects.exit);
            expect(back.wordEffect, effects.wordEffect);
            expect(back.durationMs, 340);
            expect(back.delayMs, 40);
            expect(back.easing, CaptionEasing.easeOutBack);
            expect(back.intensity, 1.4);
            expect(back.pulse, isTrue);
          }
        }
      }
    });

    test('fromMap survives junk without throwing', () {
      final CaptionEffects effects = CaptionEffects.fromMap(<String, Object?>{
        'enter': 'not-a-real-animation',
        'exit': 42,
        'word': null,
        'durationMs': 'fast',
      });
      expect(effects.enter, CaptionAnimation.fade);
      expect(effects.exit, CaptionExit.fadeOut);
      expect(effects.wordEffect, CaptionWordEffect.none);
      expect(effects.durationMs, 260);
    });

    test('CaptionPreset.toMap carries every field the native renderer needs', () {
      final Map<String, Object?> map = PresetsLibrary.byId('viral-fa').toMap();
      for (final String key in <String>[
        'id',
        'language',
        'fontFamily',
        'fontWeight',
        'fontScale',
        'textColor',
        'accentColor',
        'strokeWidth',
        'shadowBlur',
        'glowRadius',
        'positionY',
        'widthFraction',
        'effects',
      ]) {
        expect(map.containsKey(key), isTrue, reason: 'missing $key');
      }
      expect((map['effects']! as Map<String, Object?>)['enter'], isNotNull);
    });

    test('every enum value has a Persian label', () {
      for (final CaptionAnimation value in CaptionAnimation.values) {
        expect(captionAnimationLabel(value), isNotEmpty);
      }
      for (final CaptionExit value in CaptionExit.values) {
        expect(captionExitLabel(value), isNotEmpty);
      }
      for (final CaptionWordEffect value in CaptionWordEffect.values) {
        expect(captionWordEffectLabel(value), isNotEmpty);
      }
      for (final CaptionEasing value in CaptionEasing.values) {
        expect(captionEasingLabel(value), isNotEmpty);
      }
    });
  });

  group('renderer paints every effect', () {
    Future<void> paintPreset(
      WidgetTester tester, {
      required CaptionPreset preset,
      required String text,
      double enter = 1,
      double exit = 0,
      int activeWord = -1,
    }) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: 360,
              height: 240,
              child: CaptionSurface(
                preset: preset,
                text: text,
                enter: enter,
                exit: exit,
                activeWord: activeWord,
                wordFills: <double>[0.2, 0.6, 1, 1],
                pulsePhase: 0.3,
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    }

    final CaptionPreset base = PresetsLibrary.byId('viral-fa');

    testWidgets('entrance animations paint at 0%, 50% and 100%', (WidgetTester tester) async {
      for (final CaptionAnimation enter in CaptionAnimation.values) {
        final CaptionPreset preset = base.copyWith(
          effects: CaptionEffects(enter: enter, exit: CaptionExit.none),
        );
        for (final double progress in <double>[0, 0.5, 1]) {
          await paintPreset(
            tester,
            preset: preset,
            text: 'این یک متن آزمایشی فارسی است',
            enter: progress,
            activeWord: 2,
          );
        }
      }
    });

    testWidgets('exit animations paint at 0%, 50% and 100%', (WidgetTester tester) async {
      for (final CaptionExit exit in CaptionExit.values) {
        final CaptionPreset preset = base.copyWith(
          effects: CaptionEffects(enter: CaptionAnimation.fade, exit: exit),
        );
        for (final double progress in <double>[0, 0.5, 1]) {
          await paintPreset(
            tester,
            preset: preset,
            text: 'متن خروج آزمایشی',
            exit: progress,
            activeWord: 1,
          );
        }
      }
    });

    testWidgets('word effects paint with and without an active word', (WidgetTester tester) async {
      for (final CaptionWordEffect effect in CaptionWordEffect.values) {
        final CaptionPreset preset = base.copyWith(
          effects: CaptionEffects(enter: CaptionAnimation.fade, wordEffect: effect),
        );
        await paintPreset(tester, preset: preset, text: 'کلمه به کلمه تست می‌شود', activeWord: 2);
        await paintPreset(tester, preset: preset, text: 'بدون کلمه فعال');
      }
    });

    testWidgets('gradient, stroke, glow and box presets paint', (WidgetTester tester) async {
      for (final CaptionPreset preset in PresetsLibrary.all) {
        await paintPreset(tester, preset: preset, text: 'نمونه', activeWord: 0);
      }
    });

    testWidgets('empty and whitespace text is a no-op, not a crash', (WidgetTester tester) async {
      await paintPreset(tester, preset: base, text: '');
      await paintPreset(tester, preset: base, text: '   ');
    });

    testWidgets('animated audition runs for a full cycle without exceptions',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              height: 200,
              child: AnimatedCaptionPreview(preset: base, text: 'پیش‌نمایش زنده', cycleMs: 600),
            ),
          ),
        ),
      );
      for (int i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 60));
        expect(tester.takeException(), isNull);
      }
    });
  });
}
