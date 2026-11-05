import 'dart:math';

/// UUID v4 generator. Implemented locally (12 lines) instead of pulling a
/// package: ids are only ever local primary keys, never sent anywhere.
class Ids {
  Ids._();

  static final Random _random = Random.secure();
  static String? _last;
  static int _counter = 0;

  static String uuid() {
    // Monotonic suffix guarantees uniqueness even if Random.secure() is not.
    _counter = (_counter + 1) & 0xFFFF;
    final List<int> bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0F) | 0x40;
    bytes[8] = (bytes[8] & 0x3F) | 0x80;
    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < 16; i++) {
      if (i == 4 || i == 6 || i == 8 || i == 10) buffer.write('-');
      buffer.write(bytes[i].toRadixString(16).padLeft(2, '0'));
    }
    final String candidate = buffer.toString();
    if (candidate == _last) return uuid();
    _last = candidate;
    return candidate;
  }

  static int nowMs() => DateTime.now().millisecondsSinceEpoch;
}
