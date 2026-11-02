import 'dart:typed_data';

import '../models/swatch.dart';
import 'color_utils.dart';

/// Posterize setting that keeps every gray instead of reducing to bands.
const int fullTonalRange = 0;

const List<int> posterizeLevelOptions = <int>[fullTonalRange, 3, 4, 5];

/// Snaps [lightness] to the midpoint of one of [levels] even L* bands.
double posterizeLightness(double lightness, int levels) {
  if (levels == fullTonalRange) return lightness;
  final int band = (lightness / 100 * levels).floor().clamp(0, levels - 1);
  return (band + 0.5) / levels * 100;
}

/// The neutral gray that [swatch] shows as in a value study.
Swatch valueSwatch(Swatch swatch, int levels) {
  final int gray = grayForLightness(posterizeLightness(swatch.lightness, levels));
  return Swatch.fromRgb(gray, gray, gray, count: swatch.count);
}

/// Input for [renderValueStudy] (a single sendable object for `compute`).
class ValueStudyRequest {
  const ValueStudyRequest(this.rgba, this.levels);

  /// Premultiplied RGBA pixels.
  final Uint8List rgba;
  final int levels;
}

/// Steps in the luminance-to-gray table; fine enough to be invisible in shadows.
const int _grayTableSize = 4096;

/// Maps a premultiplied RGBA buffer to opaque grays of equal L*, reduced to
/// `levels` bands when posterizing. Transparency is flattened onto white.
Uint8List renderValueStudy(ValueStudyRequest req) {
  // Indexed by channel + (255 - alpha), which rounding can push just past 255.
  final Float64List linear = Float64List(511);
  for (int v = 0; v < linear.length; v++) {
    linear[v] = srgbToLinear(clampInt(v, 0, 255) / 255);
  }
  final Uint8List grayTable = Uint8List(_grayTableSize);
  for (int i = 0; i < _grayTableSize; i++) {
    final double lightness = lightnessFromRelativeLuminance(i / (_grayTableSize - 1));
    grayTable[i] = grayForLightness(posterizeLightness(lightness, req.levels));
  }

  final Uint8List rgba = req.rgba;
  final Uint8List out = Uint8List(rgba.length);
  for (int i = 0; i + 3 < rgba.length; i += 4) {
    final int white = 255 - rgba[i + 3];
    final double y = 0.2126 * linear[rgba[i] + white] +
        0.7152 * linear[rgba[i + 1] + white] +
        0.0722 * linear[rgba[i + 2] + white];
    final int gray = grayTable[(y * (_grayTableSize - 1)).round()];
    out[i] = gray;
    out[i + 1] = gray;
    out[i + 2] = gray;
    out[i + 3] = 255;
  }
  return out;
}
