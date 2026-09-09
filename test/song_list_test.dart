import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piano_flow/data/song_library.dart';
import 'package:piano_flow/game/chart.dart';
import 'package:piano_flow/screens/play_screen.dart';
import 'package:piano_flow/screens/song_list_screen.dart';

void main() {
  testWidgets('lists every song, none of them locked', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SongListScreen()));
    for (final song in SongLibrary.all) {
      expect(find.text(song.title), findsOneWidget);
      // Two of the three are Beethoven, so a composer may appear more than once.
      expect(find.text(song.composer), findsAtLeastNWidgets(1));
    }
    expect(find.byIcon(Icons.lock), findsNothing);
  });

  testWidgets('offers every difficulty and speed by name', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SongListScreen()));
    for (final difficulty in Difficulty.values) {
      expect(find.text(difficulty.label), findsOneWidget);
    }
    for (final label in ['%40', '%60', '%80', 'Tam hız']) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('no label leaks raw code', (tester) async {
    // A mis-escaped string once shipped '%${(speed * 100).round()}' to the
    // screen; nothing the player reads should contain source code.
    await tester.pumpWidget(const MaterialApp(home: SongListScreen()));
    for (final text in tester.widgetList<Text>(find.byType(Text))) {
      final value = text.data ?? '';
      expect(value.contains(r'$'), isFalse, reason: 'raw code in "$value"');
      expect(value.contains('{'), isFalse, reason: 'raw code in "$value"');
    }
  });

  testWidgets('tapping a song opens the playfield', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SongListScreen()));
    await tester.tap(find.text('Für Elise'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(PlayScreen), findsOneWidget);
  });

  testWidgets('the chosen difficulty and speed reach the playfield',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SongListScreen()));
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
  });
}
