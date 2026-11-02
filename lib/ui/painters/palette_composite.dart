import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../models/swatch.dart';
import '../app_theme.dart';

const double _swatchPaddingX = 12;
const double _minSwatchWidth = 48;
const double _minFontSize = 9;
const double _minSubFontSize = 7;
const double _sidebarMinWidth = 200;
const double _sidebarRowMinHeight = 44;
const double _sidebarPaddingX = 16;

const Color _darkText = Color(0xFF0F172A);
const Color _lightText = Color(0xFFFFFFFF);

double _measure(String text, double size, FontWeight weight) {
  final TextPainter tp = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(fontFamily: monoFont, fontSize: size, fontWeight: weight),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  final double width = tp.width;
  tp.dispose();
  return width;
}

/// Which color codes are written on each swatch, and how they are arranged into
/// a main line and an optional smaller line beneath it.
class _SwatchLabels {
  const _SwatchLabels(this.showHex, this.showRgb, this.showLightness);

  final bool showHex;
  final bool showRgb;
  final bool showLightness;

  bool get any => showHex || showRgb || showLightness;

  String? main(Swatch color) {
    if (showHex) return color.hex;
    if (showRgb) return 'rgb(${color.r},${color.g},${color.b})';
    return showLightness ? color.lightnessLabel : null;
  }

  String? sub(Swatch color) {
    final String? rgb = showHex && showRgb ? color.rgbLabel : null;
    final String? lightness =
        showLightness && (showHex || showRgb) ? color.lightnessLabel : null;
    if (rgb != null && lightness != null) return '$rgb · $lightness';
    return rgb ?? lightness;
  }

  /// A lone HEX code is drawn a little larger than [fontSize].
  double mainSize(Swatch color, double fontSize) =>
      showHex && sub(color) == null ? fontSize + 2 : fontSize;
}

/// Everything needed to draw the composite (image + swatches) at logical size,
/// shared by the on-screen preview and the PNG export. Ported from `palette.js`.
class PaletteCompositePlan {
  PaletteCompositePlan._({
    required this.width,
    required this.height,
    required this.sidebar,
    required this.imgW,
    required this.imgH,
    required this.colors,
    required this._labels,
    required this.fontSize,
    required this.subFontSize,
    required this.swatchWidths,
    required this.stripHeight,
    required this.rowHeight,
    required this.sidebarWidth,
  });

  factory PaletteCompositePlan.compute({
    required int imageWidth,
    required int imageHeight,
    required List<Swatch> colors,
    required bool showHex,
    required bool showRgb,
    bool showLightness = false,
  }) {
    final double imgW = imageWidth.toDouble();
    final double imgH = imageHeight.toDouble();
    final _SwatchLabels labels = _SwatchLabels(showHex, showRgb, showLightness);
    final bool tooNarrow = labels.any && imgW < colors.length * _minSwatchWidth;
    return tooNarrow
        ? _sidebar(imgW, imgH, colors, labels)
        : _strip(imgW, imgH, colors, labels);
  }

  final double width;
  final double height;
  final bool sidebar;
  final double imgW;
  final double imgH;
  final List<Swatch> colors;
  final _SwatchLabels _labels;
  final double fontSize;
  final double subFontSize;
  final List<double> swatchWidths;
  final double stripHeight;
  final double rowHeight;
  final double sidebarWidth;

  int get pixelWidth => width.round();
  int get pixelHeight => height.round();

  static List<double> _naturalWidths(
    List<Swatch> colors,
    double fontSize,
    double subFontSize,
    _SwatchLabels labels,
  ) {
    return colors.map((Swatch color) {
      double needed = _minSwatchWidth;
      final String? main = labels.main(color);
      if (main != null) {
        final double mainSize = labels.mainSize(color, fontSize);
        needed = math.max(
          needed,
          _measure(main, mainSize, FontWeight.w700) + _swatchPaddingX * 2,
        );
      }
      final String? sub = labels.sub(color);
      if (sub != null) {
        needed = math.max(
          needed,
          _measure(sub, subFontSize, FontWeight.w500) + _swatchPaddingX * 2,
        );
      }
      return needed;
    }).toList();
  }

  static PaletteCompositePlan _strip(
    double imgW,
    double imgH,
    List<Swatch> colors,
    _SwatchLabels labels,
  ) {
    final double stripHeight = math.max(80, (imgH * 0.18).roundToDouble());
    double fontSize = math.max(14, (stripHeight * 0.18).roundToDouble());
    double subFontSize = math.max(10, (stripHeight * 0.12).roundToDouble());
    List<double> natural = _naturalWidths(colors, fontSize, subFontSize, labels);

    while (natural.fold<double>(0, (double a, double b) => a + b) > imgW &&
        (fontSize > _minFontSize || subFontSize > _minSubFontSize)) {
      fontSize = math.max(_minFontSize, fontSize - 1);
      subFontSize = math.max(_minSubFontSize, subFontSize - 1);
      natural = _naturalWidths(colors, fontSize, subFontSize, labels);
    }

    final double naturalTotal = natural.fold<double>(0, (double a, double b) => a + b);
    final double scale = naturalTotal > 0 ? imgW / naturalTotal : 1;
    return PaletteCompositePlan._(
      width: imgW,
      height: imgH + stripHeight,
      sidebar: false,
      imgW: imgW,
      imgH: imgH,
      colors: colors,
      labels: labels,
      fontSize: fontSize,
      subFontSize: subFontSize,
      swatchWidths: natural.map((double w) => w * scale).toList(),
      stripHeight: stripHeight,
      rowHeight: 0,
      sidebarWidth: 0,
    );
  }

  static PaletteCompositePlan _sidebar(
    double imgW,
    double imgH,
    List<Swatch> colors,
    _SwatchLabels labels,
  ) {
    final double rowHeight =
        math.max(_sidebarRowMinHeight, (imgH / colors.length).roundToDouble());
    final double canvasHeight = math.max(imgH, rowHeight * colors.length);
    final double rowFont = math.max(13, math.min(20, (rowHeight * 0.32).roundToDouble()));
    final double rowSub = math.max(10, math.min(15, (rowHeight * 0.22).roundToDouble()));

    final double maxLabel = colors.map((Swatch c) {
      final String? main = labels.main(c);
      final String? sub = labels.sub(c);
      return math.max(
        main == null ? 0.0 : _measure(main, labels.mainSize(c, rowFont), FontWeight.w700),
        sub == null ? 0.0 : _measure(sub, rowSub, FontWeight.w500),
      );
    }).fold<double>(0, math.max);
    final double sidebarWidth =
        math.max(_sidebarMinWidth, (maxLabel + _sidebarPaddingX * 2).roundToDouble());

    return PaletteCompositePlan._(
      width: imgW + sidebarWidth,
      height: canvasHeight,
      sidebar: true,
      imgW: imgW,
      imgH: imgH,
      colors: colors,
      labels: labels,
      fontSize: rowFont,
      subFontSize: rowSub,
      swatchWidths: const <double>[],
      stripHeight: 0,
      rowHeight: rowHeight,
      sidebarWidth: sidebarWidth,
    );
  }

  /// Paints the composite into [canvas], scaled to fill [size].
  void paint(Canvas canvas, Size size, ui.Image image) {
    canvas.save();
    final double scale = size.width / width;
    canvas.scale(scale, scale);
    if (sidebar) {
      _paintSidebar(canvas, image);
    } else {
      _paintStrip(canvas, image);
    }
    canvas.restore();
  }

  void _drawImage(Canvas canvas, ui.Image image) {
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(0, 0, imgW, imgH),
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  static void _text(
    Canvas canvas,
    String text,
    double size,
    FontWeight weight,
    Color color,
    Offset anchor, {
    required bool centered,
  }) {
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: monoFont,
          fontSize: size,
          fontWeight: weight,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final double dx = centered ? anchor.dx - tp.width / 2 : anchor.dx;
    tp.paint(canvas, Offset(dx, anchor.dy - tp.height / 2));
    tp.dispose();
  }

  void _paintStrip(Canvas canvas, ui.Image image) {
    _drawImage(canvas, image);
    double cursorX = 0;
    for (int i = 0; i < colors.length; i++) {
      final Swatch color = colors[i];
      final double x = cursorX;
      final double y = imgH;
      final double w = i == colors.length - 1 ? width - x : swatchWidths[i];
      cursorX += w;

      canvas.drawRect(Rect.fromLTWH(x, y, w, stripHeight), Paint()..color = Color(color.argb));

      final Color text = color.isLight ? _darkText : _lightText;
      final Color sub = color.isLight
          ? const Color.fromRGBO(15, 23, 42, 0.75)
          : const Color.fromRGBO(255, 255, 255, 0.75);
      final double cx = x + w / 2;
      final String? mainLabel = _labels.main(color);
      final String? subLabel = _labels.sub(color);
      if (mainLabel != null) {
        _text(canvas, mainLabel, _labels.mainSize(color, fontSize), FontWeight.w700, text,
            Offset(cx, y + stripHeight * (subLabel == null ? 0.5 : 0.38)), centered: true);
      }
      if (subLabel != null) {
        _text(canvas, subLabel, subFontSize, FontWeight.w500, sub,
            Offset(cx, y + stripHeight * 0.68), centered: true);
      }
    }

    canvas.drawLine(
      Offset(0, imgH),
      Offset(width, imgH),
      Paint()
        ..color = const Color.fromRGBO(0, 0, 0, 0.15)
        ..strokeWidth = 2,
    );
  }

  void _paintSidebar(Canvas canvas, ui.Image image) {
    canvas.drawRect(Rect.fromLTWH(0, 0, width, height), Paint()..color = AppColors.slate900);
    _drawImage(canvas, image);

    for (int i = 0; i < colors.length; i++) {
      final Swatch color = colors[i];
      final double x = imgW;
      final double y = i * rowHeight;
      final double textX = x + _sidebarPaddingX;

      canvas.drawRect(
        Rect.fromLTWH(x, y, sidebarWidth, rowHeight),
        Paint()..color = Color(color.argb),
      );

      final Color text = color.isLight ? _darkText : _lightText;
      final Color sub = color.isLight
          ? const Color.fromRGBO(15, 23, 42, 0.75)
          : const Color.fromRGBO(255, 255, 255, 0.75);
      final String? mainLabel = _labels.main(color);
      final String? subLabel = _labels.sub(color);
      if (mainLabel != null) {
        _text(canvas, mainLabel, _labels.mainSize(color, fontSize), FontWeight.w700, text,
            Offset(textX, y + rowHeight * (subLabel == null ? 0.5 : 0.36)), centered: false);
      }
      if (subLabel != null) {
        _text(canvas, subLabel, subFontSize, FontWeight.w500, sub,
            Offset(textX, y + rowHeight * 0.68), centered: false);
      }

      if (i > 0) {
        canvas.drawLine(
          Offset(x, y),
          Offset(x + sidebarWidth, y),
          Paint()
            ..color = const Color.fromRGBO(0, 0, 0, 0.15)
            ..strokeWidth = 1,
        );
      }
    }

    canvas.drawLine(
      Offset(imgW, 0),
      Offset(imgW, height),
      Paint()
        ..color = const Color.fromRGBO(0, 0, 0, 0.25)
        ..strokeWidth = 2,
    );
  }
}

class PaletteCompositePainter extends CustomPainter {
  PaletteCompositePainter({required this.plan, required this.image});

  final PaletteCompositePlan plan;
  final ui.Image image;

  @override
  void paint(Canvas canvas, Size size) => plan.paint(canvas, size, image);

  @override
  bool shouldRepaint(PaletteCompositePainter oldDelegate) =>
      oldDelegate.plan != plan || oldDelegate.image != image;
}
