import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piano_flow/widgets/song_progress.dart';

void main() {
  group('the clock', () {
    test('reads as minutes and whole seconds', () {
      expect(clockOf(0), '0:00');
      expect(clockOf(9), '0:09');
      expect(clockOf(63), '1:03');
      expect(clockOf(163.8), '2:43');
    });

    test('never goes backwards past zero', () {
      // The song clock starts a lead-in *before* the first note, so it is
      // negative for the first two seconds of every performance.
      expect(clockOf(-1.9), '0:00');
    });
  });

  group('the progress bar', () {
    /// The two halves of the bar, filled first.
    Future<List<int>> flexesFor(WidgetTester tester, double through) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SongProgressBar(through: through)),
        ),
      );
      return tester
          .widgetList<Expanded>(find.byType(Expanded))
          .map((e) => e.flex)
          .toList();
    }

    testWidgets('is empty at the start', (tester) async {
      expect(await flexesFor(tester, 0), [0, 1000]);
    });

    testWidgets('fills from the left as the song goes by', (tester) async {
      expect(await flexesFor(tester, 0.25), [250, 750]);
      expect(await flexesFor(tester, 0.5), [500, 500]);
    });

    testWidgets('is full at the end and no fuller', (tester) async {
      expect(await flexesFor(tester, 1), [1000, 0]);
      expect(await flexesFor(tester, 1.4), [1000, 0]);
    });

    testWidgets('and is not negative during the lead-in', (tester) async {
      // Before the first note the song clock is still negative.
      expect(await flexesFor(tester, -0.02), [0, 1000]);
    });
  });
}
