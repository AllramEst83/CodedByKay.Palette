import '../core/color_utils.dart';

/// A single extracted/derived color, mirroring the legacy swatch objects.
class Swatch {
  const Swatch({
    required this.r,
    required this.g,
    required this.b,
    required this.hex,
    required this.hsl,
    required this.luminance,
    required this.count,
  });

  factory Swatch.fromRgb(int r, int g, int b, {int count = 1}) => Swatch(
        r: r,
        g: g,
        b: b,
        hex: rgbToHex(r, g, b),
        hsl: rgbToHsl(r, g, b),
        luminance: getLuminance(r, g, b),
        count: count,
      );

  factory Swatch.fromJson(Map<String, Object?> json) {
    final int r = (json['r'] as num).toInt();
    final int g = (json['g'] as num).toInt();
    final int b = (json['b'] as num).toInt();
    final Object? hsl = json['hsl'];
    return Swatch(
      r: r,
      g: g,
      b: b,
      hex: (json['hex'] as String?) ?? rgbToHex(r, g, b),
      hsl: hsl is Map<String, Object?> ? Hsl.fromJson(hsl) : rgbToHsl(r, g, b),
      luminance: (json['luminance'] as num?)?.toDouble() ?? getLuminance(r, g, b),
      count: (json['count'] as num?)?.toInt() ?? 1,
    );
  }

  final int r;
  final int g;
  final int b;
  final String hex;
  final Hsl hsl;
  final double luminance;
  final int count;

  bool get isLight => luminance > lightLuminanceThreshold;

  int get argb => 0xFF000000 | (r << 16) | (g << 8) | b;

  String get rgbLabel => '$r, $g, $b';

  Map<String, Object?> toJson() => <String, Object?>{
        'r': r,
        'g': g,
        'b': b,
        'hex': hex,
        'hsl': hsl.toJson(),
        'luminance': luminance,
        'count': count,
      };
}
