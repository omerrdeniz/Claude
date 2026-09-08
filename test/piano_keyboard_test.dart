import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piano_flow/widgets/piano_keyboard.dart';

/// Pumps a keyboard of a known size so taps can be aimed at exact keys.
Future<List<(int, double)>> pumpKeyboard(
  WidgetTester tester, {
  int lowestNote = 60,
  int octaves = 2,
  List<int>? releases,
}) async {
  final presses = <(int, double)>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 700,
            height: 200,
            child: PianoKeyboard(
              lowestNote: lowestNote,
              octaves: octaves,
              onNoteOn: (midi, {velocity = 0.8}) => presses.add((midi, velocity)),
              onNoteOff: (midi) => releases?.add(midi),
            ),
          ),
        ),
      ),
    ),
  );
  return presses;
}

void main() {
  // 700px / 14 white keys = 50px per white key.
  const whiteWidth = 50.0;

  testWidgets('tapping the first white key plays middle C', (tester) async {
    final presses = await pumpKeyboard(tester);
    final origin = tester.getTopLeft(find.byType(PianoKeyboard));
    // Low on the key, clear of the black keys above.
    await tester.tapAt(origin + const Offset(whiteWidth * 0.5, 180));
    expect(presses.single.$1, 60);
  });

  testWidgets('white keys follow the major scale, skipping the black notes',
      (tester) async {
    final presses = await pumpKeyboard(tester);
    final origin = tester.getTopLeft(find.byType(PianoKeyboard));
    for (var i = 0; i < 8; i++) {
      await tester.tapAt(origin + Offset(whiteWidth * (i + 0.5), 180));
    }
    expect(presses.map((p) => p.$1).toList(), [60, 62, 64, 65, 67, 69, 71, 72]);
  });

  testWidgets('black keys sit between their white neighbours', (tester) async {
    final presses = await pumpKeyboard(tester);
    final origin = tester.getTopLeft(find.byType(PianoKeyboard));
    // C# is centred on the C/D boundary, near the top of the keyboard.
    await tester.tapAt(origin + const Offset(whiteWidth, 20));
    expect(presses.single.$1, 61);
  });

  testWidgets('there is no black key between E and F', (tester) async {
    final presses = await pumpKeyboard(tester);
    final origin = tester.getTopLeft(find.byType(PianoKeyboard));
    // The E/F boundary is at the third white key; tapping high there must
    // still land on a white key, because no black key exists there.
    await tester.tapAt(origin + const Offset(whiteWidth * 3 - 2, 20));
    expect(presses.single.$1, 64);
  });

  testWidgets('pressing lower on a key plays harder', (tester) async {
    final presses = await pumpKeyboard(tester);
    final origin = tester.getTopLeft(find.byType(PianoKeyboard));
    await tester.tapAt(origin + const Offset(whiteWidth * 0.5, 190));
    await tester.tapAt(origin + const Offset(whiteWidth * 0.5, 130));
    expect(presses[0].$2, greaterThan(presses[1].$2));
  });

  testWidgets('lifting a finger releases only that key', (tester) async {
    final releases = <int>[];
    final presses = await pumpKeyboard(tester, releases: releases);
    final origin = tester.getTopLeft(find.byType(PianoKeyboard));

    final first = await tester.startGesture(origin + const Offset(25, 180));
    final second = await tester.startGesture(origin + const Offset(75, 180));
    expect(presses.map((p) => p.$1).toList(), [60, 62]);

    await first.up();
    expect(releases, [60], reason: 'the held key must keep sounding');
    await second.up();
    expect(releases, [60, 62]);
  });

  testWidgets('sliding across keys glissandos', (tester) async {
    final releases = <int>[];
    final presses = await pumpKeyboard(tester, releases: releases);
    final origin = tester.getTopLeft(find.byType(PianoKeyboard));

    final gesture = await tester.startGesture(origin + const Offset(25, 180));
    await gesture.moveTo(origin + const Offset(75, 180));
    await gesture.moveTo(origin + const Offset(125, 180));
    await gesture.up();

    expect(presses.map((p) => p.$1).toList(), [60, 62, 64]);
    expect(releases, [60, 62, 64]);
  });

  testWidgets('the keyboard can start on a different octave', (tester) async {
    final presses = await pumpKeyboard(tester, lowestNote: 48, octaves: 2);
    final origin = tester.getTopLeft(find.byType(PianoKeyboard));
    await tester.tapAt(origin + const Offset(whiteWidth * 0.5, 180));
    expect(presses.single.$1, 48);
  });
}
