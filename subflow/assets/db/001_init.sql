-- SubFlow schema v1.
--
-- Conventions
--   * every timestamp is INTEGER microseconds since timeline start, never REAL
--   * every *_ms column is a Unix epoch in milliseconds (wall clock only);
--   * fractional positions are stored as permille (0..1000) or percent (0..100);
--   * no user data is ever deleted by the app without an explicit user action,
--     so cascades only run when a project itself is deleted.
PRAGMA foreign_keys = ON;

CREATE TABLE projects (
    id                    TEXT PRIMARY KEY,
    name                  TEXT NOT NULL,
    status                TEXT NOT NULL DEFAULT 'draft'
                              CHECK (status IN ('draft', 'importing', 'transcribing',
                                                'editing', 'ready', 'exporting')),
    thumbnail_path        TEXT,
    export_settings_json  TEXT,
    last_edit_label       TEXT,
    created_at_ms         INTEGER NOT NULL,
    updated_at_ms         INTEGER NOT NULL,
    last_opened_at_ms     INTEGER,
    deleted_at_ms         INTEGER
);

CREATE TABLE video_assets (
    id                 TEXT PRIMARY KEY,
    project_id         TEXT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    uri                TEXT NOT NULL,
    display_name       TEXT NOT NULL,
    size_bytes         INTEGER NOT NULL DEFAULT 0,
    duration_us        INTEGER NOT NULL DEFAULT 0 CHECK (duration_us >= 0),
    width              INTEGER NOT NULL DEFAULT 0,
    height             INTEGER NOT NULL DEFAULT 0,
    rotation_degrees   INTEGER NOT NULL DEFAULT 0,
    fps_milli          INTEGER NOT NULL DEFAULT 0,
    bitrate_bps        INTEGER NOT NULL DEFAULT 0,
    video_codec        TEXT,
    color_transfer     TEXT,
    hdr                INTEGER NOT NULL DEFAULT 0 CHECK (hdr IN (0, 1)),
    audio_codec        TEXT,
    audio_sample_rate  INTEGER NOT NULL DEFAULT 0,
    audio_channels     INTEGER NOT NULL DEFAULT 0,
    audio_bitrate_bps  INTEGER NOT NULL DEFAULT 0,
    probe_json         TEXT,
    is_missing         INTEGER NOT NULL DEFAULT 0 CHECK (is_missing IN (0, 1)),
    imported_at_ms     INTEGER NOT NULL
);

CREATE TABLE subtitle_tracks (
    id             TEXT PRIMARY KEY,
    project_id     TEXT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    kind           TEXT NOT NULL CHECK (kind IN ('original', 'translation', 'imported')),
    language       TEXT NOT NULL DEFAULT 'auto'
                       CHECK (language IN ('auto', 'fa', 'en', 'mixed')),
    label          TEXT NOT NULL,
    is_default     INTEGER NOT NULL DEFAULT 0 CHECK (is_default IN (0, 1)),
    created_at_ms  INTEGER NOT NULL,
    updated_at_ms  INTEGER NOT NULL
);

CREATE TABLE subtitle_styles (
    id                  TEXT PRIMARY KEY,
    project_id          TEXT REFERENCES projects(id) ON DELETE CASCADE,
    name                TEXT NOT NULL,
    is_template         INTEGER NOT NULL DEFAULT 0 CHECK (is_template IN (0, 1)),
    font_family         TEXT NOT NULL DEFAULT 'Vazirmatn',
    font_size           REAL NOT NULL DEFAULT 64.0,
    font_weight         INTEGER NOT NULL DEFAULT 400,
    text_color          INTEGER NOT NULL DEFAULT 16777215,
    gradient_enabled    INTEGER NOT NULL DEFAULT 0,
    gradient_color      INTEGER NOT NULL DEFAULT 0,
    stroke_color        INTEGER NOT NULL DEFAULT 0,
    stroke_width        REAL NOT NULL DEFAULT 0.0,
    shadow_enabled      INTEGER NOT NULL DEFAULT 0,
    shadow_color        INTEGER NOT NULL DEFAULT 0,
    shadow_blur         REAL NOT NULL DEFAULT 0.0,
    shadow_offset_x     REAL NOT NULL DEFAULT 0.0,
    shadow_offset_y     REAL NOT NULL DEFAULT 0.0,
    glow_enabled        INTEGER NOT NULL DEFAULT 0,
    glow_color          INTEGER NOT NULL DEFAULT 0,
    glow_radius         REAL NOT NULL DEFAULT 0.0,
    background_enabled  INTEGER NOT NULL DEFAULT 0,
    background_color    INTEGER NOT NULL DEFAULT 0,
    background_opacity  REAL NOT NULL DEFAULT 0.0,
    background_radius   REAL NOT NULL DEFAULT 0.0,
    character_spacing   REAL NOT NULL DEFAULT 0.0,
    line_spacing        REAL NOT NULL DEFAULT 1.0,
    text_align          TEXT NOT NULL DEFAULT 'center'
                            CHECK (text_align IN ('start', 'center', 'end')),
    text_direction      TEXT NOT NULL DEFAULT 'auto'
                            CHECK (text_direction IN ('auto', 'rtl', 'ltr')),
    rotation            REAL NOT NULL DEFAULT 0.0,
    position_x          REAL NOT NULL DEFAULT 0.5,
    position_y          REAL NOT NULL DEFAULT 0.86,
    width_fraction      REAL NOT NULL DEFAULT 0.86,
    padding             REAL NOT NULL DEFAULT 8.0,
    created_at_ms       INTEGER NOT NULL,
    updated_at_ms       INTEGER NOT NULL
);

CREATE TABLE subtitle_segments (
    id           TEXT PRIMARY KEY,
    track_id     TEXT NOT NULL REFERENCES subtitle_tracks(id) ON DELETE CASCADE,
    ordinal      INTEGER NOT NULL,
    start_us     INTEGER NOT NULL CHECK (start_us >= 0),
    end_us       INTEGER NOT NULL CHECK (end_us > start_us),
    text         TEXT NOT NULL,
    style_id     TEXT REFERENCES subtitle_styles(id) ON DELETE SET NULL,
    source       TEXT NOT NULL DEFAULT 'manual'
                     CHECK (source IN ('manual', 'whisper', 'imported')),
    confidence   REAL,
    created_at_ms INTEGER NOT NULL,
    updated_at_ms INTEGER NOT NULL,
    UNIQUE (track_id, ordinal)
);

CREATE TABLE subtitle_words (
    id          TEXT PRIMARY KEY,
    segment_id  TEXT NOT NULL REFERENCES subtitle_segments(id) ON DELETE CASCADE,
    ordinal     INTEGER NOT NULL,
    start_us    INTEGER NOT NULL CHECK (start_us >= 0),
    end_us      INTEGER NOT NULL CHECK (end_us >= start_us),
    text        TEXT NOT NULL,
    confidence  REAL,
    UNIQUE (segment_id, ordinal)
);

CREATE TABLE subtitle_effects (
    id           TEXT PRIMARY KEY,
    project_id   TEXT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    effect_key   TEXT NOT NULL,
    target_type  TEXT NOT NULL CHECK (target_type IN ('project', 'track', 'segment', 'style')),
    target_id    TEXT,
    params_json  TEXT NOT NULL DEFAULT '{}',
    start_us     INTEGER NOT NULL DEFAULT 0,
    end_us       INTEGER,
    z_index      INTEGER NOT NULL DEFAULT 0,
    created_at_ms INTEGER NOT NULL
);

CREATE TABLE animation_presets (
    id          TEXT PRIMARY KEY,
    name        TEXT NOT NULL,
    kind        TEXT NOT NULL CHECK (kind IN ('in', 'out', 'word', 'loop')),
    params_json TEXT NOT NULL,
    is_builtin  INTEGER NOT NULL DEFAULT 0,
    language    TEXT NOT NULL DEFAULT 'any' CHECK (language IN ('any', 'fa', 'en'))
);

CREATE TABLE watermarks (
    id            TEXT PRIMARY KEY,
    project_id    TEXT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    kind          TEXT NOT NULL CHECK (kind IN ('image', 'text')),
    payload       TEXT NOT NULL,
    font_family   TEXT NOT NULL DEFAULT 'Vazirmatn',
    font_size     REAL NOT NULL DEFAULT 48.0,
    color         INTEGER NOT NULL DEFAULT 16777215,
    opacity       REAL NOT NULL DEFAULT 1.0 CHECK (opacity >= 0 AND opacity <= 1),
    scale         REAL NOT NULL DEFAULT 1.0,
    rotation      REAL NOT NULL DEFAULT 0.0,
    position_x    REAL NOT NULL DEFAULT 0.9,
    position_y    REAL NOT NULL DEFAULT 0.08,
    anchor        TEXT NOT NULL DEFAULT 'center',
    start_us      INTEGER NOT NULL DEFAULT 0,
    end_us        INTEGER,
    fade_in_us    INTEGER NOT NULL DEFAULT 0,
    fade_out_us   INTEGER NOT NULL DEFAULT 0,
    z_index       INTEGER NOT NULL DEFAULT 0,
    created_at_ms INTEGER NOT NULL,
    updated_at_ms INTEGER NOT NULL
);

CREATE TABLE templates (
    id             TEXT PRIMARY KEY,
    name           TEXT NOT NULL,
    category       TEXT NOT NULL,
    language       TEXT NOT NULL DEFAULT 'any',
    style_json     TEXT NOT NULL,
    effects_json   TEXT NOT NULL DEFAULT '[]',
    preview_asset  TEXT,
    is_builtin     INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE translation_tracks (
    id                TEXT PRIMARY KEY,
    project_id        TEXT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    source_track_id   TEXT NOT NULL REFERENCES subtitle_tracks(id) ON DELETE CASCADE,
    target_track_id   TEXT NOT NULL REFERENCES subtitle_tracks(id) ON DELETE CASCADE,
    source_language   TEXT NOT NULL,
    target_language   TEXT NOT NULL,
    model_id          TEXT,
    engine            TEXT NOT NULL DEFAULT 'none',
    created_at_ms     INTEGER NOT NULL
);

CREATE TABLE export_jobs (
    id              TEXT PRIMARY KEY,
    project_id      TEXT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    status          TEXT NOT NULL DEFAULT 'queued'
                        CHECK (status IN ('queued', 'running', 'paused', 'succeeded',
                                          'failed', 'cancelled')),
    mode            TEXT NOT NULL CHECK (mode IN ('rendered_video', 'subtitles_only',
                                                  'passthrough_video')),
    plan_json       TEXT,
    output_path     TEXT,
    subtitle_paths_json TEXT,
    error_code      TEXT,
    created_at_ms   INTEGER NOT NULL,
    finished_at_ms  INTEGER
);

CREATE TABLE ai_models (
    id            TEXT PRIMARY KEY,
    kind          TEXT NOT NULL CHECK (kind IN ('whisper', 'translation')),
    variant       TEXT NOT NULL,
    display_name  TEXT NOT NULL,
    language_support TEXT NOT NULL DEFAULT 'multi',
    file_path     TEXT,
    size_bytes    INTEGER NOT NULL DEFAULT 0,
    sha256        TEXT,
    license       TEXT,
    state         TEXT NOT NULL DEFAULT 'not_installed'
                      CHECK (state IN ('not_installed', 'downloading', 'verifying',
                                       'installed', 'corrupt')),
    downloaded_bytes INTEGER NOT NULL DEFAULT 0,
    is_default    INTEGER NOT NULL DEFAULT 0,
    installed_at_ms INTEGER
);

CREATE TABLE app_settings (
    key           TEXT PRIMARY KEY,
    value         TEXT NOT NULL,
    updated_at_ms INTEGER NOT NULL
);

CREATE TABLE edit_history (
    id            TEXT PRIMARY KEY,
    project_id    TEXT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    seq           INTEGER NOT NULL,
    label         TEXT NOT NULL,
    snapshot_json TEXT NOT NULL,
    created_at_ms INTEGER NOT NULL,
    is_undone     INTEGER NOT NULL DEFAULT 0,
    UNIQUE (project_id, seq)
);

CREATE INDEX idx_video_assets_project ON video_assets(project_id);
CREATE INDEX idx_tracks_project ON subtitle_tracks(project_id);
CREATE INDEX idx_segments_track_time ON subtitle_segments(track_id, start_us);
CREATE INDEX idx_words_segment ON subtitle_words(segment_id, ordinal);
CREATE INDEX idx_styles_project ON subtitle_styles(project_id);
CREATE INDEX idx_effects_project ON subtitle_effects(project_id);
CREATE INDEX idx_watermarks_project ON watermarks(project_id, z_index);
CREATE INDEX idx_export_jobs_project ON export_jobs(project_id, created_at_ms DESC);
CREATE INDEX idx_edit_history_project ON edit_history(project_id, seq);
CREATE INDEX idx_projects_recent ON projects(deleted_at_ms, last_opened_at_ms DESC);

PRAGMA user_version = 1;
