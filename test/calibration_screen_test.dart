import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piano_flow/screens/calibration_screen.dart';
import 'package:piano_flow/screens/song_list_screen.dart';

/// A clock the test moves by hand, in step with `pump`.
///
/// The screen reads the time itself rather than taking the frame's, so a
/// test has to supply one; a real Stopwatch would not move at all here.
class FakeClock {
  double ms = 0;
  double read() => ms;
}

/// Let the clicks run for [ms], tapping once every [everyMs] at [lateMs]
/// after each click the screen puts out.
Future<void> tapAlong(
  WidgetTester tester,
  FakeClock clock, {
  required int ms,
  int everyMs = 100,
}) async {
  for (var t = 0; t < ms; t += everyMs) {
    clock.ms += everyMs;
    await tester.pump(Duration(milliseconds: everyMs));
    await tester.tapAt(tester.getCenter(find.byType(CalibrationScreen)));
  }
}

Widget screenUnder(FakeClock clock) =>
    MaterialApp(home: CalibrationScreen(nowMs: clock.read));

/// Let a route transition finish.
///
/// Not `pumpAndSettle`: the calibration screen runs a ticker for as long as
/// it is up, so nothing ever settles and that would only time out.
Future<void> settleRoute(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('asks the player to answer the sound, not the screen',
      (tester) async {
    await tester.pumpWidget(screenUnder(FakeClock()));
    await tester.pump();

    expect(find.text('Zamanlama ölçümü'), findsOneWidget);
    expect(find.textContaining('sese uy'), findsOneWidget);
    expect(find.textContaining('En az sekiz'), findsOneWidget);
    // Nothing to offer before anything has been measured.
    expect(find.textContaining('Kullan'), findsNothing);
  });

  testWidgets('counts taps and ends with a number to use', (tester) async {
    final clock = FakeClock();
    await tester.pumpWidget(screenUnder(clock));
    await tester.pump();

    // Long enough for the lead-in and well over sixteen clicks.
    await tapAlong(tester, clock, ms: 14000, everyMs: 200);
    await tester.pump();

    expect(find.textContaining('Ölçülen gecikme'), findsOneWidget);
    expect(find.textContaining('Kullan'), findsOneWidget);
  });

  testWidgets('hands the measurement back to whoever asked for it',
      (tester) async {
    final clock = FakeClock();
    double? returned;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            returned = await Navigator.of(context).push<double>(
              MaterialPageRoute(
                  builder: (_) => CalibrationScreen(nowMs: clock.read)),
            );
          },
          child: const Text('ölç'),
        ),
      ),
    ));

    await tester.tap(find.text('ölç'));
    await settleRoute(tester);
    await tapAlong(tester, clock, ms: 14000, everyMs: 200);
    await tester.pump();

    await tester.tap(find.textContaining('Kullan'));
    await settleRoute(tester);
    expect(returned, isNotNull);
  });

  testWidgets('backing out returns nothing rather than a wrong number',
      (tester) async {
    double? returned = 999;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            returned = await Navigator.of(context).push<double>(
              MaterialPageRoute(builder: (_) => const CalibrationScreen()),
            );
          },
          child: const Text('ölç'),
        ),
      ),
    ));

    await tester.tap(find.text('ölç'));
    await settleRoute(tester);
    await tester.tap(find.text('Vazgeç'));
    await settleRoute(tester);
    expect(returned, isNull);
  });

  testWidgets('starting over clears what was collected', (tester) async {
    final clock = FakeClock();
    await tester.pumpWidget(screenUnder(clock));
    await tester.pump();
    await tapAlong(tester, clock, ms: 6000, everyMs: 200);
    await tester.pump();

    expect(find.text('0 / 16'), findsNothing);
    await tester.tap(find.text('Baştan'));
    await tester.pump();
    expect(find.text('0 / 16'), findsOneWidget);
  });

  testWidgets('the song list can reach it', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SongListScreen()));
    await tester.pump();

    await tester.scrollUntilVisible(find.text('Ölç'), 200);
    await tester.tap(find.text('Ölç'));
    await settleRoute(tester);
    expect(find.byType(CalibrationScreen), findsOneWidget);
  });
}
