import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piano_flow/data/song_library.dart';
import 'package:piano_flow/game/chart.dart';
import 'package:piano_flow/game/judgement.dart';
import 'package:piano_flow/screens/play_screen.dart';
import 'package:piano_flow/screens/song_list_screen.dart';

void main() {
  /// Named from the catalogue: the library is long enough now that writing a
  /// song's name into a test is writing down which one happens to be first.
  final firstSong = SongLibrary.all.first.title;

  /// A tall surface, so most of the list fits without scrolling.
  Future<void> pumpList(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: SongListScreen()));
  }

  /// Scroll to a song and open it.
  ///
  /// [scrollUntilVisible] stops as soon as the widget is built, which is not
  /// the same as being on screen: a row hanging over the bottom edge is
  /// found and cannot be tapped. Every song added pushes one more row over
  /// that edge, so this ends with [ensureVisible] rather than trusting the
  /// list to be short.
  Future<void> openSong(WidgetTester tester, String title) async {
    final song = find.text(title);
    await tester.scrollUntilVisible(song, 120,
        scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(song);
    await tester.pumpAndSettle();
    await tester.tap(song);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('lists every song, none of them locked', (tester) async {
    await pumpList(tester);
    // Scrolled to, not just looked for: the library is past the point where
    // it fits on a phone screen, and a list view only builds what is on it.
    // This is the first test that would quietly stop checking the last song
    // as songs are added.
    for (final song in SongLibrary.all) {
      await tester.scrollUntilVisible(find.text(song.title), 120,
          scrollable: find.byType(Scrollable).first);
      expect(find.text(song.title), findsOneWidget);
      // Beethoven wrote two of them, so a composer may appear more than once.
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
    expect(find.text('Kaçırdıklarım da duyulsun'), findsOneWidget);
    expect(find.text('Zamanlama ayarı'), findsOneWidget);
  });

  testWidgets('the build says which one it is', (tester) async {
    // The player reads this back when a fix does not seem to have arrived.
    // Without it there is no way to tell a fix that did not work from a fix
    // that never reached the phone.
    await pumpList(tester);
    expect(versionLabel, isNotEmpty);
    expect(find.text(versionLabel), findsOneWidget);
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
    await openSong(tester, 'Für Elise');
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
    await openSong(tester, firstSong);

    final screen = tester.widget<PlayScreen>(find.byType(PlayScreen));
    expect(screen.difficulty, Difficulty.hard);
    expect(screen.speed, 0.4);
    expect(screen.tolerance, TimingTolerance.wide, reason: 'the default');
    expect(screen.quantize, isTrue, reason: 'the default');
    expect(screen.latencyOffsetMs, 0, reason: 'the default');
  });

  testWidgets('the timing settings reach the playfield too', (tester) async {
    /// The switch under [title], found by its own label rather than by being
    /// the only one on the screen — there is more than one now.
    Finder switchUnder(String title) => find.ancestor(
          of: find.text(title),
          matching: find.byType(Row),
        ).first;

    await pumpList(tester);
    await tester.tap(find.text(TimingTolerance.tight.label));
    await tester.pump();
    await tester.tap(find.descendant(
        of: switchUnder('Notalar tam zamanında çalsın'),
        matching: find.byType(Switch)));
    await tester.pump();
    await tester.tap(find.descendant(
        of: switchUnder('Kaçırdıklarım da duyulsun'),
        matching: find.byType(Switch)));
    await tester.pump();
    await openSong(tester, 'Für Elise');

    final screen = tester.widget<PlayScreen>(find.byType(PlayScreen));
    expect(screen.tolerance, TimingTolerance.tight);
    expect(screen.quantize, isFalse);
    expect(screen.fillMissed, isTrue, reason: 'switched on from off');
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

    await openSong(tester, firstSong);

    expect(tester.widget<PlayScreen>(find.byType(PlayScreen)).latencyOffsetMs,
        30);
  });
}
