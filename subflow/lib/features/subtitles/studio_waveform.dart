import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../shared/theme/app_colors.dart';

/// One waveform request, value-comparable so the family caches per video.
@immutable
class WaveformRequest {
  const WaveformRequest({required this.uri, required this.durationUs, this.buckets = 72});

  final String uri;
  final int durationUs;
  final int buckets;

  @override
  bool operator ==(Object other) =>
      other is WaveformRequest &&
      other.uri == uri &&
      other.durationUs == durationUs &&
      other.buckets == buckets;

  @override
  int get hashCode => Object.hash(uri, durationUs, buckets);
}

final FutureProviderFamily<List<int>, WaveformRequest> waveformProvider =
    FutureProvider.family<List<int>, WaveformRequest>((Ref ref, WaveformRequest request) {
  return ref.watch(mediaServiceProvider).waveformFor(request.uri, buckets: request.buckets);
});

/// The film strip under the caption blocks: six frames from the video, side by
/// side, which is what makes a timeline read as a timeline.
class Filmstrip extends ConsumerWidget {
  const Filmstrip({
    required this.uri,
    required this.durationUs,
    this.frames = 6,
    super.key,
  });

  final String uri;
  final int durationUs;
  final int frames;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: <Widget>[
        for (int i = 0; i < frames; i++)
          Expanded(
            child: _Frame(
              uri: uri,
              timeMs: durationUs <= 0
                  ? i * 1000
                  : ((durationUs / 1000) * (i / frames)).round(),
            ),
          ),
      ],
    );
  }
}

class _Frame extends ConsumerWidget {
  const _Frame({required this.uri, required this.timeMs});

  final String uri;
  final int timeMs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0.5),
      child: FutureBuilder<String?>(
        future: ref.read(mediaServiceProvider).thumbnailFor(uri, timeMs: timeMs, width: 220),
        builder: (BuildContext context, AsyncSnapshot<String?> snapshot) {
          final String? path = snapshot.data;
          if (path == null) {
            return const ColoredBox(color: AppColors.surfaceHigher);
          }
          return Image.file(
            File(path),
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => const ColoredBox(color: AppColors.surfaceHigher),
          );
        },
      ),
    );
  }
}
