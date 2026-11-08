import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/time_us.dart';
import '../../models/video_asset.dart';
import '../../services/project_repository.dart';
import '../theme/app_colors.dart';

/// A real frame from the project's video, with its duration in the corner.
///
/// The frame arrives asynchronously from MediaMetadataRetriever; until then (and
/// if the file is no longer reachable) a tinted placeholder is drawn, so a
/// project list never flashes empty grey boxes or throws.
class ProjectThumbnail extends ConsumerWidget {
  const ProjectThumbnail({
    required this.projectId,
    this.width = 96,
    this.height = 62,
    this.radius = 10,
    this.showDuration = true,
    this.timeMs = 1000,
    super.key,
  });

  final String projectId;
  final double width;
  final double height;
  final double radius;
  final bool showDuration;
  final int timeMs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<ProjectDetail> detail = ref.watch(projectDetailProvider(projectId));
    final VideoAsset? asset = detail.valueOrNull?.asset;
    final int durationUs = asset?.durationUs ?? 0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            const _Placeholder(),
            if (asset != null)
              _Frame(
                uri: asset.uri,
                timeMs: timeMs,
                width: width,
              ),
            if (showDuration && durationUs > 0)
              Positioned(
                left: 5,
                bottom: 5,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.62),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    TimeUs.compact(durationUs),
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Frame extends ConsumerWidget {
  const _Frame({required this.uri, required this.timeMs, required this.width});

  final String uri;
  final int timeMs;
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<String?>(
      future: ref.read(mediaServiceProvider).thumbnailFor(
            uri,
            timeMs: timeMs,
            width: (width * 3).clamp(160, 960).round(),
          ),
      builder: (BuildContext context, AsyncSnapshot<String?> snapshot) {
        final String? path = snapshot.data;
        if (path == null) return const SizedBox.shrink();
        return Image.file(
          File(path),
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        );
      },
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            AppColors.surfaceHigher,
            AppColors.primary.withOpacity(0.22),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(Icons.movie_creation_outlined, size: 20, color: AppColors.textMuted),
      ),
    );
  }
}
