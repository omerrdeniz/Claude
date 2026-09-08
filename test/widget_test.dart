import 'package:flutter_test/flutter_test.dart';
import 'package:piano_flow/app.dart';

void main() {
  testWidgets('app boots and shows its name', (tester) async {
    await tester.pumpWidget(const PianoFlowApp());
    expect(find.text('Für Elise'), findsOneWidget);
  });
}
