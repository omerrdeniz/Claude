import 'package:flutter_test/flutter_test.dart';
import 'package:piano_flow/game/chart.dart';
import 'package:piano_flow/music/note.dart';
import 'package:piano_flow/music/song.dart';

import 'support/library.dart';

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
        for (final song in shippedSongs) {
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
        for (final song in shippedSongs) {
          for (final tap in Chart.build(song, difficulty: difficulty).taps) {
            expect(tap.across, inInclusiveRange(0.0, 1.0));
          }
        }
      }
    });
  });

  group('where each note of a chord is drawn', () {
    final chord = songOf([
      note(0, 48, hand: Hand.left),
      note(0, 52, hand: Hand.left),
      note(0, 55, hand: Hand.left),
    ]);

    test('a touch knows a place for every note it carries', () {
      for (final difficulty in Difficulty.values) {
        for (final tap in Chart.build(chord, difficulty: difficulty).taps) {
          expect(tap.noteAcross, hasLength(tap.notes.length),
              reason: 'on ${difficulty.label}');
        }
      }
    });

    test('a chord under one finger still spreads over three places', () {
      final chart = Chart.build(chord, difficulty: Difficulty.normal);
      final tap = chart.taps.single;
      expect(tap.notes, hasLength(3), reason: 'one touch');
      expect(tap.noteAcross.toSet(), hasLength(3),
          reason: 'but three notes to draw, at three pitches');
      final sorted = [...tap.noteAcross]..sort();
      expect(sorted, tap.noteAcross,
          reason: 'in pitch order, like the notes themselves');
    });

    test('the touch sits at the middle of the notes it carries', () {
      final tap = Chart.build(chord, difficulty: Difficulty.normal).taps.single;
      final average =
          tap.noteAcross.reduce((a, b) => a + b) / tap.noteAcross.length;
      expect(tap.across, closeTo(average, 0.0001));
    });

    test('a single note is drawn where it sounds', () {
      final tap = Chart.build(songOf([note(0, 60)])).taps.single;
      expect(tap.noteAcross, [tap.across]);
    });
  });

  group('how many notes are sounding', () {
    final chord = songOf([
      note(0, 60, hand: Hand.left),
      note(0, 64, hand: Hand.left),
      note(0, 67, hand: Hand.left),
      note(0, 84),
    ]);

    test('a hand counts only its own notes', () {
      final chart = Chart.build(chord, difficulty: Difficulty.hard);
      for (final tap in chart.taps) {
        expect(tap.voices, tap.hand == Hand.left ? 3 : 1,
            reason: 'the other hand should not inflate the count');
      }
    });

    test('a chord is a chord however many fingers the level asks for', () {
      // The colour is read off this, so a three-note chord must count as
      // three whether it arrives under one finger or three.
      for (final difficulty in Difficulty.values) {
        final chart = Chart.build(chord, difficulty: difficulty);
        final left = chart.taps.where((t) =>
            t.notes.any((n) => n.hand == Hand.left));
        expect(left.map((t) => t.voices).toSet(), {difficulty == Difficulty.easy ? 4 : 3},
            reason: 'on ${difficulty.label}');
      }
    });

    test('a single note is a single voice', () {
      expect(Chart.build(songOf([note(0, 60)])).taps.single.voices, 1);
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
      for (final song in shippedSongs) {
        var previous = -1.0;
        for (final tap in Chart.build(song).taps) {
          expect(tap.beat, greaterThanOrEqualTo(previous));
          previous = tap.beat;
        }
      }
    });
  });

  group('runs, the passages too fast to tap', () {
    // A beat is half a second here, so a quarter of a beat is 125 ms — inside
    // the 150 ms that makes a run — and half a beat is 250 ms, outside it.
    List<Tap> runOf(Chart chart) =>
        chart.runs.isEmpty ? const [] : chart.runs.values.single;

    test('notes close together and going on long enough make one', () {
      final chart = Chart.build(
        songOf([for (var i = 0; i < 6; i++) note(i * 0.25, 60 + i)]),
        difficulty: Difficulty.normal,
      );
      expect(runOf(chart), hasLength(6));
      expect(chart.taps.map((t) => t.runIndex), [0, 1, 2, 3, 4, 5]);
    });

    test('a flurry too short to get a finger onto is left as taps', () {
      // Three notes an eighth of a second apart are over in a quarter of a
      // second. The player could not catch them and there was nothing to
      // gain: three taps is three taps.
      final chart = Chart.build(
        songOf([for (var i = 0; i < 3; i++) note(i * 0.25, 60 + i)]),
        difficulty: Difficulty.normal,
      );
      expect(chart.runs, isEmpty);
    });

    test('two are a flourish, not a run', () {
      final chart = Chart.build(
        songOf([note(0, 60), note(0.25, 62)]),
        difficulty: Difficulty.normal,
      );
      expect(chart.runs, isEmpty);
      expect(chart.taps.every((t) => t.runId == null), isTrue);
    });

    test('notes a hand can reach one at a time are left alone', () {
      final chart = Chart.build(
        songOf([for (var i = 0; i < 8; i++) note(i * 0.5, 60 + i)]),
        difficulty: Difficulty.normal,
      );
      expect(chart.runs, isEmpty);
    });

    test('it ends where the hurry ends', () {
      final chart = Chart.build(
        songOf([
          for (var i = 0; i < 6; i++) note(i * 0.25, 60 + i),
          note(6, 72), // well over a beat later: the hand has caught up
          note(7, 74),
        ]),
        difficulty: Difficulty.normal,
      );
      expect(runOf(chart).map((t) => t.beat),
          [0, 0.25, 0.5, 0.75, 1.0, 1.25]);
    });

    test('a chord is a moment, not a hurry', () {
      final chart = Chart.build(
        songOf([note(0, 60), note(0, 64), note(0, 67)]),
        difficulty: Difficulty.hard, // a touch per note, all at once
      );
      expect(chart.taps, hasLength(3));
      expect(chart.runs, isEmpty, reason: 'three fingers, one moment');
    });

    test('the other hand does not break it', () {
      final chart = Chart.build(
        songOf([
          for (var i = 0; i < 6; i++) note(i * 0.25, 72 + i),
          note(0.3, 48, hand: Hand.left),
          note(0.6, 50, hand: Hand.left),
        ]),
        difficulty: Difficulty.normal,
      );
      expect(runOf(chart), hasLength(6),
          reason: 'a left-hand note landing inside a right-hand run is not '
              'part of it and does not interrupt it');
    });

    test('the pieces that prompted this have them', () {
      // The rondo's coda and the nocturne's cadenza are what a hand cannot
      // do; if these ever come back empty the mechanic has quietly died.
      for (final song in [shipped('fur-elise'), shipped('nocturne-op9-no2')]) {
        final chart = Chart.build(song, difficulty: Difficulty.normal);
        expect(chart.runs, isNotEmpty, reason: song.title);
        final longest = chart.runs.values
            .map((r) => r.length)
            .reduce((a, b) => a > b ? a : b);
        expect(longest, greaterThanOrEqualTo(10), reason: song.title);
      }
    });

    test('every run is in time order and long enough to be one', () {
      for (final song in shippedSongs) {
        final secondsPerBeat = 60 / song.bpm;
        for (final run in Chart.build(song).runs.values) {
          expect(run.length, greaterThanOrEqualTo(Chart.runLength));
          expect((run.last.beat - run.first.beat) * secondsPerBeat,
              greaterThanOrEqualTo(Chart.runSeconds - 1e-9),
              reason: '${song.title}: a run too short to join');
          for (var i = 1; i < run.length; i++) {
            expect(run[i].beat, greaterThan(run[i - 1].beat));
            expect(run[i].hand, run[i - 1].hand);
            expect(run[i].runIndex, i);
          }
        }
      }
    });
  });

  group('what counts as a note to hold', () {
    test('it is a length of time, not a number of beats', () {
      // The same written note, in two pieces at different tempos. A hand
      // knows seconds; it does not know beats.
      Tap only(double bpm) => Chart
          .build(songOf([note(0, 60, duration: 1.2)], bpm: bpm),
              difficulty: Difficulty.normal)
          .taps
          .single;

      expect(only(40).isHold, isTrue, reason: '1.2 beats at 40 is 1.8 s');
      expect(only(200).isHold, isFalse, reason: '1.2 beats at 200 is 0.36 s');
    });

    test("the canon's walking bass is held, because that is how it sounds", () {
      // Reported by the player: the opening notes sound held but were drawn
      // as taps. They are quarter notes at 55 — 1.09 seconds each — and the
      // threshold used to be 1.25 beats, which in this piece is 1.36
      // seconds. Nothing in the bass reached it.
      final chart = Chart.build(shipped('canon-in-d'));
      final opening = chart.taps.take(8);
      expect(opening.every((tap) => tap.isHold), isTrue,
          reason: 'the ground bass rings for a second a note');
    });

    test('nothing quick is ever asked to be held', () {
      for (final song in shippedSongs) {
        final secondsPerBeat = 60 / song.bpm;
        for (final tap in Chart.build(song).taps.where((t) => t.isHold)) {
          expect(tap.duration * secondsPerBeat,
              greaterThanOrEqualTo(Tap.holdSeconds - 1e-9),
              reason: '${song.title}: a hold of '
                  '${(tap.duration * secondsPerBeat * 1000).round()} ms');
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
