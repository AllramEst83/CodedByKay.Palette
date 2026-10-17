import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palette_app/core/dynamic_layout.dart';
import 'package:palette_app/models/board_models.dart';
import 'package:palette_app/state/board_controller.dart';
import 'package:palette_app/ui/moodboard/dynamic_board_view.dart';
import 'package:provider/provider.dart';

Future<BoardController> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1700, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final BoardController board = BoardController()..mode = BoardMode.dynamic;
  addTearDown(board.dispose);
  await tester.runAsync(board.loadSampleBoard);
  await tester.pumpWidget(
    ChangeNotifierProvider<BoardController>.value(
      value: board,
      child: const MaterialApp(home: Scaffold(body: DynamicBoardView())),
    ),
  );
  await tester.pump();
  return board;
}

void main() {
  testWidgets('dragging an item moves it, selects it and brings it to front', (WidgetTester tester) async {
    final BoardController board = await _pump(tester);
    final BoardImage first = board.images.first;
    final double x0 = first.x;
    final int z0 = first.zIndex;

    final Finder target = find.bySemanticsLabel(first.name);
    expect(target, findsOneWidget);
    await tester.drag(target, const Offset(100, 60));
    await tester.pump();

    expect(first.x, greaterThan(x0));
    expect(board.selectedId, first.id);
    expect(first.zIndex, greaterThan(z0));
  });

  testWidgets('dragging far outside the canvas clamps to the bounds', (WidgetTester tester) async {
    final BoardController board = await _pump(tester);
    final BoardImage first = board.images.first;
    await tester.drag(find.bySemanticsLabel(first.name), const Offset(-5000, -5000));
    await tester.pump();
    expect(first.x, 0);
    expect(first.y, 0);
  });

  testWidgets('arrow keys nudge the selected item and Escape deselects', (WidgetTester tester) async {
    final BoardController board = await _pump(tester);
    final BoardImage first = board.images.first;
    await tester.tap(find.bySemanticsLabel(first.name));
    await tester.pump();
    final double x0 = first.x;

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(first.x, x0 + 4);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(first.x, x0 + 24);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(board.selectedId, isNull);
  });

  testWidgets('sticky note: add, edit text, recolor, delete', (WidgetTester tester) async {
    final BoardController board = await _pump(tester);
    final StickyNote note = board.addStickyNote();
    await tester.pump();
    await tester.pump();

    expect(board.editingNoteId, note.id);
    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Remember this');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(note.text, 'Remember this');
    expect(board.editingNoteId, isNull);

    await tester.tap(find.bySemanticsLabel('Set note color #bfdbfe'));
    await tester.pump();
    expect(note.color, '#bfdbfe');

    await tester.tap(find.byTooltip('Delete note'));
    await tester.pump();
    expect(board.notes, isEmpty);
  });

  testWidgets('resize handle grows a note but never past the canvas', (WidgetTester tester) async {
    final BoardController board = await _pump(tester);
    final StickyNote note = board.addStickyNote();
    board.endEditingNote();
    await tester.pump();

    final double w0 = note.w;
    await tester.drag(find.bySemanticsLabel('Resize handle'), const Offset(60, 40));
    await tester.pump();
    expect(note.w, greaterThan(w0));

    await tester.drag(find.bySemanticsLabel('Resize handle'), const Offset(5000, 5000));
    await tester.pump();
    expect(note.x + note.w, lessThanOrEqualTo(dynamicCanvasW));
    expect(note.y + note.h, lessThanOrEqualTo(dynamicCanvasH));
  });

  testWidgets('tapping the empty canvas clears the selection', (WidgetTester tester) async {
    final BoardController board = await _pump(tester);
    board.select(board.images.first.id);
    await tester.pump();
    // Bottom-right of the canvas is empty (six images cascade top-left).
    await tester.tapAt(const Offset(1500, 1000));
    await tester.pump();
    expect(board.selectedId, isNull);
  });
}
