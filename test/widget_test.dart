import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piano_flow/app.dart';

void main() {
  testWidgets('app boots and lists its songs', (tester) async {
    await tester.pumpWidget(const PianoFlowApp());
    expect(find.text('Piano Flow'), findsOneWidget);

    // Scrolled for, not required to be on screen: the settings above the list
    // are taller than the default test window, which is far shorter than any
    // phone. What a phone actually shows is the test below.
    await tester.scrollUntilVisible(find.text('Für Elise'), 200);
    expect(find.text('Für Elise'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Neşeye Övgü'), -200);
    expect(find.text('Neşeye Övgü'), findsOneWidget);
  });

  testWidgets('a phone shows a song without scrolling', (tester) async {
    // The settings are a preamble, not the point of the screen. If they grow
    // enough to push every song under the fold, the game opens on a form.
    tester.view.physicalSize = const Size(390 * 3, 844 * 3); // a common phone
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const PianoFlowApp());
    await tester.pumpAndSettle();

    expect(find.text('Neşeye Övgü'), findsOneWidget,
        reason: 'the first song has to be visible when the screen opens');
  });
}
