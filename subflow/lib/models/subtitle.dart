import 'enums.dart';

/// One subtitle track of a project (original, machine translation or import).
class SubtitleTrack {
  const SubtitleTrack({
    required this.id,
    required this.projectId,
    required this.kind,
    required this.language,
    required this.label,
    required this.isDefault,
    required this.createdAtMs,
    required this.updatedAtMs,
    this.originalTrackId,
  });

  final String id;
  final String projectId;
  final TrackKind kind;
  final SubtitleLanguage language;
  final String label;
  final bool isDefault;
  final int createdAtMs;
  final int updatedAtMs;

  /// Set on translation tracks: the original track whose text must never change.
  final String? originalTrackId;

  factory SubtitleTrack.fromMap(Map<String, Object?> map) => SubtitleTrack(
        id: map['id']! as String,
        projectId: map['project_id']! as String,
        kind: TrackKind.fromDb(map['kind'] as String?),
        language: SubtitleLanguage.fromDb(map['language'] as String?),
        label: map['label']! as String,
        isDefault: ((map['is_default'] as int?) ?? 0) == 1,
        createdAtMs: map['created_at_ms']! as int,
        updatedAtMs: map['updated_at_ms']! as int,
        originalTrackId: map['original_track_id'] as String?,
      );

  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        'project_id': projectId,
        'kind': kind.dbValue,
        'language': language.dbValue,
        'label': label,
        'is_default': isDefault ? 1 : 0,
        'created_at_ms': createdAtMs,
        'updated_at_ms': updatedAtMs,
        'original_track_id': originalTrackId,
      };
}

class SubtitleWord {
  const SubtitleWord({
    required this.id,
    required this.segmentId,
    required this.ordinal,
    required this.startUs,
    required this.endUs,
    required this.text,
    this.confidence,
  });

  final String id;
  final String segmentId;
  final int ordinal;
  final int startUs;
  final int endUs;
  final String text;
  final double? confidence;

  factory SubtitleWord.fromMap(Map<String, Object?> map) => SubtitleWord(
        id: map['id']! as String,
        segmentId: map['segment_id']! as String,
        ordinal: map['ordinal']! as int,
        startUs: map['start_us']! as int,
        endUs: map['end_us']! as int,
        text: map['text']! as String,
        confidence: (map['confidence'] as num?)?.toDouble(),
      );

  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        'segment_id': segmentId,
        'ordinal': ordinal,
        'start_us': startUs,
        'end_us': endUs,
        'text': text,
        'confidence': confidence,
      };

  SubtitleWord copyWith({int? startUs, int? endUs, String? text}) => SubtitleWord(
        id: id,
        segmentId: segmentId,
        ordinal: ordinal,
        startUs: startUs ?? this.startUs,
        endUs: endUs ?? this.endUs,
        text: text ?? this.text,
        confidence: confidence,
      );
}

/// One caption line. `endUs > startUs` is enforced by the database.
class SubtitleSegment {
  const SubtitleSegment({
    required this.id,
    required this.trackId,
    required this.ordinal,
    required this.startUs,
    required this.endUs,
    required this.text,
    required this.source,
    required this.createdAtMs,
    required this.updatedAtMs,
    this.styleId,
    this.confidence,
    this.reviewState = ReviewState.unreviewed,
    this.words = const <SubtitleWord>[],
    this.presetJson,
  });

  final String id;
  final String trackId;
  final int ordinal;
  final int startUs;
  final int endUs;
  final String text;
  final String? styleId;
  final SubtitleSource source;
  final double? confidence;
  final ReviewState reviewState;
  final int createdAtMs;
  final int updatedAtMs;
  final List<SubtitleWord> words;

  /// Per-caption style override, serialised with `CaptionPreset.toMap()`.
  ///
  /// Null means "use the project style" - the common case, and the reason an
  /// existing project keeps looking identical after the column was added.
  final String? presetJson;

  bool get hasOwnStyle => presetJson != null && presetJson!.isNotEmpty;

  int get durationUs => endUs - startUs;

  factory SubtitleSegment.fromMap(Map<String, Object?> map) => SubtitleSegment(
        id: map['id']! as String,
        trackId: map['track_id']! as String,
        ordinal: map['ordinal']! as int,
        startUs: map['start_us']! as int,
        endUs: map['end_us']! as int,
        text: map['text']! as String,
        styleId: map['style_id'] as String?,
        source: SubtitleSource.fromDb(map['source'] as String?),
        confidence: (map['confidence'] as num?)?.toDouble(),
        reviewState: ReviewState.fromDb(map['review_state'] as String?),
        createdAtMs: map['created_at_ms']! as int,
        updatedAtMs: map['updated_at_ms']! as int,
        presetJson: map['preset_json'] as String?,
      );

  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        'track_id': trackId,
        'ordinal': ordinal,
        'start_us': startUs,
        'end_us': endUs,
        'text': text,
        'style_id': styleId,
        'source': source.dbValue,
        'confidence': confidence,
        'review_state': reviewState.dbValue,
        'created_at_ms': createdAtMs,
        'updated_at_ms': updatedAtMs,
        'preset_json': presetJson,
      };

  SubtitleSegment copyWith({
    int? startUs,
    int? endUs,
    String? text,
    String? styleId,
    ReviewState? reviewState,
    List<SubtitleWord>? words,
    int? updatedAtMs,
    String? presetJson,
    bool clearPreset = false,
  }) {
    return SubtitleSegment(
      id: id,
      trackId: trackId,
      ordinal: ordinal,
      startUs: startUs ?? this.startUs,
      endUs: endUs ?? this.endUs,
      text: text ?? this.text,
      styleId: styleId ?? this.styleId,
      source: source,
      confidence: confidence,
      reviewState: reviewState ?? this.reviewState,
      createdAtMs: createdAtMs,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      words: words ?? this.words,
      presetJson: clearPreset ? null : (presetJson ?? this.presetJson),
    );
  }
}
