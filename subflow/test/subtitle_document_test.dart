import 'package:flutter_test/flutter_test.dart';
import 'package:subflow/core/time_us.dart';
import 'package:subflow/features/effects/preset_style_mapper.dart';
import 'package:subflow/features/effects/presets_library.dart';
import 'package:subflow/features/subtitles/subtitle_document.dart';
import 'package:subflow/features/subtitles/subtitle_editor_model.dart';
import 'package:subflow/models/enums.dart';
import 'package:subflow/models/subtitle.dart';

/// The Subtitle Studio's editing rules are the one place where a bug silently
/// corrupts user work (overlapping captions, lost text, unrecoverable edits), so
/// they are tested exhaustively here rather than trusted.
void main() {
  SubtitleSegment seg(String id, int startMs, int endMs, String text, {List<SubtitleWord>? words}) {
    return SubtitleSegment(
      id: id,
      trackId: 'track-1',
      ordinal: 0,
      startUs: TimeUs.fromMilliseconds(startMs),
      endUs: TimeUs.fromMilliseconds(endMs),
      text: text,
      source: SubtitleSource.manual,
      createdAtMs: 0,
      updatedAtMs: 0,
      words: words ?? const <SubtitleWord>[],
    );
  }

  SubtitleDocument doc(List<SubtitleSegment> segments) =>
      SubtitleDocument(trackId: 'track-1', segments: segments);

  group('normalisation', () {
    test('sorts by start time and re-numbers ordinals', () {
      final SubtitleDocument document = doc(<SubtitleSegment>[
        seg('b', 4000, 5000, 'دوم'),
        seg('a', 1000, 2000, 'اول'),
      ]);
      expect(document.segments.first.id, 'a');
      expect(document.segments.last.id, 'b');
      expect(document.segments.first.ordinal, 0);
      expect(document.segments.last.ordinal, 1);
    });

    test('pushes overlapping captions apart instead of merging them', () {
      final SubtitleDocument document = doc(<SubtitleSegment>[
        seg('a', 1000, 3000, 'اول'),
        seg('b', 2000, 4000, 'دوم'),
      ]);
      expect(document.segments.length, 2);
      expect(document.segments[1].startUs, greaterThanOrEqualTo(document.segments[0].endUs));
      expect(document.segments[1].endUs, greaterThan(document.segments[1].startUs));
    });

    test('enforces the minimum readable duration and non-negative start', () {
      final SubtitleDocument document = doc(<SubtitleSegment>[
        seg('a', -500, 10, 'کوتاه'),
      ]);
      expect(document.segments.single.startUs, 0);
      expect(document.segments.single.endUs, SubtitleDocument.minSegmentUs);
    });
  });

  group('lookups', () {
    final SubtitleDocument document = doc(<SubtitleSegment>[
      seg('a', 0, 1000, 'یک دو'),
      seg('b', 2000, 4000, 'سه چهار'),
    ]);

    test('indexAt uses half-open ranges', () {
      expect(document.indexAt(0), 0);
      expect(document.indexAt(TimeUs.fromMilliseconds(999)), 0);
      expect(document.indexAt(TimeUs.fromMilliseconds(1000)), isNull);
      expect(document.indexAt(TimeUs.fromMilliseconds(2500)), 1);
      expect(document.indexAt(TimeUs.fromMilliseconds(4000)), 1,
          reason: 'playhead parked at the very end');
      expect(document.indexAt(TimeUs.fromMilliseconds(90000)), isNull);
    });

    test('wordIndexAt never returns null for a segment with words', () {
      // An empty starting text forces `withText` to build the word list; setting
      // the same text again would correctly be a no-op.
      final SubtitleDocument withWords = doc(<SubtitleSegment>[seg('a', 0, 1000, '')])
          .withText('a', 'یک دو');
      expect(withWords.segments.first.words.length, 2);
      expect(withWords.wordIndexAt('a', 10), 0);
      expect(withWords.wordIndexAt('a', TimeUs.fromMilliseconds(900)), 1);
      expect(withWords.wordIndexAt('missing', 10), isNull);
    });
  });

  group('retiming', () {
    test('clamps the edited caption between its neighbours', () {
      final SubtitleDocument document = doc(<SubtitleSegment>[
        seg('a', 0, 1000, 'اول'),
        seg('b', 1000, 2000, 'دوم'),
        seg('c', 3000, 4000, 'سوم'),
      ]);
      final SubtitleDocument later = document.withTiming('b', startUs: TimeUs.fromMilliseconds(2500));
      final SubtitleSegment b = later.byId('b')!;
      expect(b.startUs, greaterThanOrEqualTo(TimeUs.fromMilliseconds(1000)));
      expect(b.endUs, lessThanOrEqualTo(TimeUs.fromMilliseconds(3000)));
      expect(b.endUs - b.startUs, greaterThanOrEqualTo(SubtitleDocument.minSegmentUs));
    });

    test('a shorter end never produces an invalid segment', () {
      final SubtitleDocument document = doc(<SubtitleSegment>[seg('a', 0, 2000, 'متن')]);
      final SubtitleDocument shorter = document.withTiming('a', endUs: 10);
      final SubtitleSegment a = shorter.byId('a')!;
      expect(a.endUs - a.startUs, greaterThanOrEqualTo(SubtitleDocument.minSegmentUs));
    });
  });

  group('text edits', () {
    test('redistributes word timings proportional to word length', () {
      final SubtitleDocument document = doc(<SubtitleSegment>[seg('a', 0, 1000, '')]);
      final SubtitleDocument edited = document.withText('a', 'کوتاه طولانی‌تر');
      final List<SubtitleWord> words = edited.segments.single.words;
      expect(words.length, 2);
      expect(words.first.endUs, lessThan(words.last.endUs));
      expect(words.last.endUs, TimeUs.fromMilliseconds(1000));
      expect(words.first.startUs, 0);
      for (int i = 1; i < words.length; i++) {
        expect(words[i].startUs, greaterThanOrEqualTo(words[i - 1].startUs));
        expect(words[i].endUs, greaterThanOrEqualTo(words[i].startUs));
      }
    });

    test('keeps ZWNJ and Persian punctuation inside word boundaries', () {
      final SubtitleDocument document = doc(<SubtitleSegment>[seg('a', 0, 1000, '')]);
      const String text = 'می‌روم، «خانه» را دیدم؟';
      final SubtitleDocument edited = document.withText('a', text);
      final String rebuilt =
          edited.segments.single.words.map((SubtitleWord w) => w.text).join(' ');
      expect(rebuilt, text);
      expect(edited.segments.single.text, text);
      expect(edited.segments.single.reviewState, ReviewState.edited);
    });

    test('an unchanged text is a no-op', () {
      final SubtitleDocument document = doc(<SubtitleSegment>[seg('a', 0, 1000, 'متن')]);
      expect(identical(document.withText('a', 'متن'), document), isTrue);
    });
  });

  group('split / merge / insert / remove', () {
    test('split divides text and produces two valid, ordered captions', () {
      final SubtitleDocument document =
          doc(<SubtitleSegment>[seg('a', 0, 2000, 'اول دوم سوم چهارم')]).withText('a', 'اول دوم سوم چهارم');
      final SubtitleDocument split = document.splitAt('a', TimeUs.fromMilliseconds(1000));
      expect(split.segments.length, 2);
      final SubtitleSegment left = split.segments[0];
      final SubtitleSegment right = split.segments[1];
      expect(left.endUs, right.startUs);
      expect(right.endUs, document.segments.single.endUs);
      expect('${left.text} ${right.text}', 'اول دوم سوم چهارم');
      expect(left.words.last.endUs, left.endUs);
      expect(right.words.first.startUs, right.startUs);
    });

    test('split refuses to create a caption shorter than the minimum', () {
      final SubtitleDocument document = doc(<SubtitleSegment>[seg('a', 0, 1000, 'یک دو')]);
      expect(document.splitAt('a', 50000).length, 1);
      expect(document.splitAt('a', 990000).length, 1);
    });

    test('merge joins text and spans both ranges', () {
      final SubtitleDocument document = doc(<SubtitleSegment>[
        seg('a', 0, 1000, 'اول'),
        seg('b', 1200, 2000, 'دوم'),
      ]);
      final SubtitleDocument merged = document.mergeWithNext('a');
      expect(merged.segments.length, 1);
      expect(merged.segments.single.text, 'اول دوم');
      expect(merged.segments.single.startUs, 0);
      expect(merged.segments.single.endUs, TimeUs.fromMilliseconds(2000));
      expect(merged.segments.single.words.length, 2);
      expect(document.mergeWithNext('b').length, 2, reason: 'last caption has no next');
    });

    test('insert keeps the timeline sorted and readable', () {
      final SubtitleDocument document = doc(<SubtitleSegment>[seg('a', 0, 3000, 'اول')]);
      final SubtitleDocument grown = document.insertAt(TimeUs.fromMilliseconds(1000));
      expect(grown.length, 2);
      for (final SubtitleSegment segment in grown.segments) {
        expect(segment.endUs - segment.startUs, greaterThanOrEqualTo(SubtitleDocument.minSegmentUs));
      }
      expect(grown.segments.first.endUs, lessThanOrEqualTo(grown.segments.last.endUs));
    });

    test('remove drops exactly one caption', () {
      final SubtitleDocument document = doc(<SubtitleSegment>[
        seg('a', 0, 1000, 'اول'),
        seg('b', 1200, 2000, 'دوم'),
      ]);
      expect(document.remove('a').segments.single.id, 'b');
      expect(document.remove('nope').length, 2);
    });

    test('shiftAll moves captions and word timings, never below zero', () {
      final SubtitleDocument document =
          doc(<SubtitleSegment>[seg('a', 1000, 2000, '')]).withText('a', 'سلام دنیا');
      final SubtitleDocument shifted = document.shiftAll(-500000);
      expect(shifted.segments.single.startUs, TimeUs.fromMilliseconds(500));
      expect(shifted.segments.single.words.first.startUs, greaterThanOrEqualTo(0));
      final SubtitleDocument farBack = document.shiftAll(-99999999);
      expect(farBack.segments.single.startUs, 0);
    });
  });

  group('editor history', () {
    test('undo and redo walk the same path back and forth', () {
      final SubtitleEditorModel model =
          SubtitleEditorModel(document: doc(<SubtitleSegment>[seg('a', 0, 1000, 'یک')]));
      expect(model.canUndo, isFalse);
      model.setText('a', 'دو');
      expect(model.document.segments.single.text, 'دو');
      expect(model.canUndo, isTrue);
      expect(model.snapshot.dirty, isTrue);
      expect(model.undo(), isTrue);
      expect(model.document.segments.single.text, 'یک');
      expect(model.canRedo, isTrue);
      expect(model.redo(), isTrue);
      expect(model.document.segments.single.text, 'دو');
    });

    test('a new edit clears the redo stack', () {
      final SubtitleEditorModel model =
          SubtitleEditorModel(document: doc(<SubtitleSegment>[seg('a', 0, 1000, 'یک')]));
      model.setText('a', 'دو');
      model.undo();
      expect(model.canRedo, isTrue);
      model.setText('a', 'سه');
      expect(model.canRedo, isFalse);
    });

    test('history is bounded', () {
      final SubtitleEditorModel model = SubtitleEditorModel(
        document: doc(<SubtitleSegment>[seg('a', 0, 1000, 'x')]),
        historyLimit: 3,
      );
      for (int i = 0; i < 10; i++) {
        model.setText('a', 'متن $i');
      }
      expect(model.snapshot.undoDepth, 3);
    });

    test('no-op edits are not recorded', () {
      final SubtitleEditorModel model =
          SubtitleEditorModel(document: doc(<SubtitleSegment>[seg('a', 0, 1000, 'یک')]));
      expect(model.setText('a', 'یک'), isFalse);
      expect(model.canUndo, isFalse);
    });

    test('deleting the selected caption selects a neighbour', () {
      final SubtitleEditorModel model = SubtitleEditorModel(
        document: doc(<SubtitleSegment>[
          seg('a', 0, 1000, 'اول'),
          seg('b', 1200, 2000, 'دوم'),
        ]),
      );
      model.select('b');
      model.remove('b');
      expect(model.snapshot.selectionId, 'a');
    });

    test('style copy/paste and style-to-all are single undo steps', () {
      final SubtitleEditorModel model = SubtitleEditorModel(
        document: doc(<SubtitleSegment>[
          seg('a', 0, 1000, 'اول'),
          seg('b', 1200, 2000, 'دوم'),
        ]),
      );
      model.applyStyleToAll('style-1');
      expect(model.document.segments.every((SubtitleSegment s) => s.styleId == 'style-1'), isTrue);
      model.copyStyle();
      expect(model.clipboardStyleId, 'style-1');
      model.select('b');
      model.applyStyleToAll('style-2');
      model.pasteStyle();
      expect(model.document.byId('b')!.styleId, 'style-1');
      model.undo();
      expect(model.document.byId('b')!.styleId, 'style-2');
    });
  });

  group('preset -> style mapping', () {
    test('ASS alignment follows the caption position', () {
      expect(PresetStyleMapper.alignmentFor(0.9), 2);
      expect(PresetStyleMapper.alignmentFor(0.5), 5);
      expect(PresetStyleMapper.alignmentFor(0.1), 8);
    });

    test('font size follows the frame short edge, like the preview', () {
      final double portrait =
          PresetStyleMapper.fontSizeFor(PresetsLibrary.byId('viral-fa'), 1080, 1920);
      final double landscape =
          PresetStyleMapper.fontSizeFor(PresetsLibrary.byId('viral-fa'), 1920, 1080);
      expect(portrait, landscape, reason: 'short edge is 1080 in both orientations');
      expect(portrait, greaterThan(0));
    });

    test('Persian presets map to an RTL style with the same colours', () {
      final style = PresetStyleMapper.toStyle(
        PresetsLibrary.byId('viral-fa'),
        id: 'style-1',
        projectId: 'p1',
        nowMs: 0,
      );
      expect(style.direction, CaptionDirection.rtl);
      expect(style.textColor, PresetsLibrary.byId('viral-fa').textColor);
      expect(style.strokeWidth, PresetsLibrary.byId('viral-fa').strokeWidth);
      expect(style.projectId, 'p1');
    });
  });
}
