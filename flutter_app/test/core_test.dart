import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:palette_app/core/color_utils.dart';
import 'package:palette_app/core/dynamic_layout.dart';
import 'package:palette_app/core/grid_layout.dart';
import 'package:palette_app/core/kmeans.dart';
import 'package:palette_app/core/palette_theme.dart';
import 'package:palette_app/models/swatch.dart';

Uint8List _pixels(List<List<int>> list) =>
    Uint8List.fromList(list.expand((List<int> p) => p).toList());

void main() {
  group('color utils', () {
    test('rgbToHex pads, clamps and uppercases', () {
      expect(rgbToHex(255, 0, 10), '#FF000A');
      expect(rgbToHex(300, -5, 15.6), '#FF0010');
    });

    test('rgbToHsl known values', () {
      final Hsl red = rgbToHsl(255, 0, 0);
      expect((red.h, red.s, red.l), (0.0, 100.0, 50.0));
      final Hsl gray = rgbToHsl(128, 128, 128);
      expect(gray.s, 0);
      final Hsl green = rgbToHsl(0, 255, 0);
      expect(green.h, closeTo(120, 1e-9));
      final Hsl blue = rgbToHsl(0, 0, 255);
      expect(blue.h, closeTo(240, 1e-9));
    });

    test('hsl <-> rgb round trip within rounding', () {
      for (final List<int> c in <List<int>>[
        <int>[12, 200, 90],
        <int>[250, 3, 77],
        <int>[0, 0, 0],
        <int>[255, 255, 255],
        <int>[99, 100, 101],
      ]) {
        final Hsl hsl = rgbToHsl(c[0], c[1], c[2]);
        final Rgb back = hslToRgb(hsl.h, hsl.s, hsl.l);
        expect((back.r - c[0]).abs() <= 1, isTrue, reason: '$c r');
        expect((back.g - c[1]).abs() <= 1, isTrue, reason: '$c g');
        expect((back.b - c[2]).abs() <= 1, isTrue, reason: '$c b');
      }
    });

    test('hslToRgb wraps hue and handles negatives', () {
      final Rgb a = hslToRgb(-120, 100, 50);
      final Rgb b = hslToRgb(240, 100, 50);
      expect((a.r, a.g, a.b), (b.r, b.g, b.b));
    });

    test('luminance and hex parsing', () {
      expect(getLuminance(255, 255, 255), closeTo(255, 1e-9));
      expect(parseHexColor('#FF8000'), 0xFFFF8000);
      expect(parseHexColor('nope', fallback: 1), 1);
      expect(argbToHex(0xFFFF8000), '#FF8000');
    });
  });

  group('k-means', () {
    test('returns every pixel when there are at most k', () {
      final List<Swatch> out = runKMeans(_pixels(<List<int>>[<int>[1, 2, 3], <int>[4, 5, 6]]), 5);
      expect(out, hasLength(2));
      expect(out.first.hex, '#010203');
    });

    test('empty input returns empty', () {
      expect(runKMeans(Uint8List(0), 3), isEmpty);
    });

    test('separates distinct color blobs deterministically', () {
      final List<List<int>> px = <List<int>>[
        for (int i = 0; i < 60; i++) <int>[250, 10 + i % 3, 10],
        for (int i = 0; i < 30; i++) <int>[10, 250, 10 + i % 3],
        for (int i = 0; i < 10; i++) <int>[10, 10, 250],
      ];
      final List<Swatch> out =
          runKMeans(_pixels(px), 3, random: math.Random(42));
      final List<Swatch> sorted = sortPalette(out, SortMode.prominence);
      expect(sorted.map((Swatch s) => s.count), <int>[60, 30, 10]);
      expect(sorted[0].r, greaterThan(240));
      expect(sorted[1].g, greaterThan(240));
      expect(sorted[2].b, greaterThan(240));
    });

    test('sort modes', () {
      final List<Swatch> colors = <Swatch>[
        Swatch.fromRgb(0, 0, 255, count: 1),
        Swatch.fromRgb(255, 0, 0, count: 5),
        Swatch.fromRgb(0, 255, 0, count: 3),
      ];
      expect(sortPalette(colors, SortMode.prominence).map((Swatch s) => s.hex),
          <String>['#FF0000', '#00FF00', '#0000FF']);
      expect(sortPalette(colors, SortMode.luminance).first.hex, '#0000FF');
      expect(sortPalette(colors, SortMode.hue).map((Swatch s) => s.hex),
          <String>['#FF0000', '#00FF00', '#0000FF']);
    });

    test('extractPaletteFromRgba skips transparent pixels', () {
      final Uint8List rgba = Uint8List.fromList(<int>[
        255, 0, 0, 255, //
        0, 255, 0, 10, // transparent, dropped
        255, 0, 0, 255,
      ]);
      final List<Swatch> out = extractPaletteFromRgba(rgba, 2);
      expect(out, hasLength(2));
      expect(out.every((Swatch s) => s.hex == '#FF0000'), isTrue);
    });
  });

  group('themes & harmonies', () {
    final List<Swatch> base = <Swatch>[
      Swatch.fromRgb(200, 60, 40, count: 7),
      Swatch.fromRgb(30, 90, 200, count: 3),
    ];

    test('every theme keeps count and adjusts saturation/lightness bounds', () {
      for (final String name in themeNames) {
        final List<Swatch> out = applyTheme(base, name);
        expect(out, hasLength(2), reason: name);
        expect(out.map((Swatch s) => s.count), <int>[7, 3]);
      }
      final Swatch pastel = applyTheme(base, 'pastel').first;
      expect(pastel.hsl.l, inInclusiveRange(69, 93));
      final Swatch dark = applyTheme(base, 'dark').first;
      expect(dark.hsl.l, inInclusiveRange(7, 36));
      expect(applyTheme(base, 'unknown'), same(base));
    });

    test('harmony offsets and padding', () {
      final List<Swatch> comp = applyHarmony(base, 0, 'complementary', 2);
      expect(comp, hasLength(2));
      final double h0 = comp[0].hsl.h;
      final double h1 = comp[1].hsl.h;
      expect(((h1 - h0 + 360) % 360 - 180).abs(), lessThan(3));

      final List<Swatch> padded = applyHarmony(base, 0, 'triadic', 5);
      expect(padded, hasLength(5));
      expect(applyHarmony(base, 0, 'tetradic', 2), hasLength(2));
      expect(applyHarmony(base, 99, 'analogous', 5), hasLength(5));
      expect(harmonyNames, <String>['complementary', 'analogous', 'triadic', 'tetradic']);
    });
  });

  group('grid layout', () {
    const List<GridCell> cells = <GridCell>[
      GridCell(id: 'a', aspect: 2),
      GridCell(id: 'b', aspect: 0.5),
      GridCell(id: 'c', aspect: 1),
      GridCell(id: 'd', aspect: 1),
    ];

    test('cell width math', () {
      expect(gridCellWidth(cols: 3, gutter: 16, padding: 24), closeTo((1920 - 48 - 32) / 3, 1e-9));
    });

    for (final (String ratio, double mult) in <(String, double)>[
      ('1:1', 1),
      ('4:3', 3 / 4),
      ('3:4', 4 / 3),
      ('16:9', 9 / 16),
    ]) {
      test('fixed ratio $ratio', () {
        final GridLayoutResult r = layoutGridCells(
          cells: cells,
          cols: 2,
          cellWidth: 100,
          gutter: 10,
          padding: 20,
          ratio: ratio,
        );
        expect(r.cells[0].h, closeTo(100 * mult, 1e-9));
        expect(r.cells[1].x, 130);
        expect(r.cells[2].y, closeTo(20 + 100 * mult + 10, 1e-9));
        expect(r.canvasHeight, closeTo(40 + 2 * 100 * mult + 10, 1e-9));
      });
    }

    test('original ratio masonry uses shortest column', () {
      final GridLayoutResult r = layoutGridCells(
        cells: cells,
        cols: 2,
        cellWidth: 100,
        gutter: 10,
        padding: 20,
        ratio: 'original',
      );
      expect(r.cells[0].h, 50); // aspect 2
      expect(r.cells[1].h, 200); // aspect 0.5
      // c goes to column 0 (height 60 < 210), then d to column 0 again (170 < 210).
      expect(r.cells[2].x, 20);
      expect(r.cells[2].y, 20 + 60);
      expect(r.cells[3].x, 20);
      expect(r.cells[3].y, 20 + 60 + 110);
      // Column heights: col0 = 60+110+110 = 280, col1 = 210 -> 40 + 280 - 10.
      expect(r.canvasHeight, 310);
    });

    test('cover source rect crops the long side', () {
      final rect = coverSourceRect(200, 100, 1);
      expect((rect.x, rect.y, rect.w, rect.h), (50.0, 0.0, 100.0, 100.0));
      final tall = coverSourceRect(100, 200, 1);
      expect((tall.x, tall.y, tall.w, tall.h), (0.0, 50.0, 100.0, 100.0));
    });
  });

  group('dynamic layout', () {
    test('clamp position and size', () {
      final BoardPoint p = clampPosition(-10, 5000, 100, 100);
      expect((p.x, p.y), (0.0, dynamicCanvasH - 100));
      final s = clampSize(1500, 950, 400, 400);
      expect((s.w, s.h), (100.0, 60.0));
    });

    test('cascade and image size', () {
      final BoardRect r = cascadePosition(5);
      expect((r.x, r.y), (60 + 1 * 284, 60 + 224));
      final wide = dynamicImageSize(400, 200);
      expect((wide.w, wide.h), (260.0, 130.0));
      final tall = dynamicImageSize(200, 400);
      expect((tall.w, tall.h), (130.0, 260.0));
    });

    test('adjacent position prefers right, then left, then below, then bottom', () {
      const BoardRect src = BoardRect(500, 100, 200, 200);
      BoardPoint p = computeAdjacentPosition(src, <BoardRect>[], 180, 100);
      expect((p.x, p.y), (724.0, 100.0));

      p = computeAdjacentPosition(src, <BoardRect>[const BoardRect(724, 100, 180, 100)], 180, 100);
      expect((p.x, p.y), (500 - 180 - 24.0, 100.0));

      p = computeAdjacentPosition(
        src,
        <BoardRect>[const BoardRect(724, 100, 180, 100), const BoardRect(296, 100, 180, 100)],
        180,
        100,
      );
      expect((p.x, p.y), (500.0, 324.0));

      p = computeAdjacentPosition(
        src,
        <BoardRect>[
          const BoardRect(724, 100, 180, 100),
          const BoardRect(296, 100, 180, 100),
          const BoardRect(500, 324, 180, 100),
        ],
        180,
        100,
      );
      expect(p.y, 424 + swatchGroupGap);
    });

    test('rect overlap is exclusive on touching edges', () {
      const BoardRect a = BoardRect(0, 0, 10, 10);
      expect(a.overlaps(const BoardRect(10, 0, 10, 10)), isFalse);
      expect(a.overlaps(const BoardRect(9, 9, 10, 10)), isTrue);
    });

    test('wrapText breaks greedily', () {
      final List<String> lines =
          wrapText('aa bb cc dd', 5, (String s) => s.length.toDouble());
      expect(lines, <String>['aa bb', 'cc dd']);
      expect(wrapText('', 5, (String s) => s.length.toDouble()), isEmpty);
    });
  });
}
