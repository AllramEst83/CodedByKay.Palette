import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palette_app/main.dart';
import 'package:palette_app/state/palette_controller.dart';

Future<void> _pumpAt(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(PaletteApp(paletteController: PaletteController()));
  await tester.pump();
}

void main() {
  testWidgets('phone layout: bottom navigation and controls button', (WidgetTester tester) async {
    await _pumpAt(tester, const Size(390, 800));
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Extract a color palette'), findsOneWidget);
    expect(find.text('Palette controls'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tablet portrait: rail plus collapsible bottom panel', (WidgetTester tester) async {
    await _pumpAt(tester, const Size(800, 1200));
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.text('NUMBER OF COLORS'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tablet landscape: rail plus side panel', (WidgetTester tester) async {
    await _pumpAt(tester, const Size(1000, 700));
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.text('NUMBER OF COLORS'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide layout: top tabs and side panel', (WidgetTester tester) async {
    await _pumpAt(tester, const Size(1400, 900));
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('Mood Board'), findsOneWidget);
    expect(find.text('NUMBER OF COLORS'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rotation keeps the selected tab', (WidgetTester tester) async {
    await _pumpAt(tester, const Size(800, 1200));
    await tester.tap(find.text('Mood Board'));
    await tester.pump();
    tester.view.physicalSize = const Size(1200, 800);
    await tester.pump();
    expect(find.text('Build a mood board'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
