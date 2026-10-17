import 'dart:math' as math;

/// Dynamic (free-form) board geometry ported from the legacy
/// `moodboard-dynamic.js`, `moodboard-state.js` and `moodboard-extract.js`.

const double dynamicCanvasW = 1600;
const double dynamicCanvasH = 1000;
const double minResizeSize = 60;
const double dynamicImageMax = 260;

const double swatchGroupWidth = 180;
const double swatchGroupRowHeight = 34;
const double swatchGroupGap = 24;

class BoardRect {
  const BoardRect(this.x, this.y, this.w, this.h);

  final double x;
  final double y;
  final double w;
  final double h;

  bool overlaps(BoardRect o) =>
      x < o.x + o.w && x + w > o.x && y < o.y + o.h && y + h > o.y;
}

class BoardPoint {
  const BoardPoint(this.x, this.y);

  final double x;
  final double y;
}

BoardPoint clampPosition(double x, double y, double w, double h) => BoardPoint(
      math.min(math.max(0, x), math.max(0, dynamicCanvasW - w)),
      math.min(math.max(0, y), math.max(0, dynamicCanvasH - h)),
    );

({double w, double h}) clampSize(double x, double y, double w, double h) => (
      w: math.min(w, math.max(minResizeSize, dynamicCanvasW - x)),
      h: math.min(h, math.max(minResizeSize, dynamicCanvasH - y)),
    );

/// Default cascade position/size for the n-th item added to a board.
BoardRect cascadePosition(int index) {
  const int cols = 4;
  const double cellW = 260;
  const double cellH = 200;
  final int col = index % cols;
  final int row = index ~/ cols;
  return BoardRect(60 + col * (cellW + 24), 60 + row * (cellH + 24), cellW, cellH);
}

/// Fits an image into [dynamicImageMax] while keeping its aspect ratio.
({double w, double h}) dynamicImageSize(double naturalW, double naturalH) {
  final double aspect = (naturalW <= 0 ? 1 : naturalW) / (naturalH <= 0 ? 1 : naturalH);
  return aspect >= 1
      ? (w: dynamicImageMax, h: dynamicImageMax / aspect)
      : (w: dynamicImageMax * aspect, h: dynamicImageMax);
}

/// Prefers a spot directly right of [source], falling back to its left or
/// below it — whichever doesn't collide with another item in [others].
BoardPoint computeAdjacentPosition(
  BoardRect source,
  List<BoardRect> others,
  double objW,
  double objH,
) {
  final List<BoardPoint> candidates = <BoardPoint>[
    BoardPoint(source.x + source.w + swatchGroupGap, source.y),
    BoardPoint(source.x - objW - swatchGroupGap, source.y),
    BoardPoint(source.x, source.y + source.h + swatchGroupGap),
  ];

  for (final BoardPoint pos in candidates) {
    if (pos.x < 0 || pos.x + objW > dynamicCanvasW) continue;
    final BoardRect rect = BoardRect(pos.x, pos.y, objW, objH);
    if (!others.any(rect.overlaps)) return pos;
  }

  // Board is packed tight around the source: drop below everything.
  final double lowestBottom = others.fold<double>(
    source.y + source.h,
    (double max, BoardRect item) => math.max(max, item.y + item.h),
  );
  return BoardPoint(
    math.max(0, math.min(source.x, dynamicCanvasW - objW)),
    lowestBottom + swatchGroupGap,
  );
}

/// Greedy word wrap, given a width measuring function.
List<String> wrapText(String text, double maxWidth, double Function(String) measure) {
  final List<String> words =
      text.split(RegExp(r'\s+')).where((String w) => w.isNotEmpty).toList();
  final List<String> lines = <String>[];
  String line = '';
  for (final String word in words) {
    final String test = line.isEmpty ? word : '$line $word';
    if (measure(test) > maxWidth && line.isNotEmpty) {
      lines.add(line);
      line = word;
    } else {
      line = test;
    }
  }
  if (line.isNotEmpty) lines.add(line);
  return lines;
}
