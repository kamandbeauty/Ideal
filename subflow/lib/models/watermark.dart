/// Image or text overlay. Multiple watermarks per project are supported and
/// each one has its own time window and fade, so a logo can appear for 3 s and
/// a handle for the whole video.
class Watermark {
  const Watermark({
    required this.id,
    required this.projectId,
    required this.kind,
    required this.payload,
    required this.createdAtMs,
    required this.updatedAtMs,
    this.fontFamily = 'Vazirmatn',
    this.fontSize = 48,
    this.color = 0xFFFFFF,
    this.opacity = 1,
    this.scale = 1,
    this.rotation = 0,
    this.positionX = 0.9,
    this.positionY = 0.08,
    this.anchor = 'center',
    this.startUs = 0,
    this.endUs,
    this.fadeInUs = 0,
    this.fadeOutUs = 0,
    this.zIndex = 0,
  });

  final String id;
  final String projectId;

  /// `image` payload is a file path to PNG/JPG; `text` payload is the string.
  final String kind;
  final String payload;
  final String fontFamily;
  final double fontSize;
  final int color;
  final double opacity;
  final double scale;
  final double rotation;
  final double positionX;
  final double positionY;
  final String anchor;
  final int startUs;
  final int? endUs;
  final int fadeInUs;
  final int fadeOutUs;
  final int zIndex;
  final int createdAtMs;
  final int updatedAtMs;

  bool get isImage => kind == 'image';

  /// Opacity at a given timeline position, honouring fade in/out.
  double opacityAt(int timeUs) {
    if (timeUs < startUs) return 0;
    final int end = endUs ?? 1 << 62;
    if (timeUs > end) return 0;
    double value = opacity;
    if (fadeInUs > 0 && timeUs < startUs + fadeInUs) {
      value *= (timeUs - startUs) / fadeInUs;
    }
    if (fadeOutUs > 0 && timeUs > end - fadeOutUs) {
      value *= (end - timeUs) / fadeOutUs;
    }
    return value.clamp(0.0, 1.0).toDouble();
  }

  factory Watermark.fromMap(Map<String, Object?> map) => Watermark(
        id: map['id']! as String,
        projectId: map['project_id']! as String,
        kind: map['kind']! as String,
        payload: map['payload']! as String,
        fontFamily: (map['font_family'] as String?) ?? 'Vazirmatn',
        fontSize: ((map['font_size'] as num?) ?? 48).toDouble(),
        color: (map['color'] as int?) ?? 0xFFFFFF,
        opacity: ((map['opacity'] as num?) ?? 1).toDouble(),
        scale: ((map['scale'] as num?) ?? 1).toDouble(),
        rotation: ((map['rotation'] as num?) ?? 0).toDouble(),
        positionX: ((map['position_x'] as num?) ?? 0.9).toDouble(),
        positionY: ((map['position_y'] as num?) ?? 0.08).toDouble(),
        anchor: (map['anchor'] as String?) ?? 'center',
        startUs: (map['start_us'] as int?) ?? 0,
        endUs: map['end_us'] as int?,
        fadeInUs: (map['fade_in_us'] as int?) ?? 0,
        fadeOutUs: (map['fade_out_us'] as int?) ?? 0,
        zIndex: (map['z_index'] as int?) ?? 0,
        createdAtMs: map['created_at_ms']! as int,
        updatedAtMs: map['updated_at_ms']! as int,
      );

  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        'project_id': projectId,
        'kind': kind,
        'payload': payload,
        'font_family': fontFamily,
        'font_size': fontSize,
        'color': color,
        'opacity': opacity,
        'scale': scale,
        'rotation': rotation,
        'position_x': positionX,
        'position_y': positionY,
        'anchor': anchor,
        'start_us': startUs,
        'end_us': endUs,
        'fade_in_us': fadeInUs,
        'fade_out_us': fadeOutUs,
        'z_index': zIndex,
        'created_at_ms': createdAtMs,
        'updated_at_ms': updatedAtMs,
      };
}
