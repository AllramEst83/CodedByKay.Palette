import 'dart:math' as math;
import 'dart:typed_data';

import '../models/swatch.dart';

/// k-means color clustering ported from the legacy `kmeans.js`.
///
/// [rgb] is a flat `[r, g, b, r, g, b, ...]` buffer so it transfers cheaply
/// to an isolate. Pass a seeded [random] for deterministic results in tests.
List<Swatch> runKMeans(
  Uint8List rgb,
  int k, {
  int maxIterations = 10,
  math.Random? random,
}) {
  final math.Random rng = random ?? math.Random();
  final int n = rgb.length ~/ 3;
  if (n == 0) return <Swatch>[];
  if (n <= k) {
    return List<Swatch>.generate(
      n,
      (int i) => Swatch.fromRgb(rgb[i * 3], rgb[i * 3 + 1], rgb[i * 3 + 2]),
    );
  }

  // Centroids as flat doubles [r, g, b] * k.
  final Float64List centroids = Float64List(k * 3);
  void setCentroid(int j, int pixelIndex) {
    centroids[j * 3] = rgb[pixelIndex * 3].toDouble();
    centroids[j * 3 + 1] = rgb[pixelIndex * 3 + 1].toDouble();
    centroids[j * 3 + 2] = rgb[pixelIndex * 3 + 2].toDouble();
  }

  double distSq(int pixelIndex, int j) {
    final double dr = rgb[pixelIndex * 3] - centroids[j * 3];
    final double dg = rgb[pixelIndex * 3 + 1] - centroids[j * 3 + 1];
    final double db = rgb[pixelIndex * 3 + 2] - centroids[j * 3 + 2];
    return dr * dr + dg * dg + db * db;
  }

  // k-means++ seeding.
  setCentroid(0, rng.nextInt(n));
  final Float64List distances = Float64List(n);
  for (int seeded = 1; seeded < k; seeded++) {
    double total = 0;
    for (int i = 0; i < n; i++) {
      double minD = double.infinity;
      for (int j = 0; j < seeded; j++) {
        final double d = distSq(i, j);
        if (d < minD) minD = d;
      }
      distances[i] = minD;
      total += minD;
    }
    double target = rng.nextDouble() * total;
    int chosen = 0;
    for (int i = 0; i < n; i++) {
      target -= distances[i];
      if (target <= 0) {
        chosen = i;
        break;
      }
    }
    setCentroid(seeded, chosen);
  }

  final Float64List sums = Float64List(k * 3);
  final List<int> counts = List<int>.filled(k, 0);

  for (int iter = 0; iter < maxIterations; iter++) {
    sums.fillRange(0, sums.length, 0);
    counts.fillRange(0, k, 0);

    for (int i = 0; i < n; i++) {
      int best = 0;
      double bestD = double.infinity;
      for (int j = 0; j < k; j++) {
        final double d = distSq(i, j);
        if (d < bestD) {
          bestD = d;
          best = j;
        }
      }
      counts[best]++;
      sums[best * 3] += rgb[i * 3];
      sums[best * 3 + 1] += rgb[i * 3 + 1];
      sums[best * 3 + 2] += rgb[i * 3 + 2];
    }

    double maxMovement = 0;
    for (int j = 0; j < k; j++) {
      final int c = counts[j];
      if (c == 0) continue;
      final double nr = sums[j * 3] / c;
      final double ng = sums[j * 3 + 1] / c;
      final double nb = sums[j * 3 + 2] / c;
      final double movement = (centroids[j * 3] - nr).abs() +
          (centroids[j * 3 + 1] - ng).abs() +
          (centroids[j * 3 + 2] - nb).abs();
      if (movement > maxMovement) maxMovement = movement;
      centroids[j * 3] = nr;
      centroids[j * 3 + 1] = ng;
      centroids[j * 3 + 2] = nb;
    }

    if (maxMovement < 1.0) break;
  }

  return List<Swatch>.generate(k, (int j) {
    return Swatch.fromRgb(
      centroids[j * 3].round(),
      centroids[j * 3 + 1].round(),
      centroids[j * 3 + 2].round(),
      count: counts[j],
    );
  });
}

enum SortMode { prominence, luminance, hue }

SortMode sortModeFromName(String? name) => SortMode.values.firstWhere(
      (SortMode m) => m.name == name,
      orElse: () => SortMode.prominence,
    );

List<Swatch> sortPalette(List<Swatch> colors, SortMode mode) {
  final List<Swatch> copy = List<Swatch>.of(colors);
  switch (mode) {
    case SortMode.prominence:
      copy.sort((Swatch a, Swatch b) => b.count.compareTo(a.count));
    case SortMode.luminance:
      copy.sort((Swatch a, Swatch b) => a.luminance.compareTo(b.luminance));
    case SortMode.hue:
      copy.sort((Swatch a, Swatch b) => a.hsl.h.compareTo(b.hsl.h));
  }
  return copy;
}

/// Extracts a palette from a flat RGBA buffer (alpha > 128 pixels only).
List<Swatch> extractPaletteFromRgba(
  Uint8List rgba,
  int k, {
  SortMode sortMode = SortMode.prominence,
  int maxIterations = 8,
  math.Random? random,
}) {
  final Uint8List rgb = Uint8List(rgba.length ~/ 4 * 3);
  int o = 0;
  for (int i = 0; i + 3 < rgba.length; i += 4) {
    if (rgba[i + 3] > 128) {
      rgb[o++] = rgba[i];
      rgb[o++] = rgba[i + 1];
      rgb[o++] = rgba[i + 2];
    }
  }
  final List<Swatch> palette = runKMeans(
    Uint8List.sublistView(rgb, 0, o),
    k,
    maxIterations: maxIterations,
    random: random,
  );
  return sortPalette(palette, sortMode);
}

/// Input for [extractInIsolate] (a single sendable object for `compute`).
class ExtractRequest {
  const ExtractRequest(this.rgba, this.k, this.sortMode);

  final Uint8List rgba;
  final int k;
  final SortMode sortMode;
}

List<Swatch> extractInIsolate(ExtractRequest req) =>
    extractPaletteFromRgba(req.rgba, req.k, sortMode: req.sortMode);
