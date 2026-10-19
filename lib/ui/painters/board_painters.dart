import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/color_utils.dart';
import '../../core/dynamic_layout.dart';
import '../../core/grid_layout.dart';
import '../../models/board_models.dart';
import '../../models/swatch.dart';
import '../../state/board_controller.dart';
import '../app_theme.dart';

Color _hex(String hex) => Color(parseHexColor(hex));

void _drawImageCover(Canvas canvas, ui.Image image, Rect dst) {
  final ({double x, double y, double w, double h}) src = coverSourceRect(
    image.width.toDouble(),
    image.height.toDouble(),
    dst.width / dst.height,
  );
  canvas.drawImageRect(
    image,
    Rect.fromLTWH(src.x, src.y, src.w, src.h),
    dst,
    Paint()..filterQuality = FilterQuality.medium,
  );
}

void _drawText(
  Canvas canvas,
  String text,
  TextStyle style,
  Offset anchor, {
  bool centered = false,
  double maxWidth = double.infinity,
}) {
  final TextPainter tp = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    maxLines: 1,
    ellipsis: '…',
  )..layout(maxWidth: maxWidth);
  final double dx = centered ? anchor.dx - tp.width / 2 : anchor.dx;
  tp.paint(canvas, Offset(dx, anchor.dy - tp.height / 2));
  tp.dispose();
}

void _drawSwatchRows(
  Canvas canvas,
  List<Swatch> colors,
  Rect rect, {
  required bool centered,
  required double minFont,
  required double maxFont,
  double leftPadding = 10,
}) {
  final double rowH = rect.height / colors.length;
  final double fontSize = math.max(minFont, math.min(maxFont, (rowH * 0.4).roundToDouble()));
  for (int i = 0; i < colors.length; i++) {
    final Swatch color = colors[i];
    final double rowY = rect.top + i * rowH;
    canvas.drawRect(
      Rect.fromLTWH(rect.left, rowY, rect.width, rowH),
      Paint()..color = Color(color.argb),
    );
    final TextStyle style = TextStyle(
      fontFamily: monoFont,
      fontWeight: FontWeight.w700,
      fontSize: fontSize,
      color: color.isLight ? AppColors.slate900 : Colors.white,
    );
    if (centered) {
      _drawText(canvas, color.hex, style, Offset(rect.center.dx, rowY + rowH / 2),
          centered: true);
    } else {
      _drawText(canvas, color.hex, style, Offset(rect.left + leftPadding, rowY + rowH / 2));
    }
  }
}

/// A snapshot of a grid-mode board, used for both display and PNG export.
class GridBoardPlan {
  GridBoardPlan._({
    required this.layout,
    required this.items,
    required this.height,
    required this.bgColor,
    required this.radius,
  });

  /// Returns null when the board has no grid cells.
  static GridBoardPlan? from(BoardController board) {
    final List<OrderedBoardItem> items = board.orderedItems;
    if (items.isEmpty) return null;
    final int cols = math.min(board.columns, items.length);
    final double cellWidth =
        gridCellWidth(cols: cols, gutter: board.gutter, padding: board.padding);
    final GridLayoutResult layout = layoutGridCells(
      cells: <GridCell>[
        for (final OrderedBoardItem item in items)
          GridCell(
            id: item.id,
            aspect: item is BoardImage
                ? item.aspect
                : (item is SwatchGroup ? item.aspect : 1),
          ),
      ],
      cols: cols,
      cellWidth: cellWidth,
      gutter: board.gutter,
      padding: board.padding,
      ratio: board.ratio,
    );
    return GridBoardPlan._(
      layout: layout,
      items: items,
      height: layout.canvasHeight,
      bgColor: _hex(board.bgColor),
      radius: board.radius,
    );
  }

  final GridLayoutResult layout;
  final List<OrderedBoardItem> items;
  final double height;
  final Color bgColor;
  final double radius;

  double get width => gridBaseWidth;
  int get pixelWidth => gridBaseWidth.round();
  int get pixelHeight => height.round();

  void paint(Canvas canvas, Size size) {
    canvas.save();
    final double scale = size.width / width;
    canvas.scale(scale, scale);
    canvas.drawRect(Rect.fromLTWH(0, 0, width, height), Paint()..color = bgColor);

    for (int i = 0; i < items.length; i++) {
      final PlacedCell cell = layout.cells[i];
      final OrderedBoardItem item = items[i];
      final Rect rect = Rect.fromLTWH(cell.x, cell.y, cell.w, cell.h);
      final RRect rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));

      canvas.save();
      canvas.clipRRect(rrect, doAntiAlias: true);
      if (item is BoardImage) {
        _drawImageCover(canvas, item.image, rect);
      } else if (item is SwatchGroup) {
        _drawSwatchRows(canvas, item.colors, rect, centered: true, minFont: 10, maxFont: 20);
      }
      canvas.restore();

      if (radius > 0) {
        canvas.drawRRect(
          rrect,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = const Color.fromRGBO(255, 255, 255, 0.08),
        );
      }
    }
    canvas.restore();
  }
}

class GridBoardPainter extends CustomPainter {
  GridBoardPainter(this.plan);

  final GridBoardPlan plan;

  @override
  void paint(Canvas canvas, Size size) => plan.paint(canvas, size);

  @override
  bool shouldRepaint(GridBoardPainter oldDelegate) => true;
}

/// Paints the whole dynamic board (background + items by z-order) at its
/// logical 1600x1000 size, scaled to [size]. Used for PNG export.
class DynamicBoardRenderer {
  const DynamicBoardRenderer(this.board);

  final BoardController board;

  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / dynamicCanvasW, size.height / dynamicCanvasH);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, dynamicCanvasW, dynamicCanvasH),
      Paint()..color = _hex(board.bgColor),
    );

    for (final BoardItem item in board.zOrderedItems) {
      canvas.save();
      canvas.translate(item.x + item.w / 2, item.y + item.h / 2);
      canvas.rotate(item.rotation * math.pi / 180);
      final Rect rect = Rect.fromLTWH(-item.w / 2, -item.h / 2, item.w, item.h);

      if (item is BoardImage) {
        _drawImageCover(canvas, item.image, rect);
      } else if (item is StickyNote) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(12)),
          Paint()..color = _hex(item.color),
        );
        _paintNoteText(canvas, item, rect);
      } else if (item is SwatchGroup) {
        _drawSwatchRows(canvas, item.colors, rect,
            centered: false, minFont: 9, maxFont: 16);
      }
      canvas.restore();
    }
    canvas.restore();
  }

  void _paintNoteText(Canvas canvas, StickyNote note, Rect rect) {
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: note.text,
        style: TextStyle(
          fontFamily: sansFont,
          fontWeight: FontWeight.w600,
          fontSize: 18,
          height: 22 / 18,
          color: _hex(note.textColor),
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: math.max(1, rect.width - 24));
    tp.paint(canvas, Offset(rect.center.dx - tp.width / 2, rect.center.dy - tp.height / 2));
    tp.dispose();
  }
}
