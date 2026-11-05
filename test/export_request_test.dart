/// The Flutter -> Kotlin contract.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:motionshot/core/constants/app_constants.dart';
import 'package:motionshot/core/models/export_settings.dart';
import 'package:motionshot/core/models/keyframe.dart';
import 'package:motionshot/core/models/motion_profile.dart';
import 'package:motionshot/core/models/photo_item.dart';
import 'package:motionshot/core/models/project.dart';
import 'package:motionshot/core/models/transition.dart';
import 'package:motionshot/core/utils/easing.dart';
import 'package:motionshot/features/export/export_request_builder.dart';

Project _project({bool withMotions = true}) => Project(
      id: 'proj-1',
      name: 'Trip',
      photos: <PhotoItem>[
        for (var i = 0; i < 3; i++)
          PhotoItem(
            id: 'ph$i',
            sourceUri: '/data/user/0/app/files/media/ph$i.jpg',
            width: 4000,
            height: 3000,
            order: i,
            duration: 4.0,
            motion: withMotions
                ? const MotionProfile(
                    keyframes: <Keyframe>[
                      Keyframe(time: 0, x: 0, y: 0, scale: 1.1),
                      Keyframe(time: 4, x: 0.1, y: -0.05, scale: 1.4,
                          rotation: 0.02),
                    ],
                  )
                : null,
            transition: const TransitionSpec(
                type: TransitionType.slideLeft, duration: 0.5),
          ),
      ],
      createdAt: DateTime.utc(2024),
      updatedAt: DateTime.utc(2024),
    );

void main() {
  test('request contains everything the renderer needs', () {
    final req = buildExportRequest(
      project: _project(),
      outputPath: '/cache/out.mp4',
      width: 1920,
      height: 1080,
      fps: 30,
      codec: 'h264',
      bitrate: 8000000,
    );
    expect(req['frameCount'], 360);
    expect(req['totalDuration'], closeTo(12.0, 1e-12));
    final photos = req['photos'] as List<dynamic>;
    expect(photos, hasLength(3));
    final first = photos.first as Map<String, dynamic>;
    expect(first['keyframes'], hasLength(2));
    expect(first['motionType'], 'zoomIn');
    // The last photo must not carry a transition.
    expect((photos.last as Map<String, dynamic>)['transition'], isNull);
    // Fit is published so Kotlin can assert agreement (4000x3000 inside 16:9 -> iw=8/9, ih=2/3).
    expect(first['expectedFitIw'], closeTo(8 / 9, 1e-12));
    expect(first['expectedFitIh'], closeTo(2 / 3, 1e-12));
    // Audio absent by default.
    expect(req['audio'], isNull);
    // Encodes to valid JSON.
    expect(jsonDecode(jsonEncode(req)), isA<Map<String, dynamic>>());
  });

  test('a project without motions is rejected with a clear reason', () {
    expect(
      () => buildExportRequest(
        project: _project(withMotions: false),
        outputPath: '/cache/out.mp4',
        width: 1920,
        height: 1080,
        fps: 30,
        codec: 'h264',
        bitrate: 8000000,
      ),
      throwsA(isA<ExportRequestException>()),
    );
    expect(preflightProblems(_project(withMotions: false)),
        contains(startsWith('motion_missing')));
  });

  test('missing photos block the export instead of producing a broken video', () {
    final p = _project();
    final broken = p.copyWith(photos: <PhotoItem>[
      p.photos[0].copyWith(missing: true),
      p.photos[1],
      p.photos[2],
    ]);
    expect(preflightProblems(broken), contains(startsWith('missing_photos')));
  });

  test('bitrate increases with resolution, fps and quality', () {
    int b(ResolutionPreset r, FpsPreset f, QualityPreset q,
            {VideoCodecPreset c = VideoCodecPreset.h264}) {
      final dims = outputDimensions(16 / 9, r.shortSide);
      return deriveBitrate(
          width: dims.width, height: dims.height, fps: f.value,
          quality: q, codec: c);
    }

    expect(b(ResolutionPreset.p1080, FpsPreset.f30, QualityPreset.maximum),
        greaterThan(b(ResolutionPreset.p1080, FpsPreset.f30, QualityPreset.high)));
    expect(b(ResolutionPreset.p1080, FpsPreset.f60, QualityPreset.high),
        greaterThan(b(ResolutionPreset.p1080, FpsPreset.f30, QualityPreset.high)));
    expect(b(ResolutionPreset.p2160, FpsPreset.f30, QualityPreset.high),
        greaterThan(b(ResolutionPreset.p1080, FpsPreset.f30, QualityPreset.high)));
    // HEVC reaches the same quality at a lower bitrate.
    expect(b(ResolutionPreset.p1080, FpsPreset.f30, QualityPreset.high,
            c: VideoCodecPreset.hevc),
        lessThan(b(ResolutionPreset.p1080, FpsPreset.f30, QualityPreset.high)));
    // Custom is honoured but clamped.
    final custom = deriveBitrate(
        width: 1920, height: 1080, fps: 30,
        quality: QualityPreset.custom, codec: VideoCodecPreset.h264,
        customBitrate: 123456789);
    expect(custom, lessThanOrEqualTo(100000000));
  });

  test('exact 1080p output is 1920x1080, portrait is 1080x1920', () {
    expect(outputDimensions(16 / 9, 1080), (width: 1920, height: 1080));
    expect(outputDimensions(9 / 16, 1080), (width: 1080, height: 1920));
    expect(outputDimensions(1.0, 1080), (width: 1080, height: 1080));
    expect(outputDimensions(4 / 5, 1080), (width: 864, height: 1080));
    final fourK = outputDimensions(16 / 9, 2160);
    expect(fourK.width, 3840);
    expect(fourK.height, 2160);
  });

  test('original aspect follows the first photo but stays in video range', () {
    expect(effectiveAspect(AspectPreset.original, 3 / 4), closeTo(3 / 4, 1e-12));
    expect(effectiveAspect(AspectPreset.original, 0.1), closeTo(9 / 16, 1e-12));
    expect(effectiveAspect(AspectPreset.original, 10.0), closeTo(16 / 9, 1e-12));
    expect(effectiveAspect(AspectPreset.r1x1, 0.1), 1.0);
  });

  test('export settings survive a preferences round-trip', () {
    const s = ExportSettings(
      resolution: ResolutionPreset.p1440,
      fps: FpsPreset.f60,
      codec: VideoCodecPreset.hevc,
      quality: QualityPreset.maximum,
      aspect: AspectPreset.r9x16,
      customBitrate: 42000000,
    );
    final back = exportSettingsFromPreferences(s.encode());
    expect(back.toJson().toString(), s.toJson().toString());
  });

  test('estimated size is in the right ballpark', () {
    final bytes = estimateOutputBytes(
        bitrate: 10000000, durationSeconds: 60, hasAudio: true);
    // 10 Mbps + 192 kbps for 60s = ~76 MB
    expect(bytes / 1e6, closeTo(76.4, 0.5));
  });

  test('photo rotation swaps intrinsic axes for the next render', () {
    final p = _project();
    final rotated = p.photos[0].copyWith(width: 3000, height: 4000);
    final next = p.copyWith(photos: <PhotoItem>[rotated, p.photos[1], p.photos[2]]);
    final req = buildExportRequest(
      project: next,
      outputPath: '/cache/x.mp4',
      width: 1080,
      height: 1920,
      fps: 30,
      codec: 'h264',
      bitrate: 6000000,
    );
    final first = (req['photos'] as List<dynamic>).first as Map<String, dynamic>;
    expect(first['width'], 3000);
    expect(first['height'], 4000);
  });

  test('custom easing curve is serialised', () {
    final p = Project(
      id: 'x',
      name: 'y',
      photos: const <PhotoItem>[
        PhotoItem(
          id: 'a',
          sourceUri: '/a.jpg',
          width: 100,
          height: 100,
          motion: MotionProfile(
            keyframes: <Keyframe>[
              Keyframe(time: 0, x: 0, y: 0, scale: 1,
                  easing: Easing.custom, curve: <double>[0.2, 0.0, 0.1, 1.0]),
              Keyframe(time: 3, x: 0, y: 0, scale: 1.2),
            ],
          ),
        ),
      ],
      createdAt: _epoch,
      updatedAt: _epoch,
    );
    final req = buildExportRequest(
      project: p,
      outputPath: '/cache/x.mp4',
      width: 720,
      height: 720,
      fps: 24,
      codec: 'h264',
      bitrate: 1500000,
    );
    final kf = (((req['photos'] as List<dynamic>).first
            as Map<String, dynamic>)['keyframes'] as List<dynamic>).first
        as Map<String, dynamic>;
    expect(kf['easing'], 'custom');
    expect(kf['curve'], <double>[0.2, 0.0, 0.1, 1.0]);
  });
}

final DateTime _epoch = DateTime.utc(2024);
