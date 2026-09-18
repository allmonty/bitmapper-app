/// xorshift128+ seeded through splitmix64: a tiny, portable PRNG so
/// `random` dither is deterministic for a given seed (migration doc §6.4a).
///
/// Uses 64-bit integer arithmetic, so it runs on the Dart VM / AOT (all the
/// app's targets), not on the web.
class XorShift128Plus {
  XorShift128Plus(int seed) {
    var sm = seed;
    int next() {
      sm = sm + 0x9E3779B97F4A7C15;
      var z = sm;
      z = (z ^ (z >>> 30)) * 0xBF58476D1CE4E5B9;
      z = (z ^ (z >>> 27)) * 0x94D049BB133111EB;
      return z ^ (z >>> 31);
    }

    _s0 = next();
    _s1 = next();
    if (_s0 == 0 && _s1 == 0) _s1 = 1;
  }

  late int _s0;
  late int _s1;

  /// Next raw 64-bit value.
  int nextInt64() {
    var s1 = _s0;
    final s0 = _s1;
    final result = s0 + s1;
    _s0 = s0;
    s1 ^= s1 << 23;
    _s1 = s1 ^ s0 ^ (s1 >>> 17) ^ (s0 >>> 26);
    return result;
  }

  /// Uniform double in [0, 1) from the top 53 bits.
  double nextDouble() => (nextInt64() >>> 11) * (1.0 / 9007199254740992.0);
}
