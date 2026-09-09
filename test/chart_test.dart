import 'package:flutter_test/flutter_test.dart';
import 'package:piano_flow/data/song_library.dart';
import 'package:piano_flow/game/chart.dart';
import 'package:piano_flow/music/note.dart';
import 'package:piano_flow/music/song.dart';

Song songOf(List<Note> notes, {double bpm = 120}) => Song(
      id: 'test',
      title: 'Test',
      composer: '',
      bpm: bpm,
      notes: notes,
    );

Note note(double beat, int midi,
        {double duration = 0.5, Hand hand = Hand.right}) =>
    Note(beat: beat, midi: midi, duration: duration, hand: hand);

void main() {
  group('what the player is given', () {
    final twoHands = songOf([
      note(0, 72),
      note(0, 48, hand: Hand.left),
      note(0, 52, hand: Hand.left),
      note(0, 55, hand: Hand.left),
      note(1, 74),
    ]);

    test('easy is one zone and one finger', () {
      final chart = Chart.build(twoHands, difficulty: Difficulty.easy);
      expect(chart.separatesHands, isFalse);
      final atZero = chart.taps.where((t) => t.beat == 0);
      expect(atZero, hasLength(1), reason: 'the whole moment is one touch');
      expect(atZero.single.notes, hasLength(4));
    });

    test('normal splits the hands but keeps a chord under one finger', () {
      final chart = Chart.build(twoHands, difficulty: Difficulty.normal);
      expect(chart.separatesHands, isTrue);
      final atZero = chart.taps.where((t) => t.beat == 0).toList();
      expect(atZero, hasLength(2), reason: 'one touch per hand');
      expect(atZero.map((t) => t.hand).toSet(), {Hand.left, Hand.right});
      final left = atZero.firstWhere((t) => t.hand == Hand.left);
      expect(left.notes, hasLength(3), reason: 'the triad is one touch');
    });

    test('hard asks for a finger per note of a chord', () {
      final chart = Chart.build(twoHands, difficulty: Difficulty.hard);
      final atZero = chart.taps.where((t) => t.beat == 0).toList();
      expect(atZero, hasLength(4), reason: 'three in the left, one in the right');
      expect(atZero.where((t) => t.hand == Hand.left), hasLength(3));
      expect(atZero.every((t) => t.notes.length == 1), isTrue);
    });

    test('nothing plays itself once the hands are separated', () {
      for (final difficulty in [Difficulty.normal, Difficulty.hard]) {
        expect(Chart.build(twoHands, difficulty: difficulty).autoNotes, isEmpty);
      }
    });

    test('every note is either played or played for the player', () {
      for (final difficulty in Difficulty.values) {
        for (final song in SongLibrary.all) {
          final chart = Chart.build(song, difficulty: difficulty);
          final tapped = chart.taps.expand((t) => t.notes).length;
          expect(tapped + chart.autoNotes.length, song.notes.length,
              reason: '${song.title} on ${difficulty.label}');
        }
      }
    });
  });

  group('where the hands sit', () {
    final spread = songOf([
      note(0, 40, hand: Hand.left),
      note(0, 55, hand: Hand.left),
      note(1, 72),
      note(1, 84),
    ]);

    test('each hand keeps to its own side of the screen', () {
      final chart = Chart.build(spread, difficulty: Difficulty.hard);
      for (final tap in chart.taps) {
        if (tap.hand == Hand.left) {
          expect(tap.across, lessThan(0.5), reason: 'left of centre');
        } else {
          expect(tap.across, greaterThan(0.5), reason: 'right of centre');
        }
      }
    });

    test('a gap is left down the middle', () {
      final chart = Chart.build(spread, difficulty: Difficulty.hard);
      for (final tap in chart.taps) {
        expect((tap.across - 0.5).abs(), greaterThan(0.04),
            reason: 'nothing should sit on the divide');
      }
    });

    test('within a hand, higher notes sit further right', () {
      final chart = Chart.build(spread, difficulty: Difficulty.hard);
      final left = chart.taps.where((t) => t.hand == Hand.left).toList()
        ..sort((a, b) => a.notes.first.midi.compareTo(b.notes.first.midi));
      expect(left.first.across, lessThan(left.last.across));
    });

    test('on easy the notes use the whole width instead', () {
      // Separate moments, so nothing is merged and the extremes are visible.
      final chart = Chart.build(
        songOf([
          note(0, 40, hand: Hand.left),
          note(1, 84),
        ]),
        difficulty: Difficulty.easy,
      );
      final places = chart.taps.map((t) => t.across).toList()..sort();
      expect(places.first, lessThan(0.15));
      expect(places.last, greaterThan(0.85));
      expect(places.last - places.first, greaterThan(0.7),
          reason: 'one zone, so the full width is used');
    });

    test('notes stay on the screen', () {
      for (final difficulty in Difficulty.values) {
        for (final song in SongLibrary.all) {
          for (final tap in Chart.build(song, difficulty: difficulty).taps) {
            expect(tap.across, inInclusiveRange(0.0, 1.0));
          }
        }
      }
    });
  });

  group('how many fingers', () {
    test('a hand is told how many of its own notes fall together', () {
      final chart = Chart.build(
        songOf([
          note(0, 60, hand: Hand.left),
          note(0, 64, hand: Hand.left),
          note(0, 84),
        ]),
        difficulty: Difficulty.hard,
      );
      for (final tap in chart.taps) {
        expect(tap.fingers, tap.hand == Hand.left ? 2 : 1,
            reason: 'the other hand should not inflate the count');
      }
    });

    test('a single note is a single finger', () {
      final chart = Chart.build(songOf([note(0, 60)]));
      expect(chart.taps.single.fingers, 1);
    });
  });

  group('holds', () {
    test('a long note is held', () {
      final chart = Chart.build(songOf([note(0, 60, duration: 2)]));
      expect(chart.taps.single.isHold, isTrue);
    });

    test('a short one is struck', () {
      final chart = Chart.build(songOf([note(0, 60, duration: 0.5)]));
      expect(chart.taps.single.isHold, isFalse);
    });

    test('a held touch lasts as long as its longest note', () {
      final chart = Chart.build(
        songOf([note(0, 60, duration: 0.5), note(0, 64, duration: 2)]),
        difficulty: Difficulty.easy,
      );
      expect(chart.taps.single.endBeat, 2.0);
    });
  });

  group('easy thins what is too dense to answer', () {
    final run = songOf([for (var i = 0; i < 16; i++) note(i * 0.25, 60 + i)]);

    test('a wall of sixteenths becomes something playable', () {
      final easy = Chart.build(run, difficulty: Difficulty.easy);
      final normal = Chart.build(run, difficulty: Difficulty.normal);
      expect(easy.taps.length, lessThanOrEqualTo(normal.taps.length ~/ 2));
      for (var i = 1; i < easy.taps.length; i++) {
        expect(easy.taps[i].beat - easy.taps[i - 1].beat,
            greaterThanOrEqualTo(0.5 - 0.001));
      }
    });

    test('and the rest is played, not dropped', () {
      final easy = Chart.build(run, difficulty: Difficulty.easy);
      expect(easy.taps.expand((t) => t.notes).length + easy.autoNotes.length, 16);
    });

    test('a sparse song is left alone', () {
      final sparse = songOf([note(0, 60), note(1, 62), note(2, 64)]);
      expect(Chart.build(sparse, difficulty: Difficulty.easy).taps, hasLength(3));
    });
  });

  group('what is on screen', () {
    final chart = Chart.build(
        songOf([for (var i = 0; i < 20; i++) note(i.toDouble(), 60 + i)]));

    test('only notes inside the look-ahead window are shown', () {
      expect(chart.visibleAt(0, 4).map((t) => t.beat), [0, 1, 2, 3, 4]);
    });

    test('a touch stays briefly after its moment, for a late hit', () {
      expect(chart.visibleAt(5.2, 4).first.beat, 5.0);
    });

    test('nothing is visible before the song starts or after it ends', () {
      expect(chart.visibleAt(-10, 4), isEmpty);
      expect(chart.visibleAt(500, 4), isEmpty);
    });

    test('taps stay in time order', () {
      for (final song in SongLibrary.all) {
        var previous = -1.0;
        for (final tap in Chart.build(song).taps) {
          expect(tap.beat, greaterThanOrEqualTo(previous));
          previous = tap.beat;
        }
      }
    });
  });

  test('which hand a touch belongs to is read from where it landed', () {
    expect(Chart.handAt(0.1), Hand.left);
    expect(Chart.handAt(0.49), Hand.left);
    expect(Chart.handAt(0.51), Hand.right);
    expect(Chart.handAt(0.9), Hand.right);
  });

  test('the accompaniment can be read back for a stretch of the song', () {
    final chart = Chart.build(
      songOf([
        for (var i = 0; i < 8; i++) note(i * 0.25, 60 + i),
      ]),
      difficulty: Difficulty.easy,
    );
    expect(chart.accompanimentBetween(0, 1), isNotEmpty);
    expect(chart.accompanimentBetween(100, 200), isEmpty);
  });
}
