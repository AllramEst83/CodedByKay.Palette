import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:palette_app/core/kmeans.dart';
import 'package:palette_app/models/board_models.dart';
import 'package:palette_app/services/blob/blob_store.dart';
import 'package:palette_app/state/board_controller.dart';
import 'package:palette_app/state/palette_controller.dart';
import 'package:palette_app/state/persistence.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppPersistence> _make(
  PaletteController p,
  BoardController b,
  MemoryBlobStore blobs,
) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  return AppPersistence(palette: p, board: b, prefs: prefs, blobs: blobs);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('saves and restores settings, images, notes and palettes', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final MemoryBlobStore blobs = MemoryBlobStore();

    final PaletteController p1 = PaletteController();
    final BoardController b1 = BoardController();
    addTearDown(p1.dispose);
    addTearDown(b1.dispose);
    await tester.runAsync(() async {
      await b1.loadSampleBoard();
      b1.setMode(BoardMode.dynamic);
      b1.setColumns(4);
      b1.setRatio('original');
      b1.setBgColor('#1e1b4b');
      b1.select(b1.images.first.id);
      await b1.extractSelectedPalette();
      final StickyNote note = b1.addStickyNote();
      b1.endEditingNote();
      b1.updateNote(note.id, text: 'Keep me', color: '#fecaca');
      b1.updateGeometry(b1.images[2].id, x: 700, y: 420);
      p1.applySettings(<String, Object?>{
        'paletteCountK': 7,
        'sortMode': 'hue',
        'activeHarmony': 'triadic',
        'showRgbText': true,
        'baseColorIndex': 3,
      });

      final AppPersistence save = await _make(p1, b1, blobs);
      await save.flush();
    });

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final Map<String, Object?> json =
        jsonDecode(prefs.getString(storageKey)!) as Map<String, Object?>;
    expect(json['version'], 1);
    expect(((json['moodboard']! as Map<String, Object?>)['images']! as List<Object?>), hasLength(6));

    final PaletteController p2 = PaletteController();
    final BoardController b2 = BoardController();
    addTearDown(p2.dispose);
    addTearDown(b2.dispose);
    final bool restored = await tester.runAsync(() async {
      final AppPersistence load = await _make(p2, b2, blobs);
      return load.restore();
    }) ?? false;

    expect(restored, isTrue);
    expect(p2.paletteCount, 7);
    expect(p2.sortMode, SortMode.hue);
    expect(p2.activeHarmony, 'triadic');
    expect(p2.showRgbText, isTrue);
    expect(p2.baseColorIndex, 3);

    expect(b2.mode, BoardMode.dynamic);
    expect(b2.columns, 4);
    expect(b2.ratio, 'original');
    expect(b2.bgColor, '#1e1b4b');
    expect(b2.images, hasLength(6));
    expect(b2.images[2].x, 700);
    expect(b2.images[2].y, 420);
    expect(b2.notes.single.text, 'Keep me');
    expect(b2.notes.single.color, '#fecaca');
    expect(b2.swatchGroups, hasLength(1));
    expect(b2.swatchGroups.single.colors, hasLength(5));
    expect(b2.orderedItems.map((OrderedBoardItem i) => i.order).toSet(), hasLength(7));

    // New items continue after the restored counters.
    final StickyNote next = b2.addStickyNote();
    expect(next.zIndex, greaterThan(b2.images.map((BoardImage i) => i.zIndex).reduce((int a, int b) => a > b ? a : b)));
  });

  testWidgets('corrupt state is cleared and ignored', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{storageKey: '{not json'});
    final PaletteController p = PaletteController();
    final BoardController b = BoardController();
    addTearDown(p.dispose);
    addTearDown(b.dispose);
    final AppPersistence persistence = await _make(p, b, MemoryBlobStore());
    final bool restored = await persistence.restore();
    expect(restored, isFalse);
    expect((await SharedPreferences.getInstance()).getString(storageKey), isNull);
  });

  testWidgets('unknown version is ignored without clearing', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{storageKey: '{"version":2}'});
    final PaletteController p = PaletteController();
    final BoardController b = BoardController();
    addTearDown(p.dispose);
    addTearDown(b.dispose);
    final AppPersistence persistence = await _make(p, b, MemoryBlobStore());
    expect(await persistence.restore(), isFalse);
  });

  testWidgets('attached persistence autosaves after the debounce', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final PaletteController p = PaletteController();
    final BoardController b = BoardController();
    addTearDown(p.dispose);
    addTearDown(b.dispose);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final AppPersistence persistence = AppPersistence(
      palette: p,
      board: b,
      prefs: prefs,
      blobs: MemoryBlobStore(),
      debounce: const Duration(milliseconds: 20),
    )..attach();
    addTearDown(persistence.dispose);

    await tester.runAsync(() async {
      b.setGutter(40);
      b.setGutter(41);
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    final Map<String, Object?> json =
        jsonDecode(prefs.getString(storageKey)!) as Map<String, Object?>;
    expect((json['moodboard']! as Map<String, Object?>)['gutter'], 41);
  });

  testWidgets('oversized payloads drop image sources but keep the layout', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final PaletteController p = PaletteController();
    final BoardController b = BoardController();
    addTearDown(p.dispose);
    addTearDown(b.dispose);
    await tester.runAsync(() async {
      await b.loadSampleBoard();
      final StickyNote note = b.addStickyNote();
      b.endEditingNote();
      b.updateNote(note.id, text: 'x' * (sizeSoftCap + 10));
      final AppPersistence persistence = await _make(p, b, MemoryBlobStore());
      await persistence.flush();
    });
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final Map<String, Object?> json =
        jsonDecode(prefs.getString(storageKey)!) as Map<String, Object?>;
    final List<Object?> images =
        (json['moodboard']! as Map<String, Object?>)['images']! as List<Object?>;
    expect(images, hasLength(6));
    expect(images.every((Object? i) => (i! as Map<String, Object?>)['src'] == null), isTrue);
  });
}
