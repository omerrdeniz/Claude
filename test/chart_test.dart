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
  group('building taps', () {
    test('one note becomes one tap', () {
      final chart = Chart.build(songOf([note(0, 60), note(1, 62)]));
      expect(chart.taps, hasLength(2));
      expect(chart.taps.first.notes.single.midi, 60);
    });

    test('a chord becomes one tap per finger, by pitch', () {
      final chart = Chart.build(
          songOf([note(0, 60), note(0, 64), note(0, 67), note(1, 72)]),
          beamCount: 4);
      final atZero = chart.taps.where((t) => t.beat == 0).toList();
      expect(atZero.length, greaterThan(1));
      expect(atZero.expand((t) => t.notes).map((n) => n.midi).toList()..sort(),
          [60, 64, 67]);
    });

    test('on easy that same chord is one finger', () {
      final chart = Chart.build(
          songOf([note(0, 60), note(0, 64), note(0, 67)]),
          difficulty: Difficulty.easy);
      expect(chart.taps, hasLength(1));
      expect(chart.taps.single.notes, hasLength(3));
    });

    test('on easy the accompaniment is not something the player taps', () {
      final chart = Chart.build(
        songOf([note(0, 72), note(0, 40, hand: Hand.left)]),
        difficulty: Difficulty.easy,
      );
      expect(chart.taps, hasLength(1));
      expect(chart.taps.single.notes.single.midi, 72);
    });

    test('taps stay in time order', () {
      final chart = Chart.build(SongLibrary.odeToJoy);
      var previous = -1.0;
      for (final tap in chart.taps) {
        expect(tap.beat, greaterThanOrEqualTo(previous));
        previous = tap.beat;
      }
    });
  });

  group('difficulty', () {
    // A melody note with a triad underneath it, struck together.
    final withChord = songOf([
      note(0, 72),
      note(0, 48, hand: Hand.left),
      note(0, 52, hand: Hand.left),
      note(0, 55, hand: Hand.left),
      note(2, 41, hand: Hand.left), // off on its own, between melody notes
    ]);

    test('easy thins a dense run so a beginner can answer it', () {
      // Sixteen sixteenth notes: a wall at any tempo. Easy should ask for a
      // fraction of them and play the rest, leaving the music whole.
      final run = songOf([
        for (var i = 0; i < 16; i++) note(i * 0.25, 60 + i),
      ]);
      final easy = Chart.build(run, difficulty: Difficulty.easy);
      final normal = Chart.build(run, difficulty: Difficulty.normal);

      expect(easy.taps.length, lessThanOrEqualTo(normal.taps.length ~/ 2));
      expect(easy.taps.length + easy.autoNotes.length, 16,
          reason: 'every note still sounds, played or not');

      // And what is left is spread out.
      for (var i = 1; i < easy.taps.length; i++) {
        expect(easy.taps[i].beat - easy.taps[i - 1].beat,
            greaterThanOrEqualTo(0.5 - 0.001));
      }
    });

    test('easy leaves a song that is already sparse alone', () {
      final sparse = songOf([note(0, 60), note(1, 62), note(2, 64)]);
      final easy = Chart.build(sparse, difficulty: Difficulty.easy);
      expect(easy.taps, hasLength(3));
    });

    test('easy hands the player one finger and plays the rest', () {
      final chart = Chart.build(withChord, difficulty: Difficulty.easy);
      expect(chart.taps, hasLength(1));
      expect(chart.taps.single.notes.single.midi, 72);
      expect(chart.autoNotes, hasLength(4), reason: 'all harmony plays itself');
    });

    test('normal gives the player every note, chords under several fingers', () {
      final chart = Chart.build(withChord, difficulty: Difficulty.normal);
      final atZero = chart.taps.where((t) => t.beat == 0);
      expect(atZero.length, greaterThan(1),
          reason: 'a chord must need more than one finger');
      expect(atZero.map((t) => t.beam).toSet(), hasLength(atZero.length),
          reason: 'each finger gets its own beam');
      expect(chart.autoNotes, isEmpty,
          reason: 'nothing should play itself on normal');
    });

    test('every tap knows how many fingers its moment needs', () {
      final chart = Chart.build(withChord, difficulty: Difficulty.normal);
      final atZero = chart.taps.where((t) => t.beat == 0).toList();
      for (final tap in atZero) {
        expect(tap.fingers, atZero.length,
            reason: 'all of a chord must agree on its size');
      }
      final alone = chart.taps.firstWhere((t) => t.beat == 2);
      expect(alone.fingers, 1);
    });

    test('hard plays the same notes as normal', () {
      final normal = Chart.build(withChord, difficulty: Difficulty.normal);
      final hard = Chart.build(withChord, difficulty: Difficulty.hard);
      expect(hard.autoNotes, isEmpty);
      expect(hard.taps.length, normal.taps.length,
          reason: 'hard is the same chart, judged more tightly');
    });

    test('a note is never both played and auto-played', () {
      for (final difficulty in Difficulty.values) {
        for (final song in SongLibrary.all) {
          final chart = Chart.build(song, difficulty: difficulty);
          final tapped = chart.taps.expand((t) => t.notes).length;
          expect(tapped + chart.autoNotes.length, song.notes.length,
              reason: '${song.title} on ${difficulty.label}');
        }
      }
    });

    test('the harder it gets, the more the player plays', () {
      int played(Song song, Difficulty d) =>
          Chart.build(song, difficulty: d).taps.expand((t) => t.notes).length;

      for (final song in SongLibrary.all) {
        expect(played(song, Difficulty.normal),
            greaterThanOrEqualTo(played(song, Difficulty.easy)),
            reason: song.title);
        expect(played(song, Difficulty.hard),
            greaterThanOrEqualTo(played(song, Difficulty.normal)),
            reason: song.title);
      }

      // Normal already hands over the whole piece, so the step up to hard is
      // in the judging rather than in the notes.
      expect(played(SongLibrary.preludeInC, Difficulty.hard),
          played(SongLibrary.preludeInC, Difficulty.normal));
    });

    test('real songs give the player chords to press', () {
      final chart = Chart.build(SongLibrary.odeToJoy,
          beamCount: 4, difficulty: Difficulty.normal);
      final byBeat = <double, int>{};
      for (final tap in chart.taps) {
        byBeat[tap.beat] = (byBeat[tap.beat] ?? 0) + 1;
      }
      expect(byBeat.values.any((fingers) => fingers >= 2), isTrue,
          reason: 'no moment in the song needs more than one finger');
    });
  });

  group('assigning beams', () {
    test('every beam index is in range', () {
      for (final song in SongLibrary.all) {
        final chart = Chart.build(song, beamCount: 4);
        for (final tap in chart.taps) {
          expect(tap.beam, inInclusiveRange(0, 3));
        }
      }
    });

    test('higher notes sit on higher beams', () {
      final chart = Chart.build(
          songOf([note(0, 48), note(1, 60), note(2, 72), note(3, 84)]),
          beamCount: 4);
      expect(chart.taps.map((t) => t.beam), [0, 1, 2, 3]);
    });

    test('the lowest and highest notes reach the outer beams', () {
      final chart = Chart.build(SongLibrary.preludeInC, beamCount: 4);
      expect(chart.taps.map((t) => t.beam).reduce((a, b) => a < b ? a : b), 0);
      expect(chart.taps.map((t) => t.beam).reduce((a, b) => a > b ? a : b), 3);
    });

    test('a song on one pitch does not crash and lands on one beam', () {
      final chart = Chart.build(songOf([note(0, 60), note(1, 60), note(2, 60)]));
      expect(chart.taps.map((t) => t.beam).toSet(), hasLength(1));
    });

    test('the beam count is respected', () {
      for (final count in [1, 2, 3, 5, 8]) {
        final chart = Chart.build(SongLibrary.furElise, beamCount: count);
        expect(chart.beamCount, count);
        for (final tap in chart.taps) {
          expect(tap.beam, inInclusiveRange(0, count - 1));
        }
      }
    });
  });

  group('what is on screen', () {
    final chart = Chart.build(songOf([
      for (var i = 0; i < 20; i++) note(i.toDouble(), 60 + i),
    ]));

    test('only notes inside the look-ahead window are shown', () {
      final visible = chart.visibleAt(0, 4).toList();
      expect(visible.map((t) => t.beat), [0, 1, 2, 3, 4]);
    });

    test('a tap stays briefly after its moment, for a late hit', () {
      expect(chart.visibleAt(5.2, 4).first.beat, 5.0);
    });

    test('but not for long — a spent note must leave the screen', () {
      expect(chart.visibleAt(5.6, 4).first.beat, 6.0);
    });

    test('nothing is visible before the song starts', () {
      expect(chart.visibleAt(-10, 4), isEmpty);
    });

    test('nothing is visible after it ends', () {
      expect(chart.visibleAt(500, 4), isEmpty);
    });
  });

  group('holds', () {
    test('a long note is a hold', () {
      final chart = Chart.build(songOf([note(0, 60, duration: 2.0)]));
      expect(chart.taps.single.isHold, isTrue);
    });

    test('a short one is not', () {
      final chart = Chart.build(songOf([note(0, 60, duration: 0.5)]));
      expect(chart.taps.single.isHold, isFalse);
    });

    test('a tap lasts as long as its longest note', () {
      // Easy keeps the chord under one finger, so one tap carries both.
      final chart = Chart.build(
        songOf([note(0, 60, duration: 0.5), note(0, 64, duration: 2.0)]),
        difficulty: Difficulty.easy,
      );
      expect(chart.taps.single.duration, 2.0);
    });
  });

  test('the accompaniment can be read back for a stretch of the song', () {
    // Easy is the level that still plays part of the song for the player.
    final chart = Chart.build(
      songOf([
        note(0, 40, hand: Hand.left),
        note(2, 41, hand: Hand.left),
        note(4, 42, hand: Hand.left),
      ]),
      difficulty: Difficulty.easy,
    );
    expect(chart.accompanimentBetween(0, 3).map((n) => n.midi), [40, 41]);
    expect(chart.accompanimentBetween(3, 10).map((n) => n.midi), [42]);
  });
}
