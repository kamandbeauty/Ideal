# Phase 2 — Flutter App (UI, State, Project Model)

Status: **PASS for source completeness and mathematical/contract parity; BLOCKED for SDK compilation & widget execution** (no Flutter/Dart SDK or `pub.dev` access in this sandbox).

## Scope Delivered

47 Dart source files (`lib/`) + 4 unit/conformance test suites (`test/`), zero code generation, zero `TODO`/`FIXME`/`UnimplementedError`, zero empty button handlers.

| Area | Files | Highlights |
| --- | --- | --- |
| Bootstrap | `lib/main.dart` | Opens app documents/cache directories, initializes SQLite + preferences, locks supported orientations, renders an explicit error screen on bootstrap failure |
| Theme | `lib/app/theme/app_theme.dart` | Dark cinematic Material 3 palette (light optional), Vazirmatn typography across Persian and English, responsive tablet/phone layout |
| Localization | `lib/app/l10n/strings.dart` | **266 keys** in both Persian (`fa`, RTL default) and English (`en`, LTR), 100% key parity + 100% call-site coverage verified by `portcheck` |
| Routing & State | `lib/app/router.dart`, `providers.dart`, `project_editor_controller.dart`, `settings_controller.dart` | GoRouter (9 destinations), Riverpod `StateNotifier` with 50-step undo/redo history, motion clipboard, aspect-change motion migration |
| Screens | Home, Gallery, Editor, Motion Editor, Preview, Export, Export Progress, Settings, Audio Sheet | Multi-photo import via Android Photo Picker, pinch/drag keyframe authoring, custom cubic-bezier curve editor, capability-aware export preflight |
| Preview | `lib/features/preview/*` | Shares exact camera/timeline math with the native exporter (`previewMatrix` proven numerically equivalent to `inv(layer_affine) ∘ uv→src` to `2.8e-16`) |
| Persistence | `lib/core/storage/project_repository.dart`, `app_settings_store.dart` | SQLite index + JSON project document, autosave/dirty tracking, JSON export/import |
| Native Bridge | `lib/features/platform/native_video_bridge/video_bridge.dart` | `motionshot/render`, `motionshot/render/progress`, `motionshot/media` |

## Defects Found & Fixed During Static/Numeric Verification

1. **`List.sort` comparator return type (`motion_profile.dart`, `keyframe_ops.dart`)** — `..sort((a, b) => a.time - b.time)` returned `double` instead of `int` (a compile-time error in Dart). Fixed to `a.time.compareTo(b.time)` and guarded in `portcheck.py`.
2. **`ExportProgress` terminal result & error propagation (`video_bridge.dart`, `export_manager.dart`)** — `ExportProgress` was missing `this.result`, `errorCode`, `errorMessage`, and `cancelled` in its constructor, which would both fail compilation and swallow native error codes (`ENCODER_FAILED`, `OUT_OF_MEMORY`, `CANCELLED`, etc.) on terminal `done` events. Fixed end-to-end.
3. **Bitrate truncation vs rounding (`app_constants.dart`)** — `b.round()` differed by 1 bit/s from `MOTION_SPEC.md` §8.2 on 13/108 golden combinations; fixed to `b.toInt()` (108/108 exact).
4. **Unsigned 64-bit `rangeInt` modulo (`random.dart`)** — Signed `%` on negative two's-complement 64-bit draws disagreed with unsigned `next_u64() % n` whenever `n` was not a power of two. Fixed via `BigInt.from(nextU64()).toUnsigned(64).remainder(BigInt.from(n)).toInt()`.
5. **Golden JSON 64-bit signed representation (`prng.json`, `profiles.json`)** — 20-digit unsigned integers `>= 2^63` would throw `FormatException` in `dart:convert.jsonDecode`. Switched JSON serialization to two's-complement signed 64-bit integers (`to_signed64`) and mirrored all 8 golden fixtures into `test/golden/`.
6. **Test suite fixes (`test/export_request_test.dart`, `test/golden_vectors_test.dart`)** — Fixed non-const `DateTime` inside `const Project(...)`, corrected `expectedFitIw` assertion (`8/9` for 4000×3000 in 16:9, matching `camera.json`), and added full 108-row bitrate + `roundEven` golden conformance tests.
7. **SDK & dependency alignment (`pubspec.yaml`)** — Declared `image_picker: ^1.1.2`, aligned SDK constraint to Flutter `>=3.27.0` / Dart `>=3.6.0` (matching `Color.withValues`, `CardThemeData`, `DialogThemeData`), and set `intl: any` to avoid `flutter_localizations` version pin conflicts.
8. **Missing validation l10n keys (`strings.dart`)** — Added `motion_need_two_keyframes`, `motion_bad_scale`, `motion_kf_too_close`, and `motion_first_kf` in both `en` and `fa`.

## Blocked in This Environment

- `flutter pub get`, `flutter analyze`, `flutter test` (no Dart/Flutter SDK installed; `pub.dev` unreachable).
- Visual/gesture/RTL rendering checks on a physical Android device or emulator.
