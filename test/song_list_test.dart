import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piano_flow/data/song_library.dart';
import 'package:piano_flow/game/chart.dart';
import 'package:piano_flow/game/judgement.dart';
import 'package:piano_flow/screens/play_screen.dart';
import 'package:piano_flow/screens/song_list_screen.dart';

void main() {
  /// A tall surface, so the whole list fits without scrolling.
  Future<void> pumpList(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: SongListScreen()));
  }

  testWidgets('lists every song, none of them locked', (tester) async {
    await pumpList(tester);
    for (final song in SongLibrary.all) {
      expect(find.text(song.title), findsOneWidget);
      // Two of the three are Beethoven, so a composer may appear more than once.
      expect(find.text(song.composer), findsAtLeastNWidgets(1));
    }
    expect(find.byIcon(Icons.lock), findsNothing);
  });

  testWidgets('offers every difficulty, speed and tolerance', (tester) async {
    await pumpList(tester);
    // 'Normal' names both a difficulty and a tolerance, so these are counted
    // rather than required to be unique.
    for (final difficulty in Difficulty.values) {
      expect(find.text(difficulty.label), findsAtLeastNWidgets(1));
    }
    for (final tolerance in TimingTolerance.values) {
      expect(find.text(tolerance.label), findsAtLeastNWidgets(1));
    }
    for (final label in ['%40', '%60', '%80', 'Tam hız']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('Notalar tam zamanında çalsın'), findsOneWidget);
    expect(find.text('Zamanlama ayarı'), findsOneWidget);
  });

  testWidgets('no label leaks raw code', (tester) async {
    // A mis-escaped string once shipped '%${(speed * 100).round()}' to the
    // screen; nothing the player reads should contain source code.
    await pumpList(tester);
    for (final text in tester.widgetList<Text>(find.byType(Text))) {
      final value = text.data ?? '';
      expect(value.contains(r'$'), isFalse, reason: 'raw code in "$value"');
      expect(value.contains('{'), isFalse, reason: 'raw code in "$value"');
    }
  });

  testWidgets('tapping a song opens the playfield', (tester) async {
    await pumpList(tester);
    await tester.tap(find.text('Für Elise'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(PlayScreen), findsOneWidget);
  });

  testWidgets('every chosen setting reaches the playfield', (tester) async {
    await pumpList(tester);
    // Tapping the chip itself rather than the label inside it.
    await tester.tap(find.ancestor(
        of: find.text('Zor'), matching: find.byType(InkWell)));
    await tester.pump();
    await tester.tap(find.ancestor(
        of: find.text('%40'), matching: find.byType(InkWell)));
    await tester.pump();
    await tester.tap(find.text('Neşeye Övgü'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final screen = tester.widget<PlayScreen>(find.byType(PlayScreen));
    expect(screen.difficulty, Difficulty.hard);
    expect(screen.speed, 0.4);
    expect(screen.tolerance, TimingTolerance.wide, reason: 'the default');
    expect(screen.quantize, isTrue, reason: 'the default');
    expect(screen.latencyOffsetMs, 0, reason: 'the default');
  });

  testWidgets('the timing settings reach the playfield too', (tester) async {
    await pumpList(tester);
    await tester.tap(find.text(TimingTolerance.tight.label));
    await tester.pump();
    await tester.tap(find.byType(Switch));
    await tester.pump();
    await tester.tap(find.text('Für Elise'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final screen = tester.widget<PlayScreen>(find.byType(PlayScreen));
    expect(screen.tolerance, TimingTolerance.tight);
    expect(screen.quantize, isFalse);
  });

  testWidgets('the timing calibration reaches the game', (tester) async {
    // Every setting on this screen has been forgotten on the way to the game
    // at least once. This one matters more than most: it is what a player
    // reaches for when nothing they do registers.
    await pumpList(tester);
    await tester.scrollUntilVisible(find.text('Zamanlama ayarı'), 200);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
    }
    expect(find.text('+30 ms'), findsOneWidget);
    expect(find.text('Dokunuşların 30 ms erken sayılıyor'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Neşeye Övgü'), 200);
    await tester.tap(find.text('Neşeye Övgü'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.widget<PlayScreen>(find.byType(PlayScreen)).latencyOffsetMs,
        30);
  });
}
