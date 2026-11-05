/// Deterministic PRNG — Dart port of docs/MOTION_SPEC.md §10.
///
/// Bit-exact with `tools/validate/motionshot/mathx.py` and
/// `android/.../motion/RandomMotion.kt` (golden: golden/prng.json).
library;

/// 64-bit arithmetic helper. Dart ints are 64-bit two's complement on native
/// platforms, so masking to 64 bits gives us unsigned wraparound for free.
const int _mask64 = 0xFFFFFFFFFFFFFFFF;

int _wrap(int v) => v & _mask64;

/// FNV-1a over the UTF-8 bytes of [text].
int fnv1a64(String text) {
  var h = 0xCBF29CE484222325;
  for (final b in _utf8Bytes(text)) {
    h = _wrap(h ^ b);
    h = _wrap(h * 0x100000001B3);
  }
  return h;
}

/// UTF-8 encoding matching the reference implementation byte for byte.
List<int> _utf8Bytes(String text) {
  final out = <int>[];
  for (final rune in text.runes) {
    if (rune < 0x80) {
      out.add(rune);
    } else if (rune < 0x800) {
      out.add(0xC0 | (rune >> 6));
      out.add(0x80 | (rune & 0x3F));
    } else if (rune < 0x10000) {
      out.add(0xE0 | (rune >> 12));
      out.add(0x80 | ((rune >> 6) & 0x3F));
      out.add(0x80 | (rune & 0x3F));
    } else {
      out.add(0xF0 | (rune >> 18));
      out.add(0x80 | ((rune >> 12) & 0x3F));
      out.add(0x80 | ((rune >> 6) & 0x3F));
      out.add(0x80 | (rune & 0x3F));
    }
  }
  return out;
}

/// SplitMix64 step. Returns (state, value).
(int, int) splitMix64(int state) {
  state = _wrap(state + 0x9E3779B97F4A7C15);
  var z = state;
  z = _wrap((z ^ (z >>> 30)) * 0xBF58476D1CE4E5B9);
  z = _wrap((z ^ (z >>> 27)) * 0x94D049BB133111EB);
  return (state, _wrap(z ^ (z >>> 31)));
}

/// xorshift128+ generator.
class Xorshift128Plus {
  Xorshift128Plus(int seed)
      : _s0 = 0,
        _s1 = 0 {
    var state = _wrap(seed);
    final r1 = splitMix64(state);
    state = r1.$1;
    var v0 = r1.$2;
    final r2 = splitMix64(state);
    var v1 = r2.$2;
    if (v0 == 0 && v1 == 0) v0 = 0x9E3779B97F4A7C15;
    _s0 = v0;
    _s1 = v1;
  }

  int _s0;
  int _s1;

  /// Raw 64-bit output. Typed as unsigned-ish int using `>>>` semantics.
  int nextU64() {
    var s1 = _s0;
    final s0 = _s1;
    _s0 = s0;
    s1 = _wrap(s1 ^ _wrap(s1 << 23));
    s1 = s1 ^ (s1 >>> 17);
    s1 = s1 ^ s0;
    s1 = s1 ^ (s0 >>> 26);
    _s1 = _wrap(s1);
    return _wrap(_s0 + _s1);
  }

  /// Uniform double in [0,1) using the top 53 bits.
  double nextDouble() =>
      ((nextU64() & _mask64) >>> 11) * (1.0 / 9007199254740992.0);

  double range(double lo, double hi) => lo + (hi - lo) * nextDouble();

  int rangeInt(int lo, int hiInclusive) {
    final n = hiInclusive - lo + 1;
    final rem = BigInt.from(nextU64())
        .toUnsigned(64)
        .remainder(BigInt.from(n))
        .toInt();
    return lo + rem;
  }

  bool chance([double p = 0.5]) => nextDouble() < p;

  /// +1 or -1, drawn the same way as the reference (`next_u64() & 1`).
  int sign() => (nextU64() & 1) == 1 ? 1 : -1;
}

/// Per-photo seed derivation (spec §10).
int photoSeed(int projectSeed, String photoId, int index) =>
    _wrap(_wrap(projectSeed) ^
        fnv1a64(photoId) ^
        _wrap((index + 1) * 0x9E3779B97F4A7C15));
