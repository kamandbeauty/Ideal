/// Behavioural tests for the editing rules in the brief.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:motionshot/core/models/keyframe.dart';
import 'package:motionshot/core/models/motion_profile.dart';
import 'package:motionshot/core/models/motion_type.dart';
import 'package:motionshot/core/models/photo_item.dart';
import 'package:motionshot/core/models/project.dart';
import 'package:motionshot/core/models/transition.dart';
import 'package:motionshot/core/utils/easing.dart';
import 'package:motionshot/features/motion/camera_math.dart';
import 'package:motionshot/features/motion/random_motion.dart';
import 'package:motionshot/features/project/project_editor_controller.dart';
import 'package:motionshot/core/storage/project_repository.dart';

PhotoItem _photo(String id, {int order = 0, MotionProfile? motion}) =>
    PhotoItem(
      id: id,
      sourceUri: '/nonexistent/$id.jpg',
      width: 4000,
      height: 3000,
      order: order,
      motion: motion,
    );

Project _project(int n) => Project(
      id: 'p1',
      name: 'Test',
      photos: <PhotoItem>[
        for (var i = 0; i < n; i++) _photo('ph$i', order: i),
      ],
      createdAt: DateTime.utc(2024),
      updatedAt: DateTime.utc(2024),
    );

/// Minimal in-memory repository double: the controller only needs `save`.
class _FakeRepo implements ProjectRepository {
  final List<Project> saved = <Project>[];

  @override
  Future<void> save(Project project) async => saved.add(project);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

void main() {
  late ProjectEditorController c;
  late _FakeRepo repo;

  setUp(() {
    c = ProjectEditorController();
    repo = _FakeRepo();
    c.attach(project: _project(3), repo: repo);
  });

  tearDown(() => c.detach());

  test('auto motion gives every photo a legal profile', () {
    c.autoMotion();
    final st = c.state!;
    expect(st.project.hasAllMotions, isTrue);
    for (final p in st.project.photos) {
      expect(p.motion!.keyframes.length, greaterThanOrEqualTo(2));
      final fit = ImageFit.make(p.width, p.height, st.viewport);
      for (final k in p.motion!.keyframes) {
        expect(k.scale, greaterThan(1.0));
        expect(k.time, inInclusiveRange(0, p.duration + 1e-9));
        expect(minScaleAtRotation(fit, st.viewport, k.rotation),
            lessThanOrEqualTo(k.scale + 1e-9));
      }
    }
  });

  test('regenerate all keeps locked photos and re-rolls the rest', () {
    c.autoMotion();
    c.toggleLock('ph0');
    final lockedBefore = c.state!.photoById('ph0')!.motion!.toJson().toString();
    final otherBefore = c.state!.photoById('ph1')!.motion!.toJson().toString();

    c.regenerateAll();

    final lockedAfter = c.state!.photoById('ph0')!.motion!.toJson().toString();
    final otherAfter = c.state!.photoById('ph1')!.motion!.toJson().toString();
    expect(lockedAfter, lockedBefore, reason: 'locked motion must not change');
    expect(otherAfter, isNot(otherBefore), reason: 'unlocked must re-roll');
  });

  test('auto motion does not destroy manual edits on first run', () {
    // Simulate a user-authored motion on photo 1.
    final manual = MotionProfile(
      keyframes: const <Keyframe>[
        Keyframe(time: 0, x: 0.1, y: 0.05, scale: 1.2, easing: Easing.linear),
        Keyframe(time: 5, x: -0.1, y: -0.05, scale: 1.5, easing: Easing.linear),
      ],
      motionType: MotionType.drift,
    );
    c.setMotion('ph1', manual);
    c.autoMotion(); // regenerate: false
    expect(c.state!.photoById('ph1')!.motion!.motionType, MotionType.drift);
    expect(c.state!.photoById('ph1')!.motion!.keyframes.first.x, 0.1);
    expect(c.state!.photoById('ph0')!.motion, isNotNull);
  });

  test('regenerate single photo changes only that photo', () {
    c.autoMotion();
    final before = {
      for (final p in c.state!.project.photos) p.id: p.motion!.toJson().toString()
    };
    c.regeneratePhotoMotion('ph1');
    final after = {
      for (final p in c.state!.project.photos) p.id: p.motion!.toJson().toString()
    };
    expect(after['ph1'], isNot(before['ph1']));
    expect(after['ph0'], before['ph0']);
    expect(after['ph2'], before['ph2']);
  });

  test('regenerate respects the lock on a single photo', () {
    c.autoMotion();
    c.toggleLock('ph1');
    final before = c.state!.photoById('ph1')!.motion!.toJson().toString();
    c.regeneratePhotoMotion('ph1');
    expect(c.state!.photoById('ph1')!.motion!.toJson().toString(), before);
  });

  test('undo and redo walk the whole history', () {
    expect(c.state!.canUndo, isFalse);
    c.autoMotion();
    final one = c.state!.project.photos.first.motion!.toJson().toString();
    c.regenerateAll();
    final two = c.state!.project.photos.first.motion!.toJson().toString();
    expect(two, isNot(one));
    c.undo();
    expect(c.state!.project.photos.first.motion!.toJson().toString(), one);
    c.redo();
    expect(c.state!.project.photos.first.motion!.toJson().toString(), two);
    // undo past the beginning is a no-op, not an error
    while (c.state!.canUndo) {
      c.undo();
    }
    c.undo();
    expect(c.state!.canUndo, isFalse);
  });

  test('reordering updates the order field', () {
    c.autoMotion();
    c.reorderPhotos(0, 3); // move first to the end
    final order = c.state!.project.photos.map((p) => p.id).toList();
    expect(order, <String>['ph1', 'ph2', 'ph0']);
    expect(c.state!.project.photos.map((p) => p.order).toList(), <int>[0, 1, 2]);
  });

  test('changing a duration retimes the motion but keeps the framing', () {
    c.autoMotion();
    final before = c.state!.photoById('ph0')!.motion!;
    c.setPhotoDuration('ph0', 8.0);
    final after = c.state!.photoById('ph0')!.motion!;
    expect(after.keyframes.first.time, 0);
    expect(after.keyframes.last.time, 8.0);
    expect(after.keyframes.first.x, closeTo(before.keyframes.first.x, 1e-12));
    expect(after.keyframes.last.scale,
        closeTo(before.keyframes.last.scale, 1e-12));
  });

  test('applying a transition to all affects every photo', () {
    c.autoMotion();
    c.applyTransitionToAll(
        const TransitionSpec(type: TransitionType.zoomTransition, duration: 0.9));
    for (final p in c.state!.project.photos) {
      expect(p.transition.type, TransitionType.zoomTransition);
      expect(p.transition.duration, 0.9);
    }
  });

  test('random transitions never repeat the same type twice in a row', () {
    c.autoMotion();
    c.randomizeTransitions(seed: 4);
    final types = c.state!.project.photos.map((p) => p.transition.type).toList();
    for (var i = 1; i < types.length; i++) {
      expect(types[i], isNot(types[i - 1]));
    }
  });

  test('switching aspect migrates motions and keeps them legal', () {
    c.autoMotion();
    final st = c.state!;
    c.setExportSettings(st.project.exportSettings.copyWith(
        aspect: AspectPreset.r9x16));
    final after = c.state!;
    expect(after.viewport.aspect, closeTo(9 / 16, 1e-9));
    for (final p in after.project.photos) {
      final fit = ImageFit.make(p.width, p.height, after.viewport);
      for (final k in p.motion!.keyframes) {
        expect(k.scale,
            greaterThanOrEqualTo(
                minScaleAtRotation(fit, after.viewport, k.rotation) - 1e-9));
        final e = halfExtent(after.viewport, k.scale, k.rotation);
        expect(e.bw, lessThanOrEqualTo(fit.iw + 1e-9));
        expect(e.bh, lessThanOrEqualTo(fit.ih + 1e-9));
      }
    }
  });

  test('save writes through to the repository and clears the dirty flag', () async {
    c.autoMotion();
    expect(c.state!.dirty, isTrue);
    await c.save();
    expect(repo.saved, hasLength(1));
    expect(c.state!.dirty, isFalse);
  });

  test('project round-trips through JSON without loss', () {
    c.autoMotion();
    c.setAudio(null);
    final p = c.state!.project;
    final clone = Project.fromJson(p.toJson());
    expect(clone.photos.length, p.photos.length);
    expect(clone.totalDuration, closeTo(p.totalDuration, 1e-12));
    expect(clone.photos[0].motion!.toJson().toString(),
        p.photos[0].motion!.toJson().toString());
    expect(clone.seed, p.seed);
  });

  test('removing a photo keeps the rest contiguous', () {
    c.autoMotion();
    c.removePhoto('ph1');
    expect(c.state!.project.photos.map((p) => p.id).toList(),
        <String>['ph0', 'ph2']);
    expect(c.state!.project.photos.map((p) => p.order).toList(), <int>[0, 1]);
  });
}
