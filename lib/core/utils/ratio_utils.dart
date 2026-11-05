/// Small numeric/formatting helpers shared by the UI.
library;

import 'dart:math' as math;

/// Formats seconds as `m:ss` (or `h:mm:ss` for long videos).
String formatClock(double seconds) {
  final s = seconds.isFinite && seconds > 0 ? seconds.round() : 0;
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  final sec = s % 60;
  final mm = m.toString().padLeft(2, '0');
  final ss = sec.toString().padLeft(2, '0');
  return h > 0 ? '$h:$mm:$ss' : '$m:$ss';
}

/// Formats seconds as `1:05.3` for scrubbers that need sub-second precision.
String formatClockPrecise(double seconds) {
  final v = seconds.isFinite && seconds > 0 ? seconds : 0.0;
  final m = v ~/ 60;
  final s = v - m * 60;
  return '$m:${s.toStringAsFixed(1).padLeft(4, '0')}';
}

/// Human readable byte size.
String formatBytes(int bytes) {
  const units = <String>['B', 'KB', 'MB', 'GB'];
  var v = bytes.toDouble();
  var i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  return '${v.toStringAsFixed(v >= 100 || i == 0 ? 0 : 1)} ${units[i]}';
}

/// Estimated MP4 size in bytes for a known bitrate and duration.
int estimateExportBytes({
  required int videoBitrate,
  required double seconds,
  bool hasAudio = true,
  int audioBitrate = 192000,
}) =>
    ((videoBitrate + (hasAudio ? audioBitrate : 0)) * seconds / 8).round();

/// Snaps a value to a "nice" step, used by the sliders.
double snap(double value, double step) =>
    (value / step).roundToDouble() * step;

/// Safe integer percent for progress bars.
double clamp01(double v) => v.isFinite ? v.clamp(0.0, 1.0) : 0.0;

/// Aspect ratio as `16:9` style text (approximated to 2 significant digits).
String aspectLabel(double ratio) {
  const known = <String, double>{
    '9:16': 9 / 16,
    '16:9': 16 / 9,
    '1:1': 1.0,
    '4:5': 4 / 5,
    '3:4': 3 / 4,
    '4:3': 4 / 3,
    '2.39:1': 2.39,
  };
  for (final e in known.entries) {
    if ((e.value - ratio).abs() < 0.01) return e.key;
  }
  final g = _gcd((ratio * 1000).round(), 1000);
  return '${(ratio * 1000).round() ~/ g}:${1000 ~/ g}';
}

int _gcd(int a, int b) => b == 0 ? math.max(1, a) : _gcd(b, a % b);
