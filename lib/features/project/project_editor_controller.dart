/// The single source of truth for the project being edited.
///
/// Implements the editing rules from the brief:
///  * per-photo manual motion is preserved by Auto Motion (unless unlocked +
///    regenerate was explicitly requested)
///  * locked motions are never touched by any randomize operation
///  * undo/redo covers every edit, including Auto Motion and transitions
///  * the project can always be saved and reopened
library;

import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/models/audio_settings.dart';
import '../../core/models/export_settings.dart';
import '../../core/models/keyframe.dart';
import '../../core/models/motion_path.dart';
import '../../core/models/motion_profile.dart';
import '../../core/models/motion_type.dart';
import '../../core/models/photo_item.dart';
import '../../core/models/project.dart';
import '../../core/models/transition.dart';
import '../../core/storage/project_repository.dart';
import '../../core/utils/easing.dart';
import '../motion/camera_math.dart';
import '../motion/random_motion.dart';
import '../transitions/timeline_engine.dart';

/// Immutable editing state with a bounded undo history.
class ProjectEditorState {
  const ProjectEditorState({
    required this.project,
    this.undoStack = const <Project>[],
    this.redoStack = const <Project>[],
    this.dirty = false,
    this.selectedPhotoId,
  });

  final Project project;
  final List<Project> undoStack;
  final List<Project> redoStack;
  final bool dirty;
  final String? selectedPhotoId;

  bool get canUndo => undoStack.isNotEmpty;
  bool get canRedo => redoStack.isNotEmpty;

  List<String> get photoIds =>
      project.photos.map((p) => p.id).toList(growable: false);

  List<double> get durations =>
      project.photos.map((p) => p.duration).toList(growable: false);

  List<TransitionSpec> get transitions =>
      project.photos.map((p) => p.transition).toList(growable: false);

  Viewport get viewport => Viewport(project.outputAspect);

  int indexOf(String photoId) =>
      project.photos.indexWhere((p) => p.id == photoId);

  PhotoItem? photoById(String photoId) {
    final i = indexOf(photoId);
    return i < 0 ? null : project.photos[i];
  }

  ProjectEditorState copyWith({
    Project? project,
    List<Project>? undoStack,
    List<Project>? redoStack,
    bool? dirty,
    String? selectedPhotoId,
  }) =>
      ProjectEditorState(
        project: project ?? this.project,
        undoStack: undoStack ?? this.undoStack,
        redoStack: redoStack ?? this.redoStack,
        dirty: dirty ?? this.dirty,
        selectedPhotoId: selectedPhotoId ?? this.selectedPhotoId,
      );
}

/// Maximum number of undo steps held in memory (each step is a JSON-light
/// Project object, so 50 steps stays well under a megabyte).
const int kMaxUndoSteps = 50;

class ProjectEditorController
    extends StateNotifier<ProjectEditorState?> {
  ProjectEditorController() : super(null);

  ProjectRepository? _repo;

  void attach({required Project project, required ProjectRepository repo}) {
    _repo = repo;
    state = ProjectEditorState(project: project);
  }

  void detach() {
    state = null;
    _repo = null;
  }

  // ------------------------------------------------------------------ commit
  /// Applies [next] as a new undoable state.
  void _commit(Project next, {String? selectedPhotoId}) {
    final cur = state;
    if (cur == null) return;
    final normalized = next.normalized().copyWith(
          updatedAt: DateTime.now().toUtc(),
        );
    final undo = <Project>[...cur.undoStack, cur.project];
    if (undo.length > kMaxUndoSteps) undo.removeAt(0);
    state = ProjectEditorState(
      project: normalized,
      undoStack: undo,
      redoStack: const <Project>[],
      dirty: true,
      selectedPhotoId: selectedPhotoId ?? cur.selectedPhotoId,
    );
  }

  /// Replaces a single photo by id.
  void _updatePhoto(String photoId, PhotoItem Function(PhotoItem) transform,
      {bool record = true}) {
    final cur = state;
    if (cur == null) return;
    final photos = <PhotoItem>[];
    var found = false;
    for (final p in cur.project.photos) {
      if (p.id == photoId) {
        photos.add(transform(p));
        found = true;
      } else {
        photos.add(p);
      }
    }
    if (!found) return;
    final next = cur.project.copyWith(photos: photos);
    if (record) {
      _commit(next);
    } else {
      state = cur.copyWith(project: next.normalized(), dirty: true);
    }
  }

  // ------------------------------------------------------------------ photos
  void setPhotos(List<PhotoItem> photos) {
    final cur = state;
    if (cur == null) return;
    _commit(cur.project.copyWith(photos: photos));
  }

  PhotoItem addPhoto(PhotoItem photo) {
    final cur = state;
    final placed = photo.copyWith(order: cur?.project.photos.length ?? 0);
    _commit((cur?.project ?? _emptyProject(withPhoto: placed))
        .copyWith(photos: <PhotoItem>[
      ...(cur?.project.photos ?? const <PhotoItem>[]),
      placed,
    ]));
    return placed;
  }

  void addPhotos(List<PhotoItem> photos) {
    final cur = state;
    if (cur == null || photos.isEmpty) return;
    final base = cur.project.photos.length;
    final placed = <PhotoItem>[
      for (var i = 0; i < photos.length; i++) photos[i].copyWith(order: base + i),
    ];
    _commit(cur.project.copyWith(
        photos: <PhotoItem>[...cur.project.photos, ...placed]));
  }

  void removePhoto(String photoId) {
    final cur = state;
    if (cur == null) return;
    _commit(cur.project.copyWith(
        photos: cur.project.photos
            .where((p) => p.id != photoId)
            .toList(growable: false)));
  }

  void removeAllPhotos() {
    final cur = state;
    if (cur == null) return;
    _commit(cur.project.copyWith(photos: const <PhotoItem>[]));
  }

  /// Drag & drop reorder.
  void reorderPhotos(int oldIndex, int newIndex) {
    final cur = state;
    if (cur == null) return;
    if (oldIndex < 0 || oldIndex >= cur.project.photos.length) return;
    var target = newIndex;
    if (target > oldIndex) target -= 1;
    target = target.clamp(0, cur.project.photos.length - 1);
    if (target == oldIndex) return;
    final photos = List<PhotoItem>.of(cur.project.photos);
    final moved = photos.removeAt(oldIndex);
    photos.insert(target, moved);
    _commit(cur.project.copyWith(photos: photos));
  }

  void replacePhoto(String photoId, PhotoItem replacement) {
    _updatePhoto(photoId, (old) => replacement.copyWith(
          id: old.id,
          order: old.order,
          duration: old.duration,
          motion: old.motion,
          transition: old.transition,
        ));
  }

  void rotatePhoto(String photoId) {
    _updatePhoto(photoId, (old) {
      final next = (old.rotationDegrees + 90) % 360;
      // A quarter turn swaps the intrinsic axes for rendering purposes.
      final swap = next == 90 || next == 270;
      return old.copyWith(
        rotationDegrees: next,
        width: swap ? old.height : old.width,
        height: swap ? old.width : old.height,
      );
    });
  }

  void markPhotoMissing(String photoId, bool missing) {
    _updatePhoto(photoId, (p) => p.copyWith(missing: missing), record: false);
  }

  void setPhotoDuration(String photoId, double seconds) {
    final cur = state;
    if (cur == null) return;
    final dur = seconds.clamp(AppLimits.minPhotoDuration,
        AppLimits.maxPhotoDuration);
    final vp = cur.viewport;
    _updatePhoto(photoId, (p) {
      final m = p.motion;
      if (m == null) return p.copyWith(duration: dur);
      // A path is duration-relative; only the baked keyframes need re-baking.
      final path = m.path;
      if (path != null && p.width > 0 && p.height > 0) {
        final fit = ImageFit.make(p.width, p.height, vp);
        return p.copyWith(
            duration: dur, motion: m.withPath(path, fit, vp, duration: dur));
      }
      return p.copyWith(
        duration: dur,
        motion: m.copyWith(keyframes: _retime(m.keyframes, dur)),
      );
    });
  }

  static List<Keyframe> _retime(List<Keyframe> kfs, double duration) {
    if (kfs.length < 2) return kfs;
    final oldEnd = kfs.last.time;
    if (oldEnd <= 1e-9) return kfs;
    final out = <Keyframe>[];
    for (final k in kfs) {
      final t = k.time == oldEnd ? duration : k.time / oldEnd * duration;
      out.add(k.copyWith(time: t));
    }
    out[0] = out[0].copyWith(time: 0);
    out[out.length - 1] = out.last.copyWith(time: duration);
    return out;
  }

  void selectPhoto(String? photoId) {
    final cur = state;
    if (cur == null) return;
    state = cur.copyWith(selectedPhotoId: photoId);
  }

  // ------------------------------------------------------------------ motion
  void setMotion(String photoId, MotionProfile profile, {bool record = true}) {
    _updatePhoto(photoId, (p) => p.copyWith(motion: profile), record: record);
  }

  void setMotionType(String photoId, MotionType type) {
    _updatePhoto(photoId, (p) {
      final m = p.motion;
      if (m == null) return p;
      return p.copyWith(motion: m.copyWith(motionType: type));
    });
  }

  void setMotionIntensity(String photoId, double intensity) {
    _updatePhoto(photoId, (p) {
      final m = p.motion;
      if (m == null) return p;
      return p.copyWith(motion: m.copyWith(intensity: intensity.clamp(0.0, 1.0)));
    });
  }

  void toggleLock(String photoId) {
    _updatePhoto(photoId, (p) {
      final m = p.motion;
      if (m == null) return p;
      return p.copyWith(motion: m.copyWith(isLocked: !m.isLocked));
    });
  }

  void toggleMotionTypePin(String photoId) {
    _updatePhoto(photoId, (p) {
      final m = p.motion;
      if (m == null) return p;
      return p.copyWith(
          motion: m.copyWith(isMotionTypePinned: !m.isMotionTypePinned));
    });
  }

  /// Regenerates the motion of exactly one photo (respects the lock and —
  /// unless [force] — user-drawn / user-edited paths: a plain Randomize must
  /// never silently overwrite the user's own camera path).
  void regeneratePhotoMotion(String photoId, {bool force = false}) {
    final cur = state;
    if (cur == null) return;
    final index = cur.indexOf(photoId);
    if (index < 0) return;
    final photo = cur.project.photos[index];
    final prev = index > 0 ? cur.project.photos[index - 1].motion : null;
    final profile = regenerateOne(
      photo: MotionSource(
        photoId: photo.id,
        srcWidth: photo.width,
        srcHeight: photo.height,
        duration: photo.duration,
        existing: photo.motion,
      ),
      index: index,
      viewport: cur.viewport,
      projectSeed: cur.project.seed,
      intensity: photo.motion?.intensity ?? 0.6,
      previousType: prev?.motionType,
      protectManual: !force,
      previousPathPreset: prev?.path?.preset,
    );
    setMotion(photoId, profile);
  }

  /// Replaces this photo's motion path (or clears it, back to keyframes),
  /// sanitizing against the image bounds and re-baking the keyframes.
  ///
  /// If the photo has no motion yet (the path editor can be opened straight
  /// from a fresh photo), a base profile is generated for it first — the
  /// path then rides on a normal, fully valid motion.
  void setMotionPath(String photoId, MotionPathSpec? spec,
      {bool record = true}) {
    final cur = state;
    if (cur == null) return;
    final vp = cur.viewport;
    final index = cur.indexOf(photoId);
    if (index < 0) return;
    final prevType = index > 0
        ? cur.project.photos[index - 1].motion?.motionType
        : null;
    _updatePhoto(photoId, (p) {
      if (p.width <= 0 || p.height <= 0) return p;
      final fit = ImageFit.make(p.width, p.height, vp);
      final m = p.motion ??
          generateForPhoto(
            photoId: p.id,
            srcWidth: p.width,
            srcHeight: p.height,
            duration: p.duration,
            index: index,
            projectSeed: cur.project.seed,
            viewport: vp,
            intensity: 0.6,
            previousType: prevType,
          );
      return p.copyWith(motion: m.withPath(spec, fit, vp));
    }, record: record);
  }

  /// "Auto Motion" / "Regenerate all".
  ///
  /// [regenerate] == false is the first-run Auto Motion: photos that already
  /// have motion are left alone. [regenerate] == true re-rolls every unlocked
  /// photo, which is what the "Regenerate all" button does after an explicit
  /// confirmation in the UI (manual edits are otherwise protected).
  void autoMotion({
    bool regenerate = false,
    double? intensity,
    bool protectManual = true,
  }) {
    final cur = state;
    if (cur == null) return;
    if (cur.project.photos.isEmpty) return;
    final vp = cur.viewport;
    final sources = <MotionSource>[
      for (final p in cur.project.photos)
        MotionSource(
          photoId: p.id,
          srcWidth: p.width,
          srcHeight: p.height,
          duration: p.duration,
          existing: p.motion,
        ),
    ];
    final profiles = buildProfiles(
      photos: sources,
      viewport: vp,
      projectSeed: cur.project.seed,
      intensity: intensity ?? 0.6,
      regenerate: regenerate,
      protectManual: protectManual,
    );
    final photos = <PhotoItem>[
      for (final p in cur.project.photos)
        p.motion == null || !p.motion!.isLocked
            ? p.copyWith(motion: profiles[p.id] ?? p.motion)
            : p,
    ];
    _commit(cur.project.copyWith(photos: photos));
  }

  /// New seed + reroll everything unlocked (the "Regenerate All" button).
  ///
  /// The UI warns explicitly that manual edits will be replaced, so this is
  /// the one place where user-edited / custom paths may be re-rolled
  /// ([protectManual] = false).
  void regenerateAll({double? intensity}) {
    final cur = state;
    if (cur == null) return;
    final newSeed = math.Random().nextInt(1 << 31);
    final reseeded = cur.project.copyWith(seed: newSeed);
    state = cur.copyWith(project: reseeded);
    autoMotion(regenerate: true, intensity: intensity, protectManual: false);
  }

  void resynchronizeAllMotions({double? intensity}) {
    final cur = state;
    if (cur == null) return;
    autoMotion(regenerate: true, intensity: intensity);
  }

  // -------------------------------------------------------------- transitions
  void setTransition(String photoId, TransitionSpec spec) {
    _updatePhoto(photoId, (p) => p.copyWith(transition: spec));
  }

  void applyTransitionToAll(TransitionSpec spec) {
    final cur = state;
    if (cur == null) return;
    _commit(cur.project.copyWith(
      photos: cur.project.photos
          .map((p) => p.copyWith(transition: spec))
          .toList(growable: false),
    ));
  }

  void setTransitionDurationAll(double seconds) {
    final cur = state;
    if (cur == null) return;
    final d = seconds.clamp(AppLimits.minTransition, AppLimits.maxTransition);
    _commit(cur.project.copyWith(
      photos: cur.project.photos
          .map((p) => p.copyWith(transition: p.transition.copyWith(duration: d)))
          .toList(growable: false),
    ));
  }

  /// Random transitions for every unlocked... transition (transitions are not
  /// locked, so this simply re-rolls all of them with a fresh seed).
  void randomizeTransitions({int? seed}) {
    final cur = state;
    if (cur == null) return;
    final rng = math.Random(seed ?? cur.project.seed ^ 0x5f3759df);
    const pool = <TransitionType>[
      TransitionType.crossDissolve,
      TransitionType.crossDissolve,
      TransitionType.slideLeft,
      TransitionType.slideRight,
      TransitionType.zoomTransition,
      TransitionType.smoothZoom,
      TransitionType.fade,
      TransitionType.blurTransition,
      TransitionType.fadeToBlack,
    ];
    TransitionType? prev;
    final photos = <PhotoItem>[];
    for (final p in cur.project.photos) {
      var pick = pool[rng.nextInt(pool.length)];
      if (pick == prev) {
        pick = pool[(pool.indexOf(pick) + 3) % pool.length];
      }
      prev = pick;
      photos.add(p.copyWith(transition: p.transition.copyWith(type: pick)));
    }
    _commit(cur.project.copyWith(photos: photos));
  }

  // -------------------------------------------------------------------- audio
  void setAudio(AudioSettings? audio) {
    final cur = state;
    if (cur == null) return;
    _commit(audio == null
        ? cur.project.copyWith(clearAudio: true)
        : cur.project.copyWith(audio: audio));
  }

  // ------------------------------------------------------------------- output
  void setExportSettings(ExportSettings settings) {
    final cur = state;
    if (cur == null) return;
    final oldVp = cur.viewport;
    final nextProject = cur.project.copyWith(exportSettings: settings);
    final newVp = Viewport(nextProject.outputAspect);
    if ((oldVp.aspect - newVp.aspect).abs() < 1e-6) {
      _commit(nextProject);
      return;
    }
    // Aspect changed: keep every shot's framing intent (spec §5 note).
    final sources = <MotionSource>[
      for (final p in cur.project.photos)
        MotionSource(
          photoId: p.id,
          srcWidth: p.width,
          srcHeight: p.height,
          duration: p.duration,
        ),
    ];
    final existing = <String, MotionProfile>{
      for (final p in cur.project.photos)
        if (p.motion != null) p.id: p.motion!,
    };
    final migrated = migrateAspect(
      profiles: existing,
      photos: sources,
      oldVp: oldVp,
      newVp: newVp,
    );
    _commit(nextProject.copyWith(
      photos: cur.project.photos
          .map((p) => p.motion == null
              ? p
              : p.copyWith(motion: migrated[p.id] ?? p.motion))
          .toList(growable: false),
    ));
  }

  void rename(String name) {
    final cur = state;
    if (cur == null) return;
    _commit(cur.project.copyWith(name: name.trim().isEmpty ? 'Untitled' : name.trim()));
  }

  void setSeed(int seed) {
    final cur = state;
    if (cur == null) return;
    _commit(cur.project.copyWith(seed: seed));
  }

  // -------------------------------------------------------------- undo / redo
  void undo() {
    final cur = state;
    if (cur == null || cur.undoStack.isEmpty) return;
    final prev = cur.undoStack.last;
    final undo = List<Project>.of(cur.undoStack)..removeLast();
    state = ProjectEditorState(
      project: prev,
      undoStack: undo,
      redoStack: <Project>[...cur.redoStack, cur.project],
      dirty: true,
      selectedPhotoId: cur.selectedPhotoId,
    );
  }

  void redo() {
    final cur = state;
    if (cur == null || cur.redoStack.isEmpty) return;
    final next = cur.redoStack.last;
    final redo = List<Project>.of(cur.redoStack)..removeLast();
    state = ProjectEditorState(
      project: next,
      undoStack: <Project>[...cur.undoStack, cur.project],
      redoStack: redo,
      dirty: true,
      selectedPhotoId: cur.selectedPhotoId,
    );
  }

  // -------------------------------------------------------------------- save
  Future<void> save() async {
    final cur = state;
    final repo = _repo;
    if (cur == null || repo == null) return;
    await repo.save(cur.project);
    state = cur.copyWith(dirty: false);
  }

  /// Timeline helpers used by the preview/editor.
  List<TimelineSegment> segments() {
    final cur = state;
    if (cur == null) return const <TimelineSegment>[];
    return buildSegments(cur.photoIds, cur.durations, cur.transitions);
  }

  Project _emptyProject({PhotoItem? withPhoto}) => Project(
        id: 'draft-${DateTime.now().millisecondsSinceEpoch}',
        name: 'Untitled',
        photos: <PhotoItem>[if (withPhoto != null) withPhoto],
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );
}

/// App-wide editor controller. `null` state means "no project open".
final projectEditorProvider =
    StateNotifierProvider<ProjectEditorController, ProjectEditorState?>(
  (ref) => ProjectEditorController(),
);

/// Selected photo id convenience.
final selectedPhotoIdProvider = Provider<String?>((ref) {
  return ref.watch(projectEditorProvider)?.selectedPhotoId;
});
