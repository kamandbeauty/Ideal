-- Per-caption style override (0.11.0).
--
-- The project style stays the default for every caption; this column lets a
-- single line carry its own CaptionPreset, serialised with the same toMap()
-- the Flutter preview and the native renderer already understand. Storing the
-- JSON (instead of another foreign key) is deliberate: a per-line style is an
-- arbitrary combination of font, colours, effects and animation, not one of a
-- fixed set of rows.
ALTER TABLE subtitle_segments ADD COLUMN preset_json TEXT;

-- Bookkeeping: the migration runner also sets this, but keeping it in the file
-- keeps `check-project.py` and a manual `sqlite3` run in agreement.
PRAGMA user_version = 3;
