import 'package:flutter_test/flutter_test.dart';
import 'package:piano_flow/data/song_library.dart';
import 'package:piano_flow/music/note.dart';

void main() {
  test('the library is not empty and ids are unique', () {
    final songs = SongLibrary.all;
    expect(songs, isNotEmpty);
    expect(songs.map((s) => s.id).toSet(), hasLength(songs.length));
  });

  test('songs can be looked up by id', () {
    expect(SongLibrary.byId('fur-elise')?.title, 'Für Elise');
    expect(SongLibrary.byId('nope'), isNull);
  });

  for (final song in SongLibrary.all) {
    group(song.title, () {
      test('has notes, in order, within the MIDI range', () {
        expect(song.notes, isNotEmpty);
        var previous = -1.0;
        for (final n in song.notes) {
          expect(n.beat, greaterThanOrEqualTo(previous));
          expect(n.midi, inInclusiveRange(21, 108),
              reason: 'outside an 88-key piano');
          expect(n.duration, greaterThan(0));
          previous = n.beat;
        }
      });

      test('gives the player a melody and plays an accompaniment', () {
        expect(song.melody, isNotEmpty, reason: 'nothing for the player to tap');
        expect(song.accompaniment, isNotEmpty, reason: 'no left hand');
      });

      test('the accompaniment sits below the melody', () {
        final melodyAverage = song.melody.map((n) => n.midi).reduce((a, b) => a + b) /
            song.melody.length;
        final leftAverage =
            song.accompaniment.map((n) => n.midi).reduce((a, b) => a + b) /
                song.accompaniment.length;
        expect(leftAverage, lessThan(melodyAverage));
      });

      test('credits a public-domain source', () {
        expect(song.source, isNotEmpty);
        expect(song.composer, isNotEmpty);
      });

      test('runs for a sensible length of time', () {
        expect(song.duration.inSeconds, greaterThan(5));
        expect(song.duration.inMinutes, lessThan(10));
      });

      test('taps are spaced far enough apart to be playable', () {
        final chords = song.chordsOf(song.melody);
        expect(chords, isNotEmpty);
        final secondsPerBeat = 60 / song.bpm;
        for (var i = 1; i < chords.length; i++) {
          final gap =
              (chords[i].first.beat - chords[i - 1].first.beat) * secondsPerBeat;
          expect(gap, greaterThan(0.1),
              reason: 'taps ${gap.toStringAsFixed(3)}s apart are unplayable');
        }
      });
    });
  }

  test('chordsOf groups notes struck together', () {
    final song = SongLibrary.odeToJoy;
    final chords = song.chordsOf(song.accompaniment);
    expect(chords.first, hasLength(3), reason: 'a triad is one tap');
  });

  test('Ode to Joy opens on the melody everyone knows', () {
    final opening = SongLibrary.odeToJoy.melody.take(4).map((n) => n.midi);
    expect(opening, [64, 64, 65, 67], reason: 'E E F G');
  });

  test('Für Elise opens on its alternating semitone', () {
    final opening = SongLibrary.furElise.melody.take(4).map((n) => n.midi);
    expect(opening, [76, 75, 76, 75], reason: 'E5 D#5 E5 D#5');
  });

  test('the Bach prelude repeats one figure under changing harmony', () {
    final song = SongLibrary.preludeInC;
    final figure = song.melody.take(3).map((n) => n.midi).toList();
    expect(figure, [55, 60, 64], reason: 'G3 C4 E4');
    // The same shape returns immediately, a step further into the bar.
    expect(song.melody.skip(3).take(3).map((n) => n.midi), figure);
    // Bar three changes harmony, so the figure moves.
    final barThree = song.melody
        .where((n) => n.beat >= 8 && n.beat < 12)
        .take(3)
        .map((n) => n.midi);
    expect(barThree, isNot(figure));
  });

  test('every note belongs to a hand', () {
    for (final song in SongLibrary.all) {
      expect(song.notes.length,
          song.melody.length + song.accompaniment.length);
      expect(song.notes.every((n) => n.hand == Hand.right || n.hand == Hand.left),
          isTrue);
    }
  });
}
