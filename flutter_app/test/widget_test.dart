import 'package:flutter_test/flutter_test.dart';
import 'package:palette_app/main.dart';

void main() {
  testWidgets('app boots', (WidgetTester tester) async {
    await tester.pumpWidget(const PaletteApp());
    expect(find.text('Palette & MoodBoard'), findsOneWidget);
  });
}
