import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piano_flow/data/song_library.dart';
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

  testWidgets('tapping a song opens the playfield', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SongListScreen()));
    await tester.tap(find.text('Für Elise'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(PlayScreen), findsOneWidget);
  });
}
