import 'package:flutter_test/flutter_test.dart';
import 'package:smartcut/main.dart';

void main() {
  testWidgets('SmartCut app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const SmartCutApp());
    expect(find.text('SmartCut'), findsOneWidget);
  });
}
