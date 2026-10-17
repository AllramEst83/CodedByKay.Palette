import 'package:flutter_test/flutter_test.dart';
import 'package:palette_app/core/grid_layout.dart';
import 'package:palette_app/models/board_models.dart';
import 'package:palette_app/services/image_service.dart';
import 'package:palette_app/state/board_controller.dart';
import 'package:palette_app/ui/painters/board_painters.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<BoardController> sampleBoard(WidgetTester tester) async {
    final BoardController b = BoardController();
    addTearDown(b.dispose);
    await tester.runAsync(b.loadSampleBoard);
    return b;
  }

  testWidgets('sample board adds six ordered images', (WidgetTester tester) async {
    final BoardController b = await sampleBoard(tester);
    expect(b.images, hasLength(6));
    expect(b.orderedItems.map((OrderedBoardItem i) => i.order), <int>[1, 2, 3, 4, 5, 6]);
    expect(b.loading, isFalse);
  });

  testWidgets('moveItem swaps order with its neighbor and respects bounds', (WidgetTester tester) async {
    final BoardController b = await sampleBoard(tester);
    final String first = b.orderedItems.first.id;
    final String second = b.orderedItems[1].id;
    b.moveItem(first, 1);
    expect(b.orderedItems[0].id, second);
    expect(b.orderedItems[1].id, first);
    b.moveItem(second, -1); // already first
    expect(b.orderedItems[0].id, second);
  });

  testWidgets('selection, removal and clear', (WidgetTester tester) async {
    final BoardController b = await sampleBoard(tester);
    final String id = b.images.first.id;
    b.select(id);
    expect(b.selectedImage?.id, id);
    b.removeImage(id);
    expect(b.selectedId, isNull);
    expect(b.images, hasLength(5));
    b.clear();
    expect(b.isEmpty, isTrue);
  });

  testWidgets('dynamic-mode images keep their aspect ratio, grid-mode use cascade size',
      (WidgetTester tester) async {
    final BoardController b = await sampleBoard(tester);
    expect(b.images.first.w, 260);
    expect(b.images.first.h, 200);
    b.setMode(BoardMode.dynamic);
    final image = b.images.first.image;
    final BoardImage added = b.addDecodedImage(image, 'square');
    expect(added.w, 260);
    expect(added.h, 260); // 1:1 source
  });

  testWidgets('extract in dynamic mode adds a collision-free swatch group', (WidgetTester tester) async {
    final BoardController b = await sampleBoard(tester);
    b.setMode(BoardMode.dynamic);
    b.select(b.images.first.id);
    await tester.runAsync(b.extractSelectedPalette);
    expect(b.swatchGroups, hasLength(1));
    final SwatchGroup g = b.swatchGroups.single;
    expect(g.colors, hasLength(5));
    expect(b.selectedId, g.id);
    for (final BoardItem other in <BoardItem>[...b.images, ...b.notes]) {
      final bool overlap = g.x < other.x + other.w &&
          g.x + g.w > other.x &&
          g.y < other.y + other.h &&
          g.y + g.h > other.y;
      expect(overlap, isFalse, reason: 'overlaps ${other.id}');
    }
  });

  testWidgets('extract in grid mode only fills the extracted list', (WidgetTester tester) async {
    final BoardController b = await sampleBoard(tester);
    b.select(b.images.first.id);
    await tester.runAsync(b.extractSelectedPalette);
    expect(b.swatchGroups, isEmpty);
    expect(b.extractedColors, hasLength(5));
  });

  testWidgets('sticky notes can be added, recolored and removed', (WidgetTester tester) async {
    final BoardController b = BoardController();
    addTearDown(b.dispose);
    final StickyNote n = b.addStickyNote();
    expect(b.selectedId, n.id);
    b.updateNote(n.id, text: 'Hello', color: '#fecaca');
    expect(b.notes.single.text, 'Hello');
    expect(b.notes.single.color, '#fecaca');
    b.removeNote(n.id);
    expect(b.notes, isEmpty);
  });

  testWidgets('grid plan and PNG export for every ratio', (WidgetTester tester) async {
    final BoardController b = await sampleBoard(tester);
    for (final String ratio in gridRatios) {
      b.setRatio(ratio);
      final GridBoardPlan? plan = GridBoardPlan.from(b);
      expect(plan, isNotNull, reason: ratio);
      expect(plan!.pixelWidth, 1920);
      expect(plan.pixelHeight, greaterThan(0));
      final bytes = await tester.runAsync(
        () => ImageService.renderToPng(plan.pixelWidth, plan.pixelHeight, plan.paint),
      );
      // PNG signature.
      expect(bytes!.sublist(0, 4), <int>[0x89, 0x50, 0x4E, 0x47], reason: ratio);
    }
  });

  testWidgets('dynamic export renders the full canvas', (WidgetTester tester) async {
    final BoardController b = await sampleBoard(tester);
    b.addStickyNote();
    final bytes = await tester.runAsync(
      () => ImageService.renderToPng(1600, 1000, DynamicBoardRenderer(b).paint),
    );
    expect(bytes!.sublist(0, 4), <int>[0x89, 0x50, 0x4E, 0x47]);
  });

  test('settings round trip clamps invalid numbers', () {
    final BoardController b = BoardController();
    addTearDown(b.dispose);
    b.applySettings(<String, Object?>{
      'mode': 'dynamic',
      'columns': 99,
      'gutter': -5,
      'radius': 12,
      'ratio': '16:9',
      'bgColor': '#ffffff',
    });
    expect(b.mode, BoardMode.dynamic);
    expect(b.columns, 5);
    expect(b.gutter, 0);
    expect(b.ratio, '16:9');
    expect(b.settingsToJson()['bgColor'], '#ffffff');
  });
}
