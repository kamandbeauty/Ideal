/// Database-backed enums. The `CHECK (...)` constraints in the SQL schema are
/// the authority for allowed values; these helpers must stay in sync with them.
String _snakeCase(String camel) => camel.replaceAllMapped(
      RegExp('[A-Z]'),
      (Match match) => '_${match.group(0)!.toLowerCase()}',
    );

mixin DbEnum on Enum {
  String get dbValue => _snakeCase(name);
}

T _fromDb<T extends Enum>(List<T> values, String? raw, T fallback) {
  if (raw == null) return fallback;
  for (final T value in values) {
    if (value is DbEnum && (value as DbEnum).dbValue == raw) return value;
    if (value.name == raw) return value;
  }
  return fallback;
}

enum ProjectStatus with DbEnum {
  draft,
  importing,
  transcribing,
  editing,
  ready,
  exporting;

  static ProjectStatus fromDb(String? raw) =>
      _fromDb(ProjectStatus.values, raw, ProjectStatus.draft);
}

enum TrackKind with DbEnum {
  original,
  translation,
  imported;

  static TrackKind fromDb(String? raw) => _fromDb(TrackKind.values, raw, TrackKind.original);
}

enum SubtitleLanguage with DbEnum {
  auto,
  fa,
  en,
  mixed;

  static SubtitleLanguage fromDb(String? raw) =>
      _fromDb(SubtitleLanguage.values, raw, SubtitleLanguage.auto);

  String get label => switch (this) {
        SubtitleLanguage.auto => 'تشخیص خودکار',
        SubtitleLanguage.fa => 'فارسی',
        SubtitleLanguage.en => 'English',
        SubtitleLanguage.mixed => 'فارسی + انگلیسی',
      };
}

enum SubtitleSource with DbEnum {
  manual,
  whisper,
  imported;

  static SubtitleSource fromDb(String? raw) =>
      _fromDb(SubtitleSource.values, raw, SubtitleSource.manual);
}

enum ReviewState with DbEnum {
  unreviewed,
  edited,
  approved;

  static ReviewState fromDb(String? raw) =>
      _fromDb(ReviewState.values, raw, ReviewState.unreviewed);
}

enum ModelKind with DbEnum {
  whisper,
  translation;

  static ModelKind fromDb(String? raw) => _fromDb(ModelKind.values, raw, ModelKind.whisper);
}

enum ModelState with DbEnum {
  notInstalled,
  downloading,
  verifying,
  installed,
  corrupt;

  static ModelState fromDb(String? raw) =>
      _fromDb(ModelState.values, raw, ModelState.notInstalled);
}

enum ExportMode with DbEnum {
  renderedVideo,
  subtitlesOnly,
  passthroughVideo;

  static ExportMode fromDb(String? raw) =>
      _fromDb(ExportMode.values, raw, ExportMode.renderedVideo);
}

enum ExportStatus with DbEnum {
  queued,
  running,
  paused,
  succeeded,
  failed,
  cancelled;

  static ExportStatus fromDb(String? raw) =>
      _fromDb(ExportStatus.values, raw, ExportStatus.queued);
}

/// Horizontal text alignment stored as a string so ASS/SRT export and the Dart
/// preview use one vocabulary.
enum CaptionAlign {
  start,
  center,
  end;

  String get dbValue => name;
  static CaptionAlign fromDb(String? raw) =>
      raw == 'start' ? CaptionAlign.start : (raw == 'end' ? CaptionAlign.end : CaptionAlign.center);
}

enum CaptionDirection {
  auto,
  rtl,
  ltr;

  String get dbValue => name;
  static CaptionDirection fromDb(String? raw) => raw == 'rtl'
      ? CaptionDirection.rtl
      : (raw == 'ltr' ? CaptionDirection.ltr : CaptionDirection.auto);
}
