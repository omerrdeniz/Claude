import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piano_flow/data/song_library.dart';
import 'package:piano_flow/music/note.dart';
import 'package:piano_flow/music/song.dart';
import 'package:piano_flow/screens/play_screen.dart';

void main() {
  /// Pumping a fixed number of frames, rather than settling, because the
  /// playfield animates forever — pumpAndSettle would never return.
  Future<void> play(WidgetTester tester, Duration duration,
      {int frames = 10}) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(duration ~/ frames);
    }
  }

  testWidgets('shows the song being played', (tester) async {
    await tester.pumpWidget(MaterialApp(home: PlayScreen(song: SongLibrary.furElise)));
    expect(find.text('Für Elise'), findsOneWidget);
    expect(find.textContaining('Ludwig van Beethoven'), findsOneWidget);
    expect(find.text('0'), findsOneWidget, reason: 'the score starts at zero');
    await play(tester, const Duration(seconds: 1));
  });

  testWidgets('tapping a beam scores', (tester) async {
    await tester.pumpWidget(MaterialApp(home: PlayScreen(song: SongLibrary.odeToJoy)));
    // Let the first note travel down to the line.
    await play(tester, const Duration(milliseconds: 1900), frames: 40);

    final stage = tester.getRect(find.byType(PlayScreen));
    var scored = false;
    // Sweep the beams around the moment the note lands; one of them is right.
    for (var beam = 0; beam < 4 && !scored; beam++) {
      await tester.tapAt(Offset(
          stage.left + stage.width * (beam + 0.5) / 4, stage.center.dy));
      await tester.pump(const Duration(milliseconds: 16));
      scored = find.text('0').evaluate().isEmpty;
    }
    expect(scored, isTrue, reason: 'a tap on the right beam should score');
  });

  testWidgets('pause and resume are offered', (tester) async {
    await tester.pumpWidget(MaterialApp(home: PlayScreen(song: SongLibrary.furElise)));
    expect(find.byIcon(Icons.pause), findsOneWidget);

    await tester.tap(find.byIcon(Icons.pause));
    await tester.pump();
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);

    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pump();
    expect(find.byIcon(Icons.pause), findsOneWidget);
  });

  testWidgets('restarting puts the score back to zero', (tester) async {
    await tester.pumpWidget(MaterialApp(home: PlayScreen(song: SongLibrary.odeToJoy)));
    await play(tester, const Duration(milliseconds: 1900), frames: 40);
    for (var beam = 0; beam < 4; beam++) {
      final stage = tester.getRect(find.byType(PlayScreen));
      await tester.tapAt(Offset(
          stage.left + stage.width * (beam + 0.5) / 4, stage.center.dy));
      await tester.pump(const Duration(milliseconds: 16));
    }

    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pump();
    expect(find.text('0'), findsOneWidget);
  });

  testWidgets('runs a whole song without throwing', (tester) async {
    await tester.pumpWidget(
        MaterialApp(home: PlayScreen(song: SongLibrary.preludeInC)));
    // The prelude is sixteen beats at 72bpm, plus the lead-in.
    await play(tester, const Duration(seconds: 18), frames: 120);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the song ends on a result, not an empty stage', (tester) async {
    // A song of its own, so the test does not have to sit through a real one.
    final brief = Song(
      id: 'brief',
      title: 'Kısa',
      composer: 'Test',
      bpm: 120,
      notes: [
        Note(beat: 0, midi: 60, duration: 0.5),
        Note(beat: 1, midi: 62, duration: 0.5),
      ],
    );
    await tester.pumpWidget(MaterialApp(home: PlayScreen(song: brief)));
    await play(tester, const Duration(seconds: 8), frames: 60);
    expect(find.text('Tekrar çal'), findsOneWidget);
    expect(find.text('İsabet'), findsOneWidget);
  });

  testWidgets('a finger can press and lift without anything breaking',
      (tester) async {
    // The lift is what ends a held note, so the wiring for it has to exist.
    await tester.pumpWidget(MaterialApp(
        home: PlayScreen(song: SongLibrary.odeToJoy)));
    await play(tester, const Duration(milliseconds: 2200), frames: 40);

    final stage = tester.getRect(find.byType(PlayScreen));
    final gesture = await tester.startGesture(stage.center);
    await tester.pump(const Duration(milliseconds: 300));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
  });

  testWidgets('both sides of the screen accept a finger', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: PlayScreen(song: SongLibrary.odeToJoy)));
    await play(tester, const Duration(milliseconds: 2200), frames: 40);

    final stage = tester.getRect(find.byType(PlayScreen));
    final left = await tester.startGesture(
        Offset(stage.left + stage.width * 0.25, stage.center.dy));
    final right = await tester.startGesture(
        Offset(stage.left + stage.width * 0.75, stage.center.dy));
    await tester.pump(const Duration(milliseconds: 60));
    await left.up();
    await right.up();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('leaving the screen shuts the game down cleanly', (tester) async {
    await tester.pumpWidget(MaterialApp(home: PlayScreen(song: SongLibrary.furElise)));
    await play(tester, const Duration(seconds: 2));
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    expect(tester.takeException(), isNull);
  });
}
