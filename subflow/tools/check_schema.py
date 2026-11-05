#!/usr/bin/env python3
"""Executes the real SubFlow migrations against SQLite and asserts the schema.

This is not a mock: it runs the exact .sql files that ship in
subflow/assets/db, with the same "split on ';' + newline" rule the Dart
AppDatabase uses, then inspects the resulting database with SQLite's own
introspection.

Checks
  1. every migration statement executes on a fresh database;
  2. user_version ends at manifest.schemaVersion;
  3. all expected tables / columns exist;
  4. foreign keys cascade (deleting a project removes its children);
  5. CHECK constraints reject impossible timestamps and values;
  6. UNIQUE constraints hold;
  7. a v1 database with real rows upgrades to v2 without losing data;
  8. the indices used by the hot queries exist.

Exit code 0 => schema verified.
"""
from __future__ import annotations

import json
import re
import sqlite3
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DB_DIR = ROOT / "assets" / "db"
MANIFEST = DB_DIR / "manifest.json"

failures: list[str] = []
checks = 0


def check(condition: bool, message: str) -> None:
    global checks
    checks += 1
    if not condition:
        failures.append(message)


def split_statements(sql: str) -> list[str]:
    """Mirror of AppDatabase.splitStatements (Dart).

    Comments are stripped and empty fragments dropped, because a comment-only
    statement makes Android's execSQL fail with "not an error (code 0)".
    """
    statements: list[str] = []
    current: list[str] = []
    quote: str | None = None
    in_line = False
    in_block = False

    def flush() -> None:
        statement = "".join(current).strip()
        current.clear()
        if statement:
            statements.append(statement)

    i = 0
    n = len(sql)
    while i < n:
        char = sql[i]
        nxt = sql[i + 1] if i + 1 < n else ""
        if in_line:
            if char == "\n":
                in_line = False
                current.append("\n")
            i += 1
            continue
        if in_block:
            if char == "*" and nxt == "/":
                in_block = False
                i += 1
            i += 1
            continue
        if quote is not None:
            current.append(char)
            if char == quote:
                if nxt == quote:
                    current.append(nxt)
                    i += 1
                else:
                    quote = None
            i += 1
            continue
        if char in ("'", '"', "`"):
            quote = char
            current.append(char)
            i += 1
            continue
        if char == "-" and nxt == "-":
            in_line = True
            i += 2
            continue
        if char == "/" and nxt == "*":
            in_block = True
            i += 2
            continue
        if char == ";":
            flush()
            i += 1
            continue
        current.append(char)
        i += 1
    flush()
    return statements


def column_names(conn: sqlite3.Connection, table: str) -> set[str]:
    return {row[1] for row in conn.execute(f"PRAGMA table_info({table})")}


def table_names(conn: sqlite3.Connection) -> set[str]:
    return {
        row[0]
        for row in conn.execute(
            "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'"
        )
    }


def index_names(conn: sqlite3.Connection) -> set[str]:
    return {row[0] for row in conn.execute("SELECT name FROM sqlite_master WHERE type='index'")}


EXPECTED_TABLES = {
    "projects",
    "video_assets",
    "subtitle_tracks",
    "subtitle_segments",
    "subtitle_words",
    "subtitle_styles",
    "subtitle_effects",
    "animation_presets",
    "watermarks",
    "templates",
    "translation_tracks",
    "export_jobs",
    "ai_models",
    "app_settings",
    "edit_history",
}

EXPECTED_INDICES = {
    "idx_video_assets_project",
    "idx_tracks_project",
    "idx_segments_track_time",
    "idx_words_segment",
    "idx_styles_project",
    "idx_effects_project",
    "idx_watermarks_project",
    "idx_export_jobs_project",
    "idx_edit_history_project",
    "idx_projects_recent",
    "idx_tracks_original",
    "idx_segments_review",
}

REQUIRED_COLUMNS = {
    "projects": {"id", "name", "status", "created_at_ms", "updated_at_ms", "deleted_at_ms",
                  "export_settings_json"},
    "video_assets": {"id", "project_id", "uri", "duration_us", "width", "height", "fps_milli",
                     "bitrate_bps", "hdr", "audio_sample_rate", "audio_channels", "is_missing"},
    "subtitle_tracks": {"id", "project_id", "kind", "language", "is_default",
                        "original_track_id"},
    "subtitle_segments": {"id", "track_id", "ordinal", "start_us", "end_us", "text",
                          "style_id", "source", "review_state"},
    "subtitle_words": {"id", "segment_id", "ordinal", "start_us", "end_us", "text"},
    "subtitle_styles": {"id", "project_id", "name", "font_family", "font_size", "font_weight",
                        "text_color", "gradient_enabled", "stroke_width", "shadow_enabled",
                        "glow_enabled", "background_enabled", "character_spacing",
                        "line_spacing", "text_align", "text_direction", "position_x",
                        "position_y", "width_fraction"},
    "watermarks": {"id", "project_id", "kind", "payload", "opacity", "position_x", "position_y",
                   "start_us", "end_us", "fade_in_us", "fade_out_us"},
    "export_jobs": {"id", "project_id", "status", "mode", "plan_json", "output_path",
                    "error_code"},
    "ai_models": {"id", "kind", "variant", "size_bytes", "sha256", "state", "is_default"},
    "edit_history": {"id", "project_id", "seq", "snapshot_json", "is_undone"},
}


def apply_migrations(conn: sqlite3.Connection, manifest: dict, upto: int) -> int:
    # Only apply migrations newer than the database's own user_version - the
    # same rule AppDatabase follows on device.
    applied = 0
    current = conn.execute("PRAGMA user_version").fetchone()[0]
    for migration in manifest["migrations"]:
        if migration["version"] <= current:
            continue
        if migration["version"] > upto:
            break
        path = ROOT / migration["file"]
        sql = path.read_text(encoding="utf-8")
        statements = split_statements(sql)
        check(len(statements) >= 5, f"{path.name}: expected several statements, got {len(statements)}")
        for index, statement in enumerate(statements):
            try:
                conn.execute(statement)
            except sqlite3.Error as exc:  # noqa: PERF203 - explicit diagnostics
                check(False, f"{path.name}: statement #{index + 1} failed: {exc}\n{statement[:160]}")
        applied += 1
    return applied


def seed_project(conn: sqlite3.Connection) -> None:
    conn.execute(
        "INSERT INTO projects (id, name, status, created_at_ms, updated_at_ms) "
        "VALUES ('p1', 'پروژه آزمایشی', 'editing', 1700000000000, 1700000000000)"
    )
    conn.execute(
        "INSERT INTO video_assets (id, project_id, uri, display_name, size_bytes, duration_us, "
        "width, height, rotation_degrees, fps_milli, bitrate_bps, imported_at_ms) "
        "VALUES ('v1', 'p1', 'content://media/1', 'clip.mp4', 12345678, 60000000, 1920, 1080, 0, "
        "29970, 8000000, 1700000000000)"
    )
    conn.execute(
        "INSERT INTO subtitle_tracks (id, project_id, kind, language, label, is_default, "
        "created_at_ms, updated_at_ms) VALUES ('t1', 'p1', 'original', 'fa', 'فارسی', 1, "
        "1700000000000, 1700000000000)"
    )
    conn.execute(
        "INSERT INTO subtitle_segments (id, track_id, ordinal, start_us, end_us, text, source, "
        "created_at_ms, updated_at_ms) VALUES ('s1', 't1', 0, 500000, 2250000, "
        "'سلام دنیا (SubFlow)', 'whisper', 1700000000000, 1700000000000)"
    )
    conn.execute(
        "INSERT INTO subtitle_words (id, segment_id, ordinal, start_us, end_us, text) "
        "VALUES ('w1', 's1', 0, 500000, 900000, 'سلام'), "
        "('w2', 's1', 1, 950000, 1500000, 'دنیا')"
    )


def main() -> int:
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    check(manifest["schemaVersion"] == 2, "manifest schemaVersion should be 2")
    check([m["version"] for m in manifest["migrations"]] == [1, 2],
          "migrations must be ordered 1,2")

    # ---------------------------------------------------------------- fresh db
    conn = sqlite3.connect(":memory:")
    conn.execute("PRAGMA foreign_keys = ON")
    applied = apply_migrations(conn, manifest, manifest["schemaVersion"])
    check(applied == 2, f"expected 2 migrations applied, got {applied}")

    version = conn.execute("PRAGMA user_version").fetchone()[0]
    check(version == 2, f"user_version should be 2, got {version}")

    tables = table_names(conn)
    missing_tables = EXPECTED_TABLES - tables
    check(not missing_tables, f"missing tables: {sorted(missing_tables)}")

    for table, required in REQUIRED_COLUMNS.items():
        if table not in tables:
            continue
        columns = column_names(conn, table)
        missing = required - columns
        check(not missing, f"{table}: missing columns {sorted(missing)}")

    indices = index_names(conn)
    check(not (EXPECTED_INDICES - indices), f"missing indices: {sorted(EXPECTED_INDICES - indices)}")

    # ------------------------------------------------------ constraints alive?
    seed_project(conn)
    check(conn.execute("SELECT COUNT(*) FROM subtitle_segments").fetchone()[0] == 1,
          "seed segment should exist")

    def expect_failure(label: str, sql: str, params: tuple = ()) -> None:
        try:
            conn.execute(sql, params)
        except sqlite3.DatabaseError:
            check(True, label)
        else:
            check(False, f"constraint not enforced: {label}")

    # end_us must be strictly after start_us: a zero-length cue breaks every renderer.
    expect_failure(
        "segment with end_us <= start_us rejected",
        "INSERT INTO subtitle_segments (id, track_id, ordinal, start_us, end_us, text, "
        "created_at_ms, updated_at_ms) VALUES ('bad', 't1', 9, 1000000, 1000000, 'x', 0, 0)",
    )
    expect_failure(
        "negative start_us rejected",
        "INSERT INTO subtitle_segments (id, track_id, ordinal, start_us, end_us, text, "
        "created_at_ms, updated_at_ms) VALUES ('bad2', 't1', 10, -1, 500000, 'x', 0, 0)",
    )
    expect_failure(
        "duplicate (track_id, ordinal) rejected",
        "INSERT INTO subtitle_segments (id, track_id, ordinal, start_us, end_us, text, "
        "created_at_ms, updated_at_ms) VALUES ('dup', 't1', 0, 3000000, 4000000, 'x', 0, 0)",
    )
    expect_failure(
        "unknown track kind rejected",
        "INSERT INTO subtitle_tracks (id, project_id, kind, language, label, is_default, "
        "created_at_ms, updated_at_ms) VALUES ('t9', 'p1', 'klingon', 'fa', 'x', 0, 0, 0)",
    )
    expect_failure(
        "watermark opacity above 1 rejected",
        "INSERT INTO watermarks (id, project_id, kind, payload, opacity, created_at_ms, "
        "updated_at_ms) VALUES ('w9', 'p1', 'text', 'x', 1.5, 0, 0)",
    )
    expect_failure(
        "segment pointing at a missing track rejected",
        "INSERT INTO subtitle_segments (id, track_id, ordinal, start_us, end_us, text, "
        "created_at_ms, updated_at_ms) VALUES ('orphan', 'nope', 0, 0, 1000, 'x', 0, 0)",
    )

    # --------------------------------------------------------------- cascades
    conn2 = sqlite3.connect(":memory:")
    conn2.execute("PRAGMA foreign_keys = ON")
    apply_migrations(conn2, manifest, manifest["schemaVersion"])
    seed_project(conn2)
    conn2.execute(
        "INSERT INTO watermarks (id, project_id, kind, payload, created_at_ms, updated_at_ms) "
        "VALUES ('wm1', 'p1', 'text', '@subflow', 0, 0)"
    )
    conn2.execute("DELETE FROM projects WHERE id = 'p1'")
    for table in ("video_assets", "subtitle_tracks", "subtitle_segments", "subtitle_words",
                  "watermarks"):
        count = conn2.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0]
        check(count == 0, f"cascade failed: {table} still has {count} rows")

    # --------------------------------------------------- v1 -> v2 upgrade path
    conn3 = sqlite3.connect(":memory:")
    conn3.execute("PRAGMA foreign_keys = ON")
    apply_migrations(conn3, manifest, 1)
    check(conn3.execute("PRAGMA user_version").fetchone()[0] == 1, "v1 db should be at version 1")
    seed_project(conn3)
    check("review_state" not in column_names(conn3, "subtitle_segments"),
          "review_state must not exist before v2")
    apply_migrations(conn3, manifest, 2)
    check("review_state" in column_names(conn3, "subtitle_segments"), "v2 adds review_state")
    check("original_track_id" in column_names(conn3, "subtitle_tracks"),
          "v2 adds original_track_id")
    text = conn3.execute("SELECT text FROM subtitle_segments WHERE id='s1'").fetchone()[0]
    check(text == "سلام دنیا (SubFlow)", "user data must survive the migration verbatim")
    check(conn3.execute("SELECT review_state FROM subtitle_segments WHERE id='s1'").fetchone()[0]
          == "unreviewed", "existing rows default to 'unreviewed'")

    # ------------------------------------------------------ microsecond integrity
    conn4 = sqlite3.connect(":memory:")
    apply_migrations(conn4, manifest, manifest["schemaVersion"])
    seed_project(conn4)
    stored_start = conn4.execute("SELECT start_us FROM subtitle_segments WHERE id='s1'").fetchone()[0]
    check(isinstance(stored_start, int) and stored_start == 500000,
          "timestamps must round-trip as exact integers of microseconds")

    total = checks
    print(f"SubFlow schema check: {total} assertions, {len(failures)} failure(s)")
    for failure in failures:
        print(f"  FAIL {failure}")
    return 0 if not failures else 1


if __name__ == "__main__":
    sys.exit(main())
