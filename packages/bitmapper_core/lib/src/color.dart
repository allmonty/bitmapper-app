import 'dart:typed_data';

/// Colors packed as `0xRRGGBB` ints, and brightness: the helpers every
/// stage (and the app) shares, so the bit layout and the luma formula live
/// in exactly one place.

/// Pack a color as `0xRRGGBB`.
int packRgb(int r, int g, int b) => (r << 16) | (g << 8) | b;

/// The packed color at byte offset `i` of a flat RGB (or RGBA, with the
/// matching offset) buffer.
int packedAt(List<int> bytes, int i) => packRgb(bytes[i], bytes[i + 1], bytes[i + 2]);

int redOf(int packed) => (packed >> 16) & 0xFF;
int greenOf(int packed) => (packed >> 8) & 0xFF;
int blueOf(int packed) => packed & 0xFF;

/// `[r, g, b]` of a packed color.
List<int> unpackRgb(int packed) => [redOf(packed), greenOf(packed), blueOf(packed)];

/// A flat RGB palette (`K * 3` bytes) from packed colors.
Uint8List paletteFromPacked(List<int> packed) {
  final out = Uint8List(packed.length * 3);
  for (var i = 0; i < packed.length; i++) {
    out.setAll(i * 3, unpackRgb(packed[i]));
  }
  return out;
}

/// Every pixel of a flat buffer as a packed color, in order. `stride` is 3
/// for RGB, 4 for RGBA.
List<int> packedColors(List<int> bytes, {int stride = 3}) => [
  for (var i = 0; i + 2 < bytes.length; i += stride) packedAt(bytes, i),
];

/// The distinct colors of a flat buffer, packed. `stride` is 3 for RGB, 4
/// for RGBA.
Set<int> colorSet(List<int> bytes, {int stride = 3}) => {
  for (var i = 0; i + 2 < bytes.length; i += stride) packedAt(bytes, i),
};

/// Rec. 601 luma as `(r * 0.299 + g * 0.587) + b * 0.114`, in the same
/// operation order as the Python reference so results match exactly.
double luminance(num r, num g, num b) => r * 0.299 + g * 0.587 + b * 0.114;
