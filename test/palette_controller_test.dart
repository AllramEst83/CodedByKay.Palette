import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:palette_app/core/color_utils.dart';
import 'package:palette_app/core/kmeans.dart';
import 'package:palette_app/core/value_study.dart';
import 'package:palette_app/models/swatch.dart';
import 'package:palette_app/state/palette_controller.dart';
import 'package:palette_app/ui/painters/palette_composite.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PaletteController', () {
    testWidgets('loads the sample and extracts the requested count', (WidgetTester tester) async {
      final PaletteController c = PaletteController(extractDebounce: Duration.zero);
      addTearDown(c.dispose);
      await tester.runAsync(c.loadSample);
      expect(c.hasImage, isTrue);
      expect(c.loading, isFalse);
      expect(c.sourceColors, hasLength(5));
      expect(c.displayedColors, same(c.sourceColors));
      // Default sort is prominence: descending counts.
      final List<int> counts = c.sourceColors.map((Swatch s) => s.count).toList();
      expect(counts, orderedEquals(<int>[...counts]..sort((int a, int b) => b.compareTo(a))));
    });

    testWidgets('theme and harmony are mutually exclusive', (WidgetTester tester) async {
      final PaletteController c = PaletteController(extractDebounce: Duration.zero);
      addTearDown(c.dispose);
      await tester.runAsync(c.loadSample);

      c.applyThemeByName('pastel');
      expect(c.activeTheme, 'pastel');
      expect(c.activeHarmony, isNull);
      expect(c.displayedColors, isNot(same(c.sourceColors)));

      c.applyHarmonyByName('triadic');
      expect(c.activeTheme, isNull);
      expect(c.activeHarmony, 'triadic');
      expect(c.displayedColors, hasLength(c.sourceColors.length));

      c.applyThemeByName('original');
      expect(c.activeTheme, isNull);
      expect(c.displayedColors, same(c.sourceColors));
    });

    testWidgets('count changes re-extract and stale results are ignored', (WidgetTester tester) async {
      final PaletteController c = PaletteController(extractDebounce: const Duration(milliseconds: 20));
      addTearDown(c.dispose);
      await tester.runAsync(c.loadSample);

      await tester.runAsync(() async {
        c.setPaletteCount(8);
        c.setPaletteCount(4); // supersedes the first request
        await Future<void>.delayed(const Duration(milliseconds: 400));
      });
      expect(c.paletteCount, 4);
      expect(c.sourceColors, hasLength(4));
    });

    testWidgets('sort mode re-sorts and picks the dominant base color', (WidgetTester tester) async {
      final PaletteController c = PaletteController(extractDebounce: Duration.zero);
      addTearDown(c.dispose);
      await tester.runAsync(c.loadSample);

      c.setSortMode(SortMode.luminance);
      final List<double> lum = c.sourceColors.map((Swatch s) => s.lightness).toList();
      expect(lum, orderedEquals(<double>[...lum]..sort()));
      expect(c.baseColorIndex, inInclusiveRange(0, c.sourceColors.length - 1));

      c.setBaseColorIndex(99); // ignored
      expect(c.baseColorIndex, inInclusiveRange(0, c.sourceColors.length - 1));
    });

    testWidgets('grayscale renders and caches value studies', (WidgetTester tester) async {
      final PaletteController c = PaletteController(extractDebounce: Duration.zero);
      addTearDown(c.dispose);
      await tester.runAsync(c.loadSample);
      expect(c.valueImage, isNull);
      expect(c.compositeColors, same(c.displayedColors));

      await tester.runAsync(() => c.setGrayscale(true));
      expect(c.valueLoading, isFalse);
      final ui.Image? gray = c.valueImage;
      expect(gray, isNotNull);
      expect(gray!.width, c.image!.width);
      for (final Swatch s in c.compositeColors) {
        expect((s.r, s.g), (s.b, s.b));
      }

      // Posterizing renders a separate study; going back reuses the first one.
      await tester.runAsync(() => c.setPosterizeLevels(3));
      expect(c.valueImage, isNot(same(gray)));
      final Set<int> bands = <int>{
        for (final double l in <double>[100 / 6, 50, 500 / 6]) grayForLightness(l),
      };
      final ByteData? pixels = await tester.runAsync<ByteData?>(() => c.valueImage!.toByteData());
      final Set<int> rendered = <int>{
        for (int i = 0; i < pixels!.lengthInBytes; i += 4) pixels.getUint8(i),
      };
      expect(bands.containsAll(rendered), isTrue, reason: '$rendered');

      await tester.runAsync(() => c.setPosterizeLevels(fullTonalRange));
      expect(c.valueImage, same(gray));

      await tester.runAsync(() => c.setGrayscale(false));
      expect(c.valueImage, isNull);
      expect(c.compositeColors, same(c.displayedColors));
    });

    testWidgets('a superseded value render is ignored', (WidgetTester tester) async {
      final PaletteController c = PaletteController(extractDebounce: Duration.zero);
      addTearDown(c.dispose);
      await tester.runAsync(c.loadSample);

      await tester.runAsync(() async {
        final Future<void> first = c.setGrayscale(true);
        final Future<void> second = c.setGrayscale(false);
        await Future.wait(<Future<void>>[first, second]);
      });
      expect(c.valueLoading, isFalse);
      expect(c.valueImage, isNull);
    });

    test('settings round trip and invalid values are ignored', () {
      final PaletteController c = PaletteController();
      addTearDown(c.dispose);
      c.applySettings(<String, Object?>{
        'paletteCountK': 99,
        'sortMode': 'hue',
        'showHexText': false,
        'showRgbText': true,
        'activeTheme': 'nope',
        'activeHarmony': 'analogous',
        'baseColorIndex': 2,
        'showLightnessText': false,
        'grayscale': true,
        'posterizeLevels': 4,
      });
      expect(c.paletteCount, PaletteController.maxCount);
      expect(c.sortMode, SortMode.hue);
      expect(c.showHexText, isFalse);
      expect(c.activeTheme, isNull);
      expect(c.activeHarmony, 'analogous');
      final Map<String, Object?> json = c.toJson();
      expect(json['sortMode'], 'hue');
      expect(json['baseColorIndex'], 2);
      expect(json['showLightnessText'], isFalse);
      expect(json['grayscale'], isTrue);
      expect(json['posterizeLevels'], 4);

      c.applySettings(<String, Object?>{'posterizeLevels': 9});
      expect(c.posterizeLevels, 4);
    });
  });

  group('PaletteCompositePlan', () {
    final List<Swatch> colors = List<Swatch>.generate(
      5,
      (int i) => Swatch.fromRgb(40 * i, 255 - 40 * i, 90),
    );

    test('wide image uses a strip beneath the image', () {
      final PaletteCompositePlan plan = PaletteCompositePlan.compute(
        imageWidth: 900,
        imageHeight: 600,
        colors: colors,
        showHex: true,
        showRgb: false,
      );
      expect(plan.sidebar, isFalse);
      expect(plan.width, 900);
      expect(plan.height, 600 + 108); // strip = max(80, round(600 * 0.18))
      expect(plan.swatchWidths.reduce((double a, double b) => a + b), closeTo(900, 1e-6));
    });

    test('narrow image falls back to a sidebar', () {
      final PaletteCompositePlan plan = PaletteCompositePlan.compute(
        imageWidth: 120,
        imageHeight: 400,
        colors: colors,
        showHex: true,
        showRgb: true,
      );
      expect(plan.sidebar, isTrue);
      expect(plan.width, greaterThanOrEqualTo(120 + 200));
      expect(plan.height, greaterThanOrEqualTo(400));
    });

    test('lightness labels need space and keep the strip full width', () {
      final PaletteCompositePlan strip = PaletteCompositePlan.compute(
        imageWidth: 900,
        imageHeight: 600,
        colors: colors,
        showHex: true,
        showRgb: true,
        showLightness: true,
      );
      expect(strip.sidebar, isFalse);
      expect(strip.swatchWidths.reduce((double a, double b) => a + b), closeTo(900, 1e-6));

      final PaletteCompositePlan narrow = PaletteCompositePlan.compute(
        imageWidth: 100,
        imageHeight: 100,
        colors: colors,
        showHex: false,
        showRgb: false,
        showLightness: true,
      );
      expect(narrow.sidebar, isTrue);
    });

    test('no labels never needs a sidebar', () {
      final PaletteCompositePlan plan = PaletteCompositePlan.compute(
        imageWidth: 100,
        imageHeight: 100,
        colors: colors,
        showHex: false,
        showRgb: false,
      );
      expect(plan.sidebar, isFalse);
    });
  });
}
