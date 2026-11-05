import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/constants.dart';
import '../features/subtitles/subtitle_document.dart';
import '../models/subtitle.dart';
import '../core/platform/native_bridge.dart';

/// Result of a subtitle-only export. The brief's "mode 1" deliverable: the
/// original video is *not* touched at all, only a text file is produced.
class ExportedSubtitle {
  const ExportedSubtitle({
    required this.path,
    required this.format,
    required this.bytes,
    required this.segmentCount,
  });

  final String path;

  /// `srt`, `ass` or `txt`.
  final String format;
  final int bytes;
  final int segmentCount;

  String get fileName => p.basename(path);
}

/// Writes subtitle files on-device. SRT and ASS text comes from the native C++
/// codec (the same writer the host tests verify for Persian text and CJK-safe
/// line breaks); TXT is a plain transcript and is built here.
class SubtitleExportService {
  SubtitleExportService({
    required NativeBridge bridge,
    Future<Directory> Function()? directory,
  })  : _bridge = bridge,
        _directory = directory ?? getApplicationDocumentsDirectory;

  final NativeBridge _bridge;
  final Future<Directory> Function() _directory;

  Future<ExportedSubtitle> exportSrt(SubtitleDocument document, {String? baseName}) async {
    if (document.isEmpty) {
      throw const SubtitleExportException('زیرنویسی برای خروجی وجود ندارد.');
    }
    final String content = await _bridge.writeSrt(document.segments);
    return _write(content, 'srt', document, baseName);
  }

  Future<ExportedSubtitle> exportAss(
    SubtitleDocument document, {
    required int videoWidth,
    required int videoHeight,
    required String fontName,
    required double fontSize,
    required int primaryColor,
    required int outlineColor,
    required double outlineWidth,
    required double shadowDepth,
    required bool bold,
    required int alignment,
    String? baseName,
  }) async {
    if (document.isEmpty) {
      throw const SubtitleExportException('زیرنویسی برای خروجی وجود ندارد.');
    }
    final String content = await _bridge.writeAss(
      segments: document.segments,
      videoWidth: videoWidth,
      videoHeight: videoHeight,
      fontName: fontName,
      fontSize: fontSize,
      primaryColor: primaryColor,
      outlineColor: outlineColor,
      outlineWidth: outlineWidth,
      shadowDepth: shadowDepth,
      bold: bold,
      alignment: alignment,
    );
    return _write(content, 'ass', document, baseName);
  }

  /// Plain transcript, one caption per line. Deliberately timestamp-free: a file
  /// that claims to be a subtitle file but has no timing would be a trap.
  Future<ExportedSubtitle> exportTxt(SubtitleDocument document, {String? baseName}) async {
    if (document.isEmpty) {
      throw const SubtitleExportException('زیرنویسی برای خروجی وجود ندارد.');
    }
    final StringBuffer buffer = StringBuffer();
    for (final SubtitleSegment segment in document.segments) {
      final String line = segment.text.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (line.isNotEmpty) buffer.writeln(line);
    }
    return _write(buffer.toString(), 'txt', document, baseName);
  }

  Future<ExportedSubtitle> _write(
    String content,
    String format,
    SubtitleDocument document,
    String? baseName,
  ) async {
    final Directory root = await _directory();
    final Directory target = Directory(p.join(root.path, SubFlowInfo.exportsDirName));
    if (!await target.exists()) {
      await target.create(recursive: true);
    }
    final String stamp = _timestamp(DateTime.now());
    final String name = '${baseName ?? 'subflow'}-${document.trackId.hashCode.toRadixString(16)}-$stamp.$format';
    final File file = File(p.join(target.path, name));
    // UTF-8 with a BOM-free body: SRT/ASS readers expect UTF-8 and a BOM breaks
    // some legacy players, while every modern one handles plain UTF-8.
    await file.writeAsString(content, flush: true);
    final int bytes = await file.length();
    return ExportedSubtitle(
      path: file.path,
      format: format,
      bytes: bytes,
      segmentCount: document.length,
    );
  }

  static String _timestamp(DateTime now) {

    String two(int value) => value.toString().padLeft(2, '0');
    return '${now.year}${two(now.month)}${two(now.day)}-'
        '${two(now.hour)}${two(now.minute)}${two(now.second)}';
  }
}

class SubtitleExportException implements Exception {
  const SubtitleExportException(this.message);

  final String message;

  @override
  String toString() => message;
}
