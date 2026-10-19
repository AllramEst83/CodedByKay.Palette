import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palette_app/main.dart';
import 'package:palette_app/models/board_models.dart';
import 'package:palette_app/state/board_controller.dart';
import 'package:palette_app/state/palette_controller.dart';

const Map<String, Size> _sizes = <String, Size>{
  'phone portrait': Size(360, 800),
  'phone landscape': Size(800, 360),
  'small tablet portrait': Size(600, 960),
  'small tablet landscape': Size(960, 600),
  'large tablet portrait': Size(800, 1280),
  'large tablet landscape': Size(1280, 800),
  'desktop web': Size(1600, 900),
};

void main() {
  for (final MapEntry<String, Size> entry in _sizes.entries) {
    testWidgets('no overflow with content at ${entry.key}', (WidgetTester tester) async {
      tester.view.physicalSize = entry.value;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final PaletteController palette = PaletteController(extractDebounce: Duration.zero);
      final BoardController board = BoardController();
      addTearDown(palette.dispose);
      addTearDown(board.dispose);
      await tester.runAsync(() async {
        await palette.loadSample();
        await board.loadSampleBoard();
      });

      await tester.pumpWidget(PaletteApp(paletteController: palette, boardController: board));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'palette tab');

      // Open the controls sheet on narrow layouts.
      if (find.text('Palette controls').evaluate().isNotEmpty &&
          find.byType(FilledButton).evaluate().isNotEmpty &&
          find.text('NUMBER OF COLORS').evaluate().isEmpty) {
        await tester.tap(find.text('Palette controls'));
        await tester.pumpAndSettle();
        expect(find.text('NUMBER OF COLORS'), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'palette sheet');
        await tester.tapAt(const Offset(2, 2)); // dismiss
        await tester.pumpAndSettle();
      }

      await tester.tap(find.text('Mood Board').first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'grid board');

      board.setMode(BoardMode.dynamic);
      board.addStickyNote();
      board.endEditingNote();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'dynamic board');
    });
  }
}
