import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../core/dynamic_layout.dart';
import '../core/kmeans.dart';
import '../models/board_models.dart';
import '../models/swatch.dart';
import '../services/app_messenger.dart';
import '../services/image_service.dart';
import '../services/picker_service.dart';
import '../services/sample_data.dart';

/// State for the Mood Board tab (grid and dynamic modes).
class BoardController extends ChangeNotifier {
  final List<BoardImage> images = <BoardImage>[];
  final List<StickyNote> notes = <StickyNote>[];
  final List<SwatchGroup> swatchGroups = <SwatchGroup>[];

  BoardMode mode = BoardMode.grid;
  int columns = 3;
  double gutter = 16;
  double padding = 24;
  double radius = 12;
  String ratio = '1:1';
  String bgColor = '#0f172a';

  String? selectedId;

  /// Id of the sticky note whose text is currently being edited.
  String? editingNoteId;
  bool loading = false;

  /// Palette extracted from the selected image (shown in the controls panel).
  List<Swatch> extractedColors = <Swatch>[];

  int _zCounter = 1;
  int _orderCounter = 1;
  final math.Random _random = math.Random();

  bool get isEmpty => images.isEmpty && notes.isEmpty && swatchGroups.isEmpty;

  BoardImage? get selectedImage {
    for (final BoardImage i in images) {
      if (i.id == selectedId) return i;
    }
    return null;
  }

  /// Images and swatch groups share one ordering so the grid can interleave them.
  List<OrderedBoardItem> get orderedItems => <OrderedBoardItem>[
        ...images,
        ...swatchGroups,
      ]..sort((OrderedBoardItem a, OrderedBoardItem b) => a.order.compareTo(b.order));

  /// Everything on the dynamic canvas, back to front.
  List<BoardItem> get zOrderedItems => <BoardItem>[
        ...images,
        ...notes,
        ...swatchGroups,
      ]..sort((BoardItem a, BoardItem b) => a.zIndex.compareTo(b.zIndex));

  String _id(String prefix) => '${prefix}_${_random.nextInt(1 << 31).toRadixString(36)}';

  BoardItem? findItem(String id) {
    for (final BoardItem item in <BoardItem>[...images, ...notes, ...swatchGroups]) {
      if (item.id == id) return item;
    }
    return null;
  }

  // ---- settings ----------------------------------------------------------

  void setMode(BoardMode value) {
    mode = value;
    notifyListeners();
  }

  void setColumns(int value) {
    columns = value;
    notifyListeners();
  }

  void setGutter(double value) {
    gutter = value;
    notifyListeners();
  }

  void setPadding(double value) {
    padding = value;
    notifyListeners();
  }

  void setRadius(double value) {
    radius = value;
    notifyListeners();
  }

  void setRatio(String value) {
    ratio = value;
    notifyListeners();
  }

  void setBgColor(String value) {
    bgColor = value;
    notifyListeners();
  }

  // ---- images ------------------------------------------------------------

  BoardImage addDecodedImage(ui.Image image, String name, {String? storedSrc}) {
    final BoardRect pos = cascadePosition(images.length + notes.length + swatchGroups.length);
    double w = pos.w;
    double h = pos.h;
    if (mode == BoardMode.dynamic) {
      final ({double w, double h}) size =
          dynamicImageSize(image.width.toDouble(), image.height.toDouble());
      w = size.w;
      h = size.h;
    }
    final BoardImage item = BoardImage(
      id: _id('mb'),
      name: name,
      image: image,
      x: pos.x,
      y: pos.y,
      w: w,
      h: h,
      zIndex: _zCounter++,
      order: _orderCounter++,
      storedSrc: storedSrc,
    );
    images.add(item);
    return item;
  }

  /// Decodes and adds all [picked] images. Failures are reported per file.
  Future<void> addPickedImages(List<PickedImage> picked) async {
    if (picked.isEmpty) return;
    loading = true;
    notifyListeners();
    int added = 0;
    for (final PickedImage file in picked) {
      try {
        final ui.Image img = await ImageService.decode(file.bytes);
        addDecodedImage(img, file.name);
        added++;
      } catch (err) {
        AppMessenger.show('Could not load ${file.name}: $err', isError: true);
      }
    }
    loading = false;
    notifyListeners();
    if (added > 0) {
      AppMessenger.show('Added $added image${added > 1 ? 's' : ''} to board!');
    }
  }

  Future<void> loadSampleBoard() async {
    loading = true;
    notifyListeners();
    try {
      final List<SampleBoardImage> samples = await SampleData.board();
      _clearAll();
      for (final SampleBoardImage s in samples) {
        addDecodedImage(s.image, s.name);
      }
      AppMessenger.show('Sample mood board loaded!');
    } catch (err) {
      AppMessenger.show('Could not build sample board: $err', isError: true);
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void removeImage(String id) {
    images.removeWhere((BoardImage i) => i.id == id);
    if (selectedId == id) selectedId = null;
    notifyListeners();
    AppMessenger.show('Image removed');
  }

  /// Swaps the board order of [id] with its neighbor ([direction] is -1 or 1).
  void moveItem(String id, int direction) {
    final List<OrderedBoardItem> combined = orderedItems;
    final int index = combined.indexWhere((OrderedBoardItem i) => i.id == id);
    if (index == -1) return;
    final int target = index + direction;
    if (target < 0 || target >= combined.length) return;
    final int tmp = combined[index].order;
    combined[index].order = combined[target].order;
    combined[target].order = tmp;
    notifyListeners();
  }

  void _clearAll() {
    images.clear();
    notes.clear();
    swatchGroups.clear();
    extractedColors = <Swatch>[];
    selectedId = null;
    editingNoteId = null;
  }

  void clear() {
    if (isEmpty) return;
    _clearAll();
    notifyListeners();
    AppMessenger.show('Mood board cleared');
  }

  // ---- selection / z-order ----------------------------------------------

  void select(String? id) {
    if (selectedId == id) return;
    selectedId = id;
    notifyListeners();
  }

  void bringToFront(String id) {
    final BoardItem? item = findItem(id);
    if (item == null) return;
    item.zIndex = ++_zCounter;
    notifyListeners();
  }

  /// Applies geometry changes from drags/resizes/nudges.
  void updateGeometry(String id, {double? x, double? y, double? w, double? h}) {
    final BoardItem? item = findItem(id);
    if (item == null) return;
    if (x != null) item.x = x;
    if (y != null) item.y = y;
    if (w != null) item.w = w;
    if (h != null) item.h = h;
    notifyListeners();
  }

  // ---- sticky notes ------------------------------------------------------

  StickyNote addStickyNote() {
    final BoardRect fallback =
        cascadePosition(images.length + notes.length + swatchGroups.length);
    final StickyNote note = StickyNote(
      id: _id('note'),
      text: 'New note',
      x: fallback.x,
      y: fallback.y,
      zIndex: _zCounter++,
    );
    notes.add(note);
    selectedId = note.id;
    editingNoteId = note.id;
    notifyListeners();
    return note;
  }

  void beginEditingNote(String id) {
    selectedId = id;
    editingNoteId = id;
    notifyListeners();
  }

  void endEditingNote() {
    if (editingNoteId == null) return;
    editingNoteId = null;
    notifyListeners();
  }

  void updateNote(String id, {String? text, String? color}) {
    for (final StickyNote n in notes) {
      if (n.id != id) continue;
      if (text != null) n.text = text;
      if (color != null) n.color = color;
      notifyListeners();
      return;
    }
  }

  void removeNote(String id) {
    notes.removeWhere((StickyNote n) => n.id == id);
    if (selectedId == id) selectedId = null;
    if (editingNoteId == id) editingNoteId = null;
    notifyListeners();
  }

  // ---- swatch groups -----------------------------------------------------

  SwatchGroup addSwatchGroup({
    required List<Swatch> colors,
    required String sourceName,
    required double x,
    required double y,
    required double w,
    required double h,
  }) {
    final SwatchGroup group = SwatchGroup(
      id: _id('swatch'),
      colors: colors,
      sourceName: sourceName,
      x: x,
      y: y,
      w: w,
      h: h,
      zIndex: _zCounter++,
      order: _orderCounter++,
    );
    swatchGroups.add(group);
    selectedId = group.id;
    notifyListeners();
    return group;
  }

  void removeSwatchGroup(String id, {bool toast = true}) {
    swatchGroups.removeWhere((SwatchGroup g) => g.id == id);
    if (selectedId == id) selectedId = null;
    notifyListeners();
    if (toast) AppMessenger.show('Palette removed');
  }

  /// Extracts a palette from the selected image. In dynamic mode the result is
  /// also placed next to the image as a swatch group.
  Future<void> extractSelectedPalette({int k = 5}) async {
    final BoardImage? item = selectedImage;
    if (item == null) {
      AppMessenger.show('Select a mood board image first', isError: true);
      return;
    }
    try {
      final Uint8List rgba = await ImageService.sampleRgba(item.image);
      final List<Swatch> colors =
          await compute(extractInIsolate, ExtractRequest(rgba, k, SortMode.prominence));
      extractedColors = colors;

      if (mode == BoardMode.dynamic) {
        final double h = math.max(80, colors.length * swatchGroupRowHeight);
        final BoardPoint pos = computeAdjacentPosition(
          BoardRect(item.x, item.y, item.w, item.h),
          <BoardItem>[...images, ...notes, ...swatchGroups]
              .where((BoardItem o) => o.id != item.id)
              .map((BoardItem o) => BoardRect(o.x, o.y, o.w, o.h))
              .toList(),
          swatchGroupWidth,
          h,
        );
        addSwatchGroup(
          colors: colors,
          sourceName: item.name,
          x: pos.x,
          y: pos.y,
          w: swatchGroupWidth,
          h: h,
        );
        AppMessenger.show('Palette added to the board!');
      } else {
        notifyListeners();
        AppMessenger.show('Palette extracted — switch to Dynamic mode to drag it onto the board');
      }
    } catch (err) {
      AppMessenger.show('Could not extract colors from that image: $err', isError: true);
    }
  }

  // ---- persistence hooks (used in Phase 5) ------------------------------

  Map<String, Object?> settingsToJson() => <String, Object?>{
        'mode': mode.name,
        'columns': columns,
        'gutter': gutter,
        'padding': padding,
        'radius': radius,
        'ratio': ratio,
        'bgColor': bgColor,
      };

  void applySettings(Map<String, Object?> json) {
    mode = boardModeFromName(json['mode'] as String?);
    final Object? cols = json['columns'];
    if (cols is num) columns = cols.toInt().clamp(1, 5);
    final Object? g = json['gutter'];
    if (g is num) gutter = g.toDouble().clamp(0, 64);
    final Object? p = json['padding'];
    if (p is num) padding = p.toDouble().clamp(0, 80);
    final Object? r = json['radius'];
    if (r is num) radius = r.toDouble().clamp(0, 40);
    final Object? ratioValue = json['ratio'];
    if (ratioValue is String) ratio = ratioValue;
    final Object? bg = json['bgColor'];
    if (bg is String) bgColor = bg;
  }

  /// Restores items from storage, keeping z/order counters consistent.
  void hydrateImage(BoardImage item) {
    images.add(item);
    _zCounter = math.max(_zCounter, item.zIndex + 1);
    _orderCounter = math.max(_orderCounter, item.order + 1);
  }

  void hydrateNote(StickyNote note) {
    notes.add(note);
    _zCounter = math.max(_zCounter, note.zIndex + 1);
  }

  void hydrateSwatchGroup(SwatchGroup group) {
    swatchGroups.add(group);
    _zCounter = math.max(_zCounter, group.zIndex + 1);
    _orderCounter = math.max(_orderCounter, group.order + 1);
  }

  void finishHydration() => notifyListeners();
}
