-- Schema v2: translation provenance + human review workflow.
--
-- A translated track always keeps a pointer to the track it was translated
-- from, so the original text can never be lost or overwritten. Segments gain a
-- review state so machine output is visibly marked until a human confirms it.
PRAGMA foreign_keys = ON;

ALTER TABLE subtitle_tracks ADD COLUMN original_track_id TEXT
    REFERENCES subtitle_tracks(id) ON DELETE SET NULL;

ALTER TABLE subtitle_segments ADD COLUMN review_state TEXT NOT NULL DEFAULT 'unreviewed'
    CHECK (review_state IN ('unreviewed', 'edited', 'approved'));

CREATE INDEX idx_tracks_original ON subtitle_tracks(original_track_id);
CREATE INDEX idx_segments_review ON subtitle_segments(track_id, review_state);

PRAGMA user_version = 2;
