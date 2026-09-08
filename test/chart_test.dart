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

    test('a chord becomes a single tap carrying every note', () {
      final chart = Chart.build(
          songOf([note(0, 60), note(0, 64), note(0, 67), note(1, 72)]));
      expect(chart.taps, hasLength(2));
      expect(chart.taps.first.notes, hasLength(3));
    });

    test('the accompaniment is not something the player taps', () {
      final chart = Chart.build(songOf([
        note(0, 72),
        note(0, 40, hand: Hand.left),
      ]));
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
      final chart = Chart.build(songOf([
        note(0, 60, duration: 0.5),
        note(0, 64, duration: 2.0),
      ]));
      expect(chart.taps.single.duration, 2.0);
    });
  });

  test('the accompaniment can be read back for a stretch of the song', () {
    final chart = Chart.build(songOf([
      note(0, 40, hand: Hand.left),
      note(2, 41, hand: Hand.left),
      note(4, 42, hand: Hand.left),
    ]));
    expect(chart.accompanimentBetween(0, 3).map((n) => n.midi), [40, 41]);
    expect(chart.accompanimentBetween(3, 10).map((n) => n.midi), [42]);
  });
}
