import '../models/swatch.dart';
import 'color_utils.dart';

/// Palette themes and color harmonies ported from the legacy `palette-theme.js`.

typedef _HslAdjust = Hsl Function(Hsl hsl);

final Map<String, _HslAdjust> _themes = <String, _HslAdjust>{
  'pastel': (Hsl c) =>
      Hsl(c.h, clampDouble(c.s * 0.5, 20, 45), clampDouble(c.l * 0.4 + 60, 70, 92)),
  'neon': (Hsl c) =>
      Hsl(c.h, clampDouble(c.s * 1.4 + 20, 85, 100), clampDouble(c.l, 45, 60)),
  'muted': (Hsl c) => Hsl(c.h, clampDouble(c.s * 0.35, 8, 30), c.l),
  'vivid': (Hsl c) =>
      Hsl(c.h, clampDouble(c.s * 1.25, 70, 100), clampDouble(c.l, 40, 65)),
  // JS clamp(hsl.s * 1.1, hsl.s, 90) = min(90, max(hsl.s, hsl.s * 1.1)).
  'dark': (Hsl c) =>
      Hsl(c.h, clampDouble(c.s * 1.1, c.s, 90), clampDouble(c.l * 0.45, 8, 35)),
};

List<String> get themeNames => _themes.keys.toList(growable: false);

Swatch _swatchFromRgb(Rgb rgb, int count) =>
    Swatch.fromRgb(rgb.r, rgb.g, rgb.b, count: count);

List<Swatch> applyTheme(List<Swatch> colors, String themeName) {
  final _HslAdjust? adjust = _themes[themeName];
  if (adjust == null) return colors;
  return colors.map((Swatch color) {
    final Hsl next = adjust(rgbToHsl(color.r, color.g, color.b));
    return _swatchFromRgb(hslToRgb(next.h, next.s, next.l), color.count);
  }).toList();
}

const Map<String, List<double>> _harmonyOffsets = <String, List<double>>{
  'complementary': <double>[0, 180],
  'analogous': <double>[-30, -15, 0, 15, 30],
  'triadic': <double>[0, 120, 240],
  'tetradic': <double>[0, 90, 180, 270],
};

List<String> get harmonyNames => _harmonyOffsets.keys.toList(growable: false);

List<Swatch> applyHarmony(
  List<Swatch> colors,
  int baseIndex,
  String schemeName,
  int count,
) {
  final List<double>? offsets = _harmonyOffsets[schemeName];
  if (offsets == null || colors.isEmpty) return colors;

  final Swatch base = colors[clampInt(baseIndex, 0, colors.length - 1)];
  final Hsl baseHsl = rgbToHsl(base.r, base.g, base.b);
  final int targetCount = count == 0 ? colors.length : count;

  final List<Swatch> swatches = offsets
      .map((double offset) => _swatchFromRgb(
            hslToRgb(baseHsl.h + offset, baseHsl.s, baseHsl.l),
            base.count,
          ))
      .toList();

  int padIndex = 0;
  while (swatches.length < targetCount) {
    final double sourceOffset = offsets[padIndex % offsets.length];
    final double shift = (padIndex ~/ offsets.length) % 2 == 0 ? 15 : -15;
    final double l = clampDouble(baseHsl.l + shift, 10, 90);
    swatches.add(
      _swatchFromRgb(hslToRgb(baseHsl.h + sourceOffset, baseHsl.s, l), base.count),
    );
    padIndex++;
  }

  return swatches.sublist(0, targetCount);
}
