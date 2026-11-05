/// The fifteen motion types required by the product brief (§5).
///
/// The ordering and ids are part of the persisted JSON contract and must match
/// `MOTION_TYPES` in tools/validate/motionshot/profile.py and
/// android/.../motion/MotionTypes.kt.
enum MotionType {
  zoomIn('zoomIn'),
  zoomOut('zoomOut'),
  panLeft('panLeft'),
  panRight('panRight'),
  panUp('panUp'),
  panDown('panDown'),
  diagonalLeft('diagonalLeft'),
  diagonalRight('diagonalRight'),
  slowPush('slowPush'),
  pullBack('pullBack'),
  zoomPan('zoomPan'),
  subtleRotation('subtleRotation'),
  drift('drift'),
  centerToCorner('centerToCorner'),
  combined('combined');

  const MotionType(this.id);
  final String id;

  String get labelKey => 'motion_$id';

  bool get isDirectional => const <MotionType>{
        MotionType.panLeft,
        MotionType.panRight,
        MotionType.panUp,
        MotionType.panDown,
        MotionType.diagonalLeft,
        MotionType.diagonalRight,
        MotionType.zoomPan,
        MotionType.centerToCorner,
      }.contains(this);

  bool get usesRotation => const <MotionType>{
        MotionType.subtleRotation,
        MotionType.drift,
        MotionType.combined,
      }.contains(this);

  bool get isMultiKeyframe => const <MotionType>{
        MotionType.drift,
        MotionType.combined,
      }.contains(this);

  static MotionType parse(String? id) => MotionType.values.firstWhere(
        (e) => e.id == id,
        orElse: () => MotionType.zoomIn,
      );

  /// Relative likelihood during auto-generation (spec §10).
  double get generationWeight {
    switch (this) {
      case MotionType.zoomIn:
        return 1.4;
      case MotionType.zoomOut:
        return 1.2;
      case MotionType.panLeft:
      case MotionType.panRight:
        return 1.0;
      case MotionType.panUp:
      case MotionType.panDown:
        return 0.9;
      case MotionType.diagonalLeft:
      case MotionType.diagonalRight:
        return 0.8;
      case MotionType.slowPush:
        return 1.1;
      case MotionType.pullBack:
        return 1.0;
      case MotionType.zoomPan:
        return 1.2;
      case MotionType.subtleRotation:
        return 0.45;
      case MotionType.drift:
        return 0.5;
      case MotionType.centerToCorner:
        return 0.8;
      case MotionType.combined:
        return 1.0;
    }
  }
}
