import 'dart:math' as math;

/// Pure color math ported from the legacy `color.js`.

double clampDouble(double value, double min, double max) =>
    math.min(max, math.max(min, value));

int clampInt(int value, int min, int max) => math.min(max, math.max(min, value));

class Hsl {
  const Hsl(this.h, this.s, this.l);

  /// Hue in degrees [0, 360), saturation and lightness in percent [0, 100].
  final double h;
  final double s;
  final double l;

  Map<String, Object?> toJson() => <String, Object?>{'h': h, 's': s, 'l': l};

  static Hsl fromJson(Map<String, Object?> json) => Hsl(
        (json['h'] as num).toDouble(),
        (json['s'] as num).toDouble(),
        (json['l'] as num).toDouble(),
      );
}

class Rgb {
  const Rgb(this.r, this.g, this.b);

  final int r;
  final int g;
  final int b;
}

String rgbToHex(num r, num g, num b) {
  String part(num x) =>
      clampDouble(x.toDouble(), 0, 255).round().toRadixString(16).padLeft(2, '0');
  return '#${part(r)}${part(g)}${part(b)}'.toUpperCase();
}

Hsl rgbToHsl(num rIn, num gIn, num bIn) {
  final double r = rIn / 255;
  final double g = gIn / 255;
  final double b = bIn / 255;
  final double max = math.max(r, math.max(g, b));
  final double min = math.min(r, math.min(g, b));
  final double l = (max + min) / 2;
  double h;
  double s;
  if (max == min) {
    h = 0;
    s = 0;
  } else {
    final double d = max - min;
    s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
    if (max == r) {
      h = (g - b) / d + (g < b ? 6 : 0);
    } else if (max == g) {
      h = (b - r) / d + 2;
    } else {
      h = (r - g) / d + 4;
    }
    h /= 6;
  }
  return Hsl(h * 360, s * 100, l * 100);
}

double _hueToRgb(double p, double q, double tIn) {
  double t = tIn;
  if (t < 0) t += 1;
  if (t > 1) t -= 1;
  if (t < 1 / 6) return p + (q - p) * 6 * t;
  if (t < 1 / 2) return q;
  if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6;
  return p;
}

Rgb hslToRgb(double h, double s, double l) {
  final double hue = (((h % 360) + 360) % 360) / 360;
  final double sat = clampDouble(s, 0, 100) / 100;
  final double light = clampDouble(l, 0, 100) / 100;

  if (sat == 0) {
    final int v = (light * 255).round();
    return Rgb(v, v, v);
  }

  final double q = light < 0.5 ? light * (1 + sat) : light + sat - light * sat;
  final double p = 2 * light - q;
  return Rgb(
    (_hueToRgb(p, q, hue + 1 / 3) * 255).round(),
    (_hueToRgb(p, q, hue) * 255).round(),
    (_hueToRgb(p, q, hue - 1 / 3) * 255).round(),
  );
}

double getLuminance(num r, num g, num b) => 0.299 * r + 0.587 * g + 0.114 * b;

/// Threshold above which dark text is used on top of a color.
const double lightLuminanceThreshold = 140;

/// Parses `#RRGGBB` into an opaque ARGB int. Returns [fallback] when malformed.
int parseHexColor(String hex, {int fallback = 0xFF000000}) {
  final String cleaned = hex.replaceFirst('#', '');
  if (cleaned.length != 6) return fallback;
  final int? value = int.tryParse(cleaned, radix: 16);
  if (value == null) return fallback;
  return 0xFF000000 | value;
}

/// Formats an ARGB int as `#RRGGBB`.
String argbToHex(int argb) =>
    '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
