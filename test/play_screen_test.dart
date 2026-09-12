import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piano_flow/game/chart.dart';
import 'package:piano_flow/music/note.dart';
import 'package:piano_flow/music/song.dart';
import 'package:piano_flow/game/play_settings.dart';
import 'package:piano_flow/screens/play_screen.dart';

import 'support/library.dart';

void main() {
  /// The number on the scoreboard.
  int scoreOf(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => int.tryParse(t.data ?? ''))
      .firstWhere((n) => n != null, orElse: () => 0)!;

  /// Pumping a fixed number of frames, rather than settling, because the
  /// playfield animates forever — pumpAndSettle would never return.
  Future<void> play(WidgetTester tester, Duration duration,
      {int frames = 10}) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(duration ~/ frames);
    }
  }

  group('an ornament is earned by staying on it', () {
    // One ornamented note with the hand free afterwards, so the whole of the
    // hold is the player's to give.
    final ornamented = Song(
      id: 't',
      title: 'T',
      composer: '',
      bpm: 100,
      notes: [
        Note(beat: 1.895, midi: 72, duration: 0.105, hand: Hand.right),
        Note(beat: 2.0, midi: 71, duration: 1.75, hand: Hand.right),
      ],
    );

    /// Play the note, keeping the finger down for [ms], and give back the
    /// score. Written through the screen on purpose: the session was right
    /// about all of this while the screen was still throwing it away, and
    /// only a test that presses a real finger could tell.
    Future<int> scoreAfterHolding(WidgetTester tester, int ms,
        {required int run}) async {
      await tester.pumpWidget(MaterialApp(
          home: PlayScreen(
              // A fresh key, or the framework keeps the old State — and with
              // it a song that has already finished.
              key: ValueKey(run),
              song: ornamented,
              settings: const PlaySettings())));
      // Bring the note to the line: two beats at 100, after the lead-in.
      await play(tester, const Duration(milliseconds: 3100), frames: 60);

      final stage = tester.getRect(find.byType(PlayScreen));
      final target =
          Chart.build(ornamented).taps.firstWhere((t) => t.hasGrace);
      final finger = await tester.startGesture(
          Offset(stage.left + stage.width * target.across, stage.center.dy));
      await play(tester, Duration(milliseconds: ms), frames: 8);
      await finger.up();
      await play(tester, const Duration(milliseconds: 400), frames: 8);
      return scoreOf(tester);
    }

    testWidgets('a press and a release is not staying', (tester) async {
      final quick = await scoreAfterHolding(tester, 120, run: 1);
      final stayed = await scoreAfterHolding(tester, 1000, run: 2);
      expect(quick, greaterThan(0), reason: 'the note itself still scores');
      expect(stayed, greaterThan(quick),
          reason: 'staying on it is what earns the ornament');
    });

    testWidgets('and neither is most of a tap', (tester) async {
      // Three tenths of a second was the first threshold and it was too
      // short: a hand resting in time with a slow piece stays about that
      // long, so a press and a stay came out the same. The note itself is
      // asked for most of its own length now.
      final resting = await scoreAfterHolding(tester, 500, run: 3);
      final stayed = await scoreAfterHolding(tester, 1000, run: 4);
      expect(resting, lessThan(stayed));
    });
  });

  testWidgets('shows the song being played', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: PlayScreen(
            song: shipped('fur-elise'), settings: const PlaySettings())));
    expect(find.text('Für Elise'), findsOneWidget);
    expect(find.textContaining('Ludwig van Beethoven'), findsOneWidget);
    expect(find.text('0'), findsOneWidget, reason: 'the score starts at zero');
    await play(tester, const Duration(seconds: 1));
  });

  testWidgets('tapping a beam scores', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: PlayScreen(
            song: shipped('ode-to-joy'), settings: const PlaySettings())));
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

  testWidgets('following a run plays notes no finger could tap',
      (tester) async {
    // Twelve notes an eighth of a second apart, rising a semitone at a time,
    // all in the right hand. The chart spreads them across that hand's zone,
    // so playing them means walking a finger across it.
    final song = Song(
      id: 'run',
      title: 'Run',
      composer: '',
      bpm: 120,
      notes: [
        for (var i = 0; i < 12; i++)
          Note(beat: i * 0.25, midi: 72 + i, duration: 0.25),
      ],
    );
    await tester.pumpWidget(MaterialApp(
        home: PlayScreen(song: song, settings: const PlaySettings())));
    // Let the first note travel down to the line.
    await play(tester, const Duration(milliseconds: 1900), frames: 40);

    final stage = tester.getRect(find.byType(PlayScreen));
    // Where the chart puts note i, in this widget's own coordinates.
    double xOf(int i) =>
        stage.left +
        stage.width *
            (Chart.rightZoneStart +
                (Chart.rightZoneEnd - Chart.rightZoneStart) * i / 11);

    final finger = await tester.startGesture(Offset(xOf(0), stage.center.dy));
    await tester.pump(const Duration(milliseconds: 16));
    final afterOneTouch = scoreOf(tester);
    expect(afterOneTouch, greaterThan(0), reason: 'the run was never joined');

    // Walk with it, one note at a time, without ever lifting.
    for (var i = 1; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 125));
      await finger.moveTo(Offset(xOf(i), stage.center.dy));
      await tester.pump(const Duration(milliseconds: 4));
    }
    await finger.up();
    await tester.pump();

    expect(scoreOf(tester), greaterThan(afterOneTouch * 4),
        reason: 'the run did not follow the finger');
  });

  testWidgets('pause and resume are offered', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: PlayScreen(
            song: shipped('fur-elise'), settings: const PlaySettings())));
    expect(find.byIcon(Icons.pause), findsOneWidget);

    await tester.tap(find.byIcon(Icons.pause));
    await tester.pump();
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);

    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pump();
    expect(find.byIcon(Icons.pause), findsOneWidget);
  });

  testWidgets('restarting puts the score back to zero', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: PlayScreen(
            song: shipped('ode-to-joy'), settings: const PlaySettings())));
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
        MaterialApp(
            home: PlayScreen(
                song: shipped('prelude-in-c'),
                settings: const PlaySettings())));
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
    await tester.pumpWidget(MaterialApp(
        home: PlayScreen(song: brief, settings: const PlaySettings())));
    await play(tester, const Duration(seconds: 8), frames: 60);
    expect(find.text('Tekrar çal'), findsOneWidget);
    expect(find.text('İsabet'), findsOneWidget);
  });

  testWidgets('a finger can press and lift without anything breaking',
      (tester) async {
    // The lift is what ends a held note, so the wiring for it has to exist.
    await tester.pumpWidget(MaterialApp(
        home: PlayScreen(
            song: shipped('ode-to-joy'),
            settings: const PlaySettings(speed: 0.6))));
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
        home: PlayScreen(
            song: shipped('ode-to-joy'),
            settings: const PlaySettings(speed: 0.6))));
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
    await tester.pumpWidget(MaterialApp(
        home: PlayScreen(
            song: shipped('fur-elise'), settings: const PlaySettings())));
    await play(tester, const Duration(seconds: 2));
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    expect(tester.takeException(), isNull);
  });
}
