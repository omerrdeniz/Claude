import 'package:flutter_test/flutter_test.dart';
import 'package:piano_flow/data/score_import.dart';
import 'package:piano_flow/data/scores.g.dart' as scores;
import 'package:piano_flow/music/note.dart';
import 'package:piano_flow/music/song.dart';

/// What the import is allowed to change about an engraved score, and what it
/// has to leave exactly as the edition has it.
void main() {
  test('an engraved score reads as a playable song', () {
    final song = ScoreImport.read(
      scores.preludeInC,
      id: 'test',
      title: 'Test',
      composer: 'Bach',
      source: 'Mutopia',
      bpm: 60,
      beatsPerBar: 4,
    );

    expect(song.id, 'test');
    expect(song.bpm, 60);
    expect(song.notes, isNotEmpty);
    expect(song.melody, isNotEmpty);
    expect(song.accompaniment, isNotEmpty);
    // The opening figure, at the octave the edition puts it in.
    expect(song.melody.take(3).map((n) => n.midi), [67, 72, 76]);
  });

  test('the beat can be a note value other than the quarter', () {
    Song read(double beatsPerQuarter) => ScoreImport.read(
          scores.furElise,
          id: 'test',
          title: 'Test',
          composer: 'Beethoven',
          source: 'Mutopia',
          bpm: 144,
          beatsPerBar: 3,
          beatsPerQuarter: beatsPerQuarter,
        );

    final inQuarters = read(1);
    final inEighths = read(2);
    expect(inEighths.lengthInBeats, closeTo(inQuarters.lengthInBeats * 2, 1e-6));
    expect(inEighths.notes.length, inQuarters.notes.length);
  });

  test('each hand gets its own weight, since the engraving has none', () {
    final song = ScoreImport.read(
      scores.preludeInC,
      id: 'test',
      title: 'Test',
      composer: 'Bach',
      source: 'Mutopia',
      bpm: 60,
      beatsPerBar: 4,
      rightVelocity: 0.8,
      leftVelocity: 0.4,
    );
    expect(song.melody.every((n) => n.velocity == 0.8), isTrue);
    expect(song.accompaniment.every((n) => n.velocity == 0.4), isTrue);
  });

  test('grace notes are dropped rather than left untappable', () {
    final song = ScoreImport.read(
      scores.furElise,
      id: 'test',
      title: 'Test',
      composer: 'Beethoven',
      source: 'Mutopia',
      bpm: 144,
      beatsPerBar: 3,
      beatsPerQuarter: 2,
    );
    // Für Elise carries three ornaments — two grace notes and an
    // appoggiatura — each a sliver of stolen time before the note it
    // decorates. Nothing that short survives the import.
    for (final note in song.notes) {
      expect(note.duration, greaterThan(0.1),
          reason: 'an ornament made it through as its own note');
    }
  });

  test('onsets land on a grid, so a chord stays one touch', () {
    final song = ScoreImport.read(
      scores.furElise,
      id: 'test',
      title: 'Test',
      composer: 'Beethoven',
      source: 'Mutopia',
      bpm: 144,
      beatsPerBar: 3,
      beatsPerQuarter: 2,
    );
    // Twenty-four steps to the eighth: thirty-seconds and triplets alike.
    for (final note in song.notes) {
      final steps = note.beat * 24;
      expect((steps - steps.roundToDouble()).abs(), lessThan(1e-6),
          reason: 'onset ${note.beat} is off the grid');
    }
  });

  test('the hands come out of the edition the right way round', () {
    for (final score in [scores.furElise, scores.preludeInC]) {
      final song = ScoreImport.read(
        score,
        id: 'test',
        title: 'Test',
        composer: 'x',
        source: 'x',
        bpm: 100,
        beatsPerBar: 4,
      );
      double average(Iterable<Note> ns) =>
          ns.map((n) => n.midi).reduce((a, b) => a + b) / ns.length;
      expect(average(song.accompaniment), lessThan(average(song.melody)));
    }
  });
}
