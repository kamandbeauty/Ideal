import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../core/time_us.dart';
import '../../models/enums.dart';
import '../../models/subtitle.dart';

/// Immutable, *validated* subtitle document plus every edit operation.
///
/// The database can only hold segments that satisfy `end_us > start_us`, and the
/// renderer/export path assumes the list is sorted and non-overlapping. Rather
/// than trusting callers, every mutation here returns a document that has been
/// re-normalised: sorted by start time, clamped to the timeline, no overlaps,
/// and each segment at least [minSegmentUs] long.
///
/// This class is deliberately pure Dart (no Flutter widgets, no database, no
/// clock) so the editing rules can be unit-tested exactly, which is the only way
/// to know that split/merge/retime do not corrupt a user's subtitles.
@immutable
class SubtitleDocument {
  SubtitleDocument({
    required this.trackId,
    required List<SubtitleSegment> segments,
    DateTime Function()? clock,
  })  : _clock = clock ?? DateTime.now,
        segments = List<SubtitleSegment>.unmodifiable(
          _normalise(segments, clock ?? DateTime.now),
        );

  /// Shortest allowed caption. Below ~120 ms a line cannot be read and some
  /// players drop it entirely.
  static const int minSegmentUs = 120000;

  /// Length used when a segment is created without an explicit range.
  static const int defaultSegmentUs = 2000000;

  /// Undo history is bounded by the controller, not here.
  final String trackId;
  final List<SubtitleSegment> segments;
  final DateTime Function() _clock;

  static int _idCounter = 0;

  /// Ids only need to be unique inside one database; a counter plus a timestamp
  /// keeps them stable across restores without pulling in a uuid dependency.
  static String newId(String prefix) {
    _idCounter += 1;
    return '$prefix-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-$_idCounter';
  }

  factory SubtitleDocument.empty(String trackId, {DateTime Function()? clock}) =>
      SubtitleDocument(trackId: trackId, segments: const <SubtitleSegment>[], clock: clock);

  bool get isEmpty => segments.isEmpty;
  bool get isNotEmpty => segments.isNotEmpty;
  int get length => segments.length;

  /// End of the last caption, or 0 when the document is empty.
  int get lastEndUs => segments.isEmpty ? 0 : segments.last.endUs;

  int get totalTextLength =>
      segments.fold<int>(0, (int sum, SubtitleSegment s) => sum + s.text.length);

  int get msNow => _clock().millisecondsSinceEpoch;

  // --------------------------------------------------------------- lookups
  /// Index of the segment that contains [timeUs], or null.
  ///
  /// Segments are treated as half-open `[start, end)`; the very last one also
  /// matches its end instant so a playhead parked at the exact end of the video
  /// still shows the final caption.
  int? indexAt(int timeUs) {
    if (segments.isEmpty) return null;
    int low = 0;
    int high = segments.length - 1;
    while (low <= high) {
      final int mid = (low + high) ~/ 2;
      final SubtitleSegment segment = segments[mid];
      if (timeUs < segment.startUs) {
        high = mid - 1;
      } else if (timeUs >= segment.endUs) {
        low = mid + 1;
      } else {
        return mid;
      }
    }
    final int next = low;
    if (next >= segments.length && timeUs == segments.last.endUs) {
      return segments.length - 1;
    }
    return null;
  }

  SubtitleSegment? segmentAt(int timeUs) {
    final int? index = indexAt(timeUs);
    return index == null ? null : segments[index];
  }

  int indexOf(String segmentId) => segments.indexWhere((SubtitleSegment s) => s.id == segmentId);

  SubtitleSegment? byId(String segmentId) {
    final int index = indexOf(segmentId);
    return index < 0 ? null : segments[index];
  }

  /// Word under the playhead. Falls back to the word that started most recently
  /// so a karaoke highlight never blinks off between words.
  int? wordIndexAt(String segmentId, int timeUs) {
    final SubtitleSegment? segment = byId(segmentId);
    if (segment == null || segment.words.isEmpty) return null;
    int candidate = 0;
    for (int i = 0; i < segment.words.length; i++) {
      final SubtitleWord word = segment.words[i];
      if (timeUs >= word.startUs) {
        candidate = i;
      }
      if (timeUs >= word.startUs && timeUs < word.endUs) return i;
    }
    return candidate;
  }

  // ------------------------------------------------------------- mutations
  SubtitleDocument withText(String segmentId, String text) {
    final int index = indexOf(segmentId);
    if (index < 0) return this;
    final SubtitleSegment segment = segments[index];
    if (segment.text == text) return this;
    final SubtitleSegment updated = segment.copyWith(
      text: text,
      updatedAtMs: msNow,
      words: _spreadWords(segment.copyWith(text: text), text),
      reviewState: ReviewState.edited,
    );
    return _replace(index, updated);
  }

  /// Moves/extends one segment without ever letting it overlap its neighbours.
  SubtitleDocument withTiming(String segmentId, {int? startUs, int? endUs}) {
    final int index = indexOf(segmentId);
    if (index < 0) return this;
    final SubtitleSegment segment = segments[index];
    final int lowerBound = index == 0 ? 0 : segments[index - 1].endUs;
    final int upperBound =
        index == segments.length - 1 ? _maxEndUs(segment.startUs) : segments[index + 1].startUs;

    int start = startUs ?? segment.startUs;
    int end = endUs ?? segment.endUs;
    start = TimeUs.clamp(start, lowerBound, math.max(lowerBound, upperBound - minSegmentUs));
    end = TimeUs.clamp(end, start + minSegmentUs, math.max(start + minSegmentUs, upperBound));
    final SubtitleSegment updated = segment.copyWith(
      startUs: start,
      endUs: end,
      updatedAtMs: msNow,
      words: _spreadWords(segment.copyWith(startUs: start, endUs: end), segment.text),
    );
    return _replace(index, updated);
  }

  /// Inserts an empty caption at [atUs] and returns the document; the caller
  /// selects the new segment (`lastInsertedId`).
  SubtitleDocument insertAt(int atUs, {String text = ''}) {
    final int start = atUs < 0 ? 0 : atUs;
    final int? index = indexAt(start);
    int end = start + defaultSegmentUs;
    if (index != null) {
      // Inside an existing caption: leave a readable gap and stay before its end.
      end = math.min(segments[index].endUs, start + defaultSegmentUs);
      if (end - start < minSegmentUs) end = start + minSegmentUs;
    }
    final SubtitleSegment segment = SubtitleSegment(
      id: newId('seg'),
      trackId: trackId,
      ordinal: segments.length,
      startUs: start,
      endUs: end,
      text: text,
      source: SubtitleSource.manual,
      createdAtMs: msNow,
      updatedAtMs: msNow,
      reviewState: ReviewState.edited,
    );
    final SubtitleSegment withWords = segment.copyWith(words: _spreadWords(segment, text));
    return SubtitleDocument(
      trackId: trackId,
      segments: <SubtitleSegment>[...segments, withWords],
      clock: _clock,
    );
  }

  /// Splits a caption in two at [atUs]. Returns `this` when the split would
  /// produce a caption shorter than [minSegmentUs] on either side.
  SubtitleDocument splitAt(String segmentId, int atUs) {
    final int index = indexOf(segmentId);
    if (index < 0) return this;
    final SubtitleSegment segment = segments[index];
    if (atUs - segment.startUs < minSegmentUs || segment.endUs - atUs < minSegmentUs) {
      return this;
    }
    final List<String> words = _words(segment.text);
    if (words.length < 2) return this;

    final int cutWords = _cutIndex(segment, atUs, words.length);
    final String leftText = words.sublist(0, cutWords).join(' ');
    final String rightText = words.sublist(cutWords).join(' ');

    final SubtitleSegment left = segment.copyWith(
      endUs: atUs,
      text: leftText,
      updatedAtMs: msNow,
      reviewState: ReviewState.edited,
    );
    final SubtitleSegment rightBase = segment.copyWith(
      startUs: atUs,
      text: rightText,
      updatedAtMs: msNow,
      reviewState: ReviewState.edited,
    );
    final SubtitleSegment right = SubtitleSegment(
      id: newId('seg'),
      trackId: trackId,
      ordinal: 0,
      startUs: rightBase.startUs,
      endUs: segment.endUs,
      text: rightText,
      styleId: segment.styleId,
      source: segment.source,
      confidence: segment.confidence,
      reviewState: ReviewState.edited,
      createdAtMs: msNow,
      updatedAtMs: msNow,
    );
    final List<SubtitleSegment> next = <SubtitleSegment>[
      ...segments.sublist(0, index),
      left.copyWith(words: _spreadWords(left, leftText)),
      right.copyWith(words: _spreadWords(right, rightText)),
      ...segments.sublist(index + 1),
    ];
    return SubtitleDocument(trackId: trackId, segments: next, clock: _clock);
  }

  /// Merges [segmentId] with the caption that follows it.
  SubtitleDocument mergeWithNext(String segmentId) {
    final int index = indexOf(segmentId);
    if (index < 0 || index >= segments.length - 1) return this;
    final SubtitleSegment first = segments[index];
    final SubtitleSegment second = segments[index + 1];
    final String text = <String>[
      if (first.text.trim().isNotEmpty) first.text.trim(),
      if (second.text.trim().isNotEmpty) second.text.trim(),
    ].join(' ');
    final SubtitleSegment merged = first.copyWith(
      endUs: math.max(second.endUs, first.startUs + minSegmentUs),
      text: text,
      updatedAtMs: msNow,
      reviewState: ReviewState.edited,
    ).copyWith(words: _spreadWords(first.copyWith(endUs: second.endUs, text: text), text));
    final List<SubtitleSegment> next = <SubtitleSegment>[
      ...segments.sublist(0, index),
      merged,
      ...segments.sublist(index + 2),
    ];
    return SubtitleDocument(trackId: trackId, segments: next, clock: _clock);
  }

  SubtitleDocument remove(String segmentId) {
    final int index = indexOf(segmentId);
    if (index < 0) return this;
    final List<SubtitleSegment> next = <SubtitleSegment>[
      ...segments.sublist(0, index),
      ...segments.sublist(index + 1),
    ];
    return SubtitleDocument(trackId: trackId, segments: next, clock: _clock);
  }

  /// Shifts every caption (used after silence removal re-times the timeline).
  SubtitleDocument shiftAll(int deltaUs) {
    if (deltaUs == 0 || segments.isEmpty) return this;
    final List<SubtitleSegment> next = segments
        .map((SubtitleSegment s) => s.copyWith(
              startUs: math.max(0, s.startUs + deltaUs),
              endUs: math.max(minSegmentUs, s.endUs + deltaUs),
              words: s.words
                  .map((SubtitleWord w) => w.copyWith(
                        startUs: math.max(0, w.startUs + deltaUs),
                        endUs: math.max(0, w.endUs + deltaUs),
                      ))
                  .toList(growable: false),
              updatedAtMs: msNow,
            ))
        .toList(growable: false);
    return SubtitleDocument(trackId: trackId, segments: next, clock: _clock);
  }

  SubtitleDocument withStyle(String segmentId, String styleId) {
    final int index = indexOf(segmentId);
    if (index < 0) return this;
    return _replace(index, segments[index].copyWith(styleId: styleId, updatedAtMs: msNow));
  }

  /// Applies one style to every caption (used when a gallery look is chosen).
  SubtitleDocument withStyleAll(String styleId) {
    if (segments.isEmpty) return this;
    final List<SubtitleSegment> next = segments
        .map((SubtitleSegment s) => s.styleId == styleId
            ? s
            : s.copyWith(styleId: styleId, updatedAtMs: msNow))
        .toList(growable: false);
    return SubtitleDocument(trackId: trackId, segments: next, clock: _clock);
  }

  /// Copies the style reference of [fromId] onto every caption in [toIds].
  SubtitleDocument copyStyleFrom(String fromId, Iterable<String> toIds) {
    final SubtitleSegment? source = byId(fromId);
    if (source == null || source.styleId == null) return this;
    final Set<String> targets = toIds.toSet();
    if (targets.isEmpty) return this;
    final List<SubtitleSegment> next = segments
        .map((SubtitleSegment s) => targets.contains(s.id)
            ? s.copyWith(styleId: source.styleId, updatedAtMs: msNow)
            : s)
        .toList(growable: false);
    return SubtitleDocument(trackId: trackId, segments: next, clock: _clock);
  }

  // ------------------------------------------------- per-caption style (0.11)

  /// Pins a serialised `CaptionPreset` to one caption, or removes it.
  ///
  /// Passing null is the "back to the project style" gesture, so it clears the
  /// column instead of writing an empty string.
  SubtitleDocument withPreset(String segmentId, String? presetJson) {
    final int index = indexOf(segmentId);
    if (index < 0) return this;
    final SubtitleSegment current = segments[index];
    if ((current.presetJson ?? '') == (presetJson ?? '')) return this;
    return _replace(
      index,
      current.copyWith(
        presetJson: presetJson,
        clearPreset: presetJson == null,
        updatedAtMs: msNow,
      ),
    );
  }

  /// Copies one caption's own style onto every caption ("اعمال برای کل فیلم").
  ///
  /// Segments that are already the same stay untouched so the undo step only
  /// records real changes.
  SubtitleDocument withPresetFrom(String segmentId) {
    final SubtitleSegment? source = byId(segmentId);
    if (source == null) return this;
    final String? preset = source.presetJson;
    final List<SubtitleSegment> next = segments
        .map((SubtitleSegment s) => (s.presetJson ?? '') == (preset ?? '')
            ? s
            : s.copyWith(
                presetJson: preset,
                clearPreset: preset == null,
                updatedAtMs: msNow,
              ))
        .toList(growable: false);
    return SubtitleDocument(trackId: trackId, segments: next, clock: _clock);
  }

  // --------------------------------------------------------------- helpers
  SubtitleDocument _replace(int index, SubtitleSegment segment) {
    final List<SubtitleSegment> next = <SubtitleSegment>[...segments]..[index] = segment;
    return SubtitleDocument(trackId: trackId, segments: next, clock: _clock);
  }

  int _maxEndUs(int fallback) {
    if (segments.isEmpty) return fallback + defaultSegmentUs;
    final int end = segments.last.endUs;
    return end > fallback ? end : fallback + defaultSegmentUs;
  }

  /// Character count used as the duration weight of a word. Persian words are
  /// weighted by their visible characters, which keeps karaoke timing sane for
  /// short particles such as «و» or «را».
  static int _weightOf(String word) => math.max(1, word.replaceAll(RegExp(r'\s'), '').length);

  static List<String> _words(String text) =>
      text.trim().split(RegExp(r'\s+')).where((String w) => w.isNotEmpty).toList(growable: false);

  /// Distributes the segment's own time range across its words, proportional to
  /// word length. Existing word timings are *replaced* on purpose: after a text
  /// edit the old word times describe different words, and keeping them would
  /// light up the wrong word.
  static List<SubtitleWord> _spreadWords(SubtitleSegment segment, String text) {
    final List<String> words = _words(text);
    if (words.isEmpty) return const <SubtitleWord>[];
    final int span = math.max(minSegmentUs, segment.endUs - segment.startUs);
    final List<int> weights = words.map(_weightOf).toList(growable: false);
    final int totalWeight = weights.fold<int>(0, (int a, int b) => a + b);
    final List<SubtitleWord> result = <SubtitleWord>[];
    int cursor = segment.startUs;
    int consumed = 0;
    for (int i = 0; i < words.length; i++) {
      consumed += weights[i];
      final int isLast = i == words.length - 1 ? 1 : 0;
      final int end = isLast == 1
          ? segment.startUs + span
          : segment.startUs + (span * consumed / totalWeight).round();
      result.add(SubtitleWord(
        id: '${segment.id}-w$i',
        segmentId: segment.id,
        ordinal: i,
        startUs: cursor,
        endUs: math.max(cursor, end),
        text: words[i],
      ));
      cursor = math.max(cursor, end);
    }
    return List<SubtitleWord>.unmodifiable(result);
  }

  /// How many words belong to the left half of a split at [atUs].
  static int _cutIndex(SubtitleSegment segment, int atUs, int wordCount) {
    final List<SubtitleWord> words = segment.words;
    if (words.length == wordCount) {
      int cut = words.indexWhere((SubtitleWord w) => w.startUs >= atUs);
      if (cut <= 0) cut = wordCount ~/ 2;
      return TimeUs.clamp(cut, 1, wordCount - 1);
    }
    final int duration = math.max(1, segment.endUs - segment.startUs);
    final double ratio = (atUs - segment.startUs) / duration;
    return TimeUs.clamp((wordCount * ratio).round(), 1, wordCount - 1);
  }

  static List<SubtitleSegment> _normalise(
    List<SubtitleSegment> input,
    DateTime Function() clock,
  ) {
    final List<SubtitleSegment> sorted = List<SubtitleSegment>.of(input)
      ..sort((SubtitleSegment a, SubtitleSegment b) {
        final int byStart = a.startUs.compareTo(b.startUs);
        return byStart != 0 ? byStart : a.id.compareTo(b.id);
      });
    final List<SubtitleSegment> out = <SubtitleSegment>[];
    int lastEnd = 0;
    for (int i = 0; i < sorted.length; i++) {
      final SubtitleSegment segment = sorted[i];
      int start = segment.startUs < 0 ? 0 : segment.startUs;
      if (start < lastEnd) start = lastEnd;
      int end = segment.endUs;
      if (end < start + minSegmentUs) end = start + minSegmentUs;
      final SubtitleSegment fixed = (start == segment.startUs && end == segment.endUs)
          ? segment
          : segment.copyWith(startUs: start, endUs: end);
      // `ordinal` is not part of `copyWith` (order belongs to the store), so the
      // normalised position is written explicitly here.
      out.add(SubtitleSegment(
        id: fixed.id,
        trackId: fixed.trackId,
        ordinal: i,
        startUs: fixed.startUs,
        endUs: fixed.endUs,
        text: fixed.text,
        styleId: fixed.styleId,
        source: fixed.source,
        confidence: fixed.confidence,
        reviewState: fixed.reviewState,
        createdAtMs: fixed.createdAtMs,
        updatedAtMs: fixed.updatedAtMs,
        words: fixed.words,
      ));
      lastEnd = end;
    }
    return out;
  }
}
