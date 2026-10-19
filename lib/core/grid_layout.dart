import 'dart:math' as math;

/// Grid/masonry layout ported from the legacy `moodboard-grid.js`.

/// Base logical width used for grid rendering and export.
const double gridBaseWidth = 1920;

const List<String> gridRatios = <String>['1:1', '4:3', '3:4', '16:9', 'original'];

class GridCell {
  const GridCell({required this.id, required this.aspect});

  final String id;

  /// width / height of the item's natural shape (used for the `original` ratio).
  final double aspect;
}

class PlacedCell {
  const PlacedCell({
    required this.id,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
  });

  final String id;
  final double x;
  final double y;
  final double w;
  final double h;
}

class GridLayoutResult {
  const GridLayoutResult({required this.cells, required this.canvasHeight});

  final List<PlacedCell> cells;
  final double canvasHeight;
}

/// Width of a single cell for [cols] columns inside [baseWidth].
double gridCellWidth({
  required int cols,
  required double gutter,
  required double padding,
  double baseWidth = gridBaseWidth,
}) =>
    (baseWidth - padding * 2 - (cols - 1) * gutter) / cols;

double _ratioHeight(double cellWidth, String ratio) {
  switch (ratio) {
    case '4:3':
      return cellWidth * 3 / 4;
    case '3:4':
      return cellWidth * 4 / 3;
    case '16:9':
      return cellWidth * 9 / 16;
    default:
      return cellWidth;
  }
}

/// Lays out cells in a fixed-ratio grid or, for `original`, a masonry of
/// columns where each cell keeps its natural aspect ratio.
GridLayoutResult layoutGridCells({
  required List<GridCell> cells,
  required int cols,
  required double cellWidth,
  required double gutter,
  required double padding,
  required String ratio,
}) {
  if (ratio == 'original') {
    final List<double> columnHeights = List<double>.filled(cols, 0);
    final List<PlacedCell> placed = cells.map((GridCell cell) {
      int colIndex = 0;
      for (int c = 1; c < cols; c++) {
        if (columnHeights[c] < columnHeights[colIndex]) colIndex = c;
      }
      final double cellHeight = cellWidth / (cell.aspect == 0 ? 1 : cell.aspect);
      final double x = padding + colIndex * (cellWidth + gutter);
      final double y = padding + columnHeights[colIndex];
      columnHeights[colIndex] += cellHeight + gutter;
      return PlacedCell(id: cell.id, x: x, y: y, w: cellWidth, h: cellHeight);
    }).toList();
    final double tallest = columnHeights.reduce(math.max);
    return GridLayoutResult(
      cells: placed,
      canvasHeight: padding * 2 + tallest - gutter,
    );
  }

  final double cellHeight = _ratioHeight(cellWidth, ratio);
  final int rows = (cells.length / cols).ceil();
  final List<PlacedCell> placed = <PlacedCell>[
    for (int i = 0; i < cells.length; i++)
      PlacedCell(
        id: cells[i].id,
        x: padding + (i % cols) * (cellWidth + gutter),
        y: padding + (i ~/ cols) * (cellHeight + gutter),
        w: cellWidth,
        h: cellHeight,
      ),
  ];
  return GridLayoutResult(
    cells: placed,
    canvasHeight: padding * 2 + rows * cellHeight + (rows - 1) * gutter,
  );
}

/// Source rect (in image pixels) for a center-crop "cover" fit of an image
/// of [imgW]x[imgH] into a cell of aspect [cellAspect].
({double x, double y, double w, double h}) coverSourceRect(
  double imgW,
  double imgH,
  double cellAspect,
) {
  final double imgAspect = imgW / imgH;
  if (imgAspect > cellAspect) {
    final double w = imgH * cellAspect;
    return (x: (imgW - w) / 2, y: 0, w: w, h: imgH);
  }
  final double h = imgW / cellAspect;
  return (x: 0, y: (imgH - h) / 2, w: imgW, h: h);
}
