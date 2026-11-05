# SubFlow — Phase 2 report (Subtitle Studio)

This phase turns the caption engine from Phase 1.5 into a working editing surface:
real caption documents, real editing rules, real persistence, real word-level
preview, and a subtitle-only export that never touches the video.

The honest limitation up front: **speech recognition is not in this phase.** There
is no "detect" button and no progress bar anywhere, because no Whisper model is
wired yet. What shipped is the studio those transcripts will land in.

---

## 1. Files created

| File | Lines | Purpose |
|---|---|---|
| `lib/features/subtitles/subtitle_document.dart` | 430 | immutable, validated caption document + every edit operation |
| `lib/features/subtitles/subtitle_editor_model.dart` | 205 | bounded undo/redo history, selection, style clipboard |
| `lib/features/subtitles/subtitle_studio_screen.dart` | 780 | the studio UI: player + karaoke overlay, segment list, sheet editor, export |
| `lib/database/dao/subtitle_dao.dart` | 165 | atomic segment/word persistence, project style rows |
| `lib/features/effects/preset_style_mapper.dart` | 90 | gallery look → stored `SubtitleStyle` (ASS units) |
| `lib/services/subtitle_export_service.dart` | 155 | SRT / ASS / TXT files on device |
| `test/subtitle_document_test.dart` | 330 | 25 tests for the editing rules, history and mapping |

## 2. Files changed

| File | Change |
|---|---|
| `lib/app/providers.dart` | `subtitleDaoProvider`, `subtitleExportServiceProvider`, `SubtitleEditorNotifier` (family AsyncNotifier with debounced autosave) |
| `lib/app/router.dart` | `/project/:id/subtitles` |
| `lib/features/editor/editor_screen.dart` | entry card into the studio |
| `pubspec.yaml` | version `0.2.0+2` |
| `tools/check-project.py` | 778 assertions (studio wiring, DAO surface, document operations) |
| `README.md` | Phase 2 in the SubFlow banner |

## 3. Capabilities implemented

* **Document model with enforced invariants.** Every mutation returns a document
  that is sorted, non-overlapping, clamped to `t ≥ 0`, and where every caption is
  at least 120 ms long. Captions cannot silently corrupt each other, which is the
  failure mode that ruins a subtitle project.
* **Editing**: add at playhead, split at playhead (word-aware, refuses to create
  unreadable fragments), merge with next, delete with confirmation, retime with
  neighbour clamping, shift the whole track by ±ms (for sync drift), multi-line
  text, per-caption style assignment, style copy/paste (single caption or all).
* **Word timings**: every text edit redistributes word timings proportional to
  word length — including Persian ZWNJ (نیم‌فاصله), «»|؟|، punctuation, and mixed
  fa/en lines. That is what makes the karaoke overlay follow real words instead of
  guessing.
* **Undo/redo**: bounded (120 steps) history over immutable documents, cleared
  redo stack on new edits, selection repair after deletion, single-step style
  changes and single-step sheet edits (a whole manual edit is one undo, not one
  per keystroke).
* **Persistence**: the whole track is replaced inside one SQLite transaction, so a
  crash mid-autosave can never leave half a document. Autosave is debounced by
  700 ms and flushed before export and on dispose.
* **Preview**: the caption overlay is driven by the real Media3 playhead — the
  segment under the playhead is painted with the selected gallery preset, and the
  active word (plus per-word fill fraction for karaoke) comes from
  `subtitle_words`. Preview and export still share one style model.
* **Export (mode 1 of the brief)**: SRT (native codec), ASS (native codec with the
  same font/colour/stroke/alignment numbers the preview uses), TXT (plain
  transcript). The original video is never opened for writing; a file is written
  to the app's `exports` directory and the exact path/size is shown to the user.
* **Honesty in the UI**: the empty state says the manual path is what exists today
  and that Whisper arrives next; the TXT option says it has no timings.

## 4. Tests run

Local: `bash tools/verify-all.sh` → **ALL CHECKS PASSED**
(C++ host 124 checks, ASan/UBSan clean, JNI syntax OK, schema 43 assertions,
project checker 778 assertions).

CI (`subflow-android.yml`, run `42094849675`): `flutter analyze` **0 errors**,
`flutter test` **64 test cases in 6 files — all passing**, `flutter build apk
--release` **success**, artefact assertions (arm64 native core + Flutter engine)
**success**.

The new test file covers: normalisation (sorting, overlap push-apart, minimum
duration, negative starts), half-open lookups, word lookup fallbacks, retiming
clamps against neighbours, word redistribution, ZWNJ/punctuation preservation,
split/merge/insert/remove/shift semantics, undo/redo (path, redo clearing,
bounded history, no-op rejection, selection repair), style copy/paste, and the
preset→style mapping (alignment, short-edge font size, RTL).

Three CI failures during this phase were **test bugs, not product bugs** — lookups
fed millisecond values into a microsecond timeline, and two fixtures set text that
was already there (a documented no-op, so no words were built). Both are fixed and
the failures are recorded here rather than quietly rewritten.

## 5. Test results (what is actually proven)

* Editing rules hold under the tested cases: 25 tests exercise them directly, and
  the same rules are what the UI calls — there is no second implementation.
* The document the UI shows is the document that is saved: `SubtitleEditorNotifier`
  state is always the model's snapshot, and the DAO writes that snapshot.
* The app builds and the APK contains the native core; the new code compiles on
  Dart 3.5 / Flutter 3.24.5.
* **Not verified**: on-device text input with a Persian IME, real karaoke timing
  against a real recording (there is no transcription yet, so word timings are
  derived from text length), file-system behaviour of the exports directory on a
  real device, and performance of the overlay during playback. These are listed as
  risks, not claims.

## 6. Remaining errors and risks

* No functional errors are known in the shipped paths: analyzer is clean, the full
  test suite passes and the release build succeeds.
* **Word timings without ASR are estimates.** They are proportional to word
  length, which is honest and documented, but they are not speech-aligned. Real
  alignment needs Whisper timestamps (Phase 3) — the schema and the renderer are
  already built for it.
* Per-caption style is stored as a reference; the *project* style is persisted when
  a gallery look is chosen. There is no style editor UI yet (the gallery is the
  only way to choose a look), so `subtitle_styles` currently holds one row per
  project.
* The studio edits the original track only; translation tracks exist in the schema
  but have no UI (Phase 4).
* Export writes to app-private storage; sharing/SAF export is a later phase, and
  the file is *not* offered as "saved to Downloads" because it is not.
* `flutter analyze` output is treated as diagnostic in CI (it is published as
  annotations but does not gate the build); a compile error still fails the build
  step, so this cannot hide a broken artefact.

## 7. Next phase

**Phase 3 — offline speech recognition (whisper.cpp via JNI)**: vendor the runtime,
compile it through the existing CMake target behind `SF_ENABLE_WHISPER`, add the
model manager (Tiny/Base/Small, size + free-space + ABI checks, default selection,
explicit user-initiated download), audio extraction, progress and cancel that
report real numbers, fa/en/mixed language selection, and word-level timestamps
written into `subtitle_words`. The studio, the karaoke renderer and the SRT/ASS
writers are already waiting for exactly that data.

---

## 8. Hotfix 0.2.1 — startup crash on a real device (user-reported)

**Reported**: installing 0.2.0 on an Android phone showed
`DatabaseException(unknown error (code 0 SQLITE_OK): Queries can be performed
using SQLiteDatabase query or rawQuery methods only.) [] sql 'PRAGMA
journal_mode = WAL'` instead of the app.

**Cause**: `AppDatabase` opened SQLite with
`db.execute('PRAGMA journal_mode = WAL')` in `onConfigure`. sqflite's `execute()`
only accepts statements that return no rows; `PRAGMA journal_mode` returns the
resulting mode, so the very first statement of the very first launch threw. Every
`.sql` migration file also carries `PRAGMA` lines that were executed the same way,
so fixing only the first one would have moved the crash a few lines down.

**Fix** (three parts, all in `lib/database/app_database.dart`):
1. pragmas run through `rawQuery`, which is what sqflite requires for rows;
2. each pragma is applied independently and a refusal is *logged*, never thrown —
   a device that dislikes `synchronous = NORMAL` must not make the app unopenable;
3. statements in migration files that start with `PRAGMA` are routed to
   `rawQuery` as well, so both files keep working unchanged.

**Related hardening**: `SubtitleDao.replaceSegments` / `clearSegments` now delete
`subtitle_words` explicitly instead of relying on `ON DELETE CASCADE`. `PRAGMA
foreign_keys` is a no-op inside a transaction, so a device that never enables it
would otherwise leave word rows orphaned after every autosave.

**Why it was not caught**: nothing in the test suite ever *opened* the database.
The schema was verified by a Python harness against real SQLite, and the Dart side
was only analysed (types) and built (compiles). 0.2.1 adds
`test/database_open_test.dart`, which opens the real schema through
`sqflite_common_ffi` on the CI runner and asserts: the open path does not throw,
migrations reach the manifest version, `foreign_keys=1`, `journal_mode=wal`, all
tables exist, re-opening does not re-migrate, and the subtitle DAO round-trips
segments/words/styles including cascade deletion.

**Also changed**: the splash failure screen is now selectable text with a
"تلاش دوباره" (retry) button, so a startup problem is reportable instead of a dead
end, and version bumped to `0.2.1+3`.

**Status**: verified by CI. Run `42104634583` (commit `30885cf`): analyzer clean,
**76 Dart tests green** (the 12 new database cases included), release APK built;
run `42105891541` (tag `subflow-v0.2.1`) republished the release. The download tag
now carries only `subflow-0.2.1-release.apk` + `.sha256` (43,999,796 B); the broken
0.2.0 assets were deleted. Not yet verified on the reporting device;
that is the user's install, not something this workspace can claim.
