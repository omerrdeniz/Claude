import 'package:flutter_test/flutter_test.dart';
import 'package:piano_flow/music/notation.dart';
import 'package:piano_flow/music/note.dart';

void main() {
  group('note names', () {
    test('map to MIDI numbers', () {
      expect(noteToMidi('A4'), 69);
      expect(noteToMidi('C4'), 60);
      expect(noteToMidi('C-1'), 0);
      expect(noteToMidi('G9'), 127);
    });

    test('accidentals shift by a semitone each', () {
      expect(noteToMidi('C#4'), 61);
      expect(noteToMidi('Db4'), 61, reason: 'enharmonic with C#4');
      expect(noteToMidi('Cb4'), 59);
      expect(noteToMidi('C##4'), 62);
    });

    test('round-trip back to a name', () {
      expect(midiToNote(69), 'A4');
      expect(midiToNote(61), 'C#4');
      expect(midiToNote(60), 'C4');
    });

    test('reject nonsense', () {
      expect(() => noteToMidi('H4'), throwsFormatException);
      expect(() => noteToMidi('C'), throwsFormatException);
      expect(() => noteToMidi('C10'), throwsFormatException,
          reason: 'past the top of the MIDI range');
    });
  });

  group('sequencing', () {
    test('notes follow one another in time', () {
      final notes = seq('C4:1 D4:1 E4:2');
      expect(notes.map((n) => n.beat), [0, 1, 2]);
      expect(notes.map((n) => n.midi), [60, 62, 64]);
    });

    test('a rest advances the cursor without sounding', () {
      expect(seq('C4:1 R:2 D4:1').map((n) => n.beat), [0, 3]);
    });

    test('a chord shares one onset', () {
      final chord = seq('C4+E4+G4:2');
      expect(chord, hasLength(3));
      expect(chord.every((n) => n.beat == 0), isTrue);
      expect(chord.map((n) => n.midi), [60, 64, 67]);
    });

    test('a token can repeat', () {
      expect(seq('C4:0.5*4').map((n) => n.beat), [0, 0.5, 1.0, 1.5]);
    });

    test('velocity can be set per token', () {
      expect(seq('C4:1@0.3').single.velocity, 0.3);
      expect(seq('C4:1', velocity: 0.9).single.velocity, 0.9);
    });

    test('bar lines are ignored', () {
      expect(seq('C4:1 | D4:1').map((n) => n.beat), [0, 1]);
    });

    test('a note lasts as long as it is written', () {
      // It used to be cut to 92% so a repeated pitch would re-articulate.
      // That was not needed — striking a sounding pitch restarts it — and it
      // put a gap under every note in every piece, which the player heard as
      // the music being chopped up.
      final repeated = seq('C4:1 C4:1');
      expect(repeated.first.duration, 1.0);
      expect(repeated.first.endBeat, repeated.last.beat,
          reason: 'one note runs straight into the next');
    });

    test('but can still be shortened on purpose', () {
      expect(seq('C4:1', gate: 0.5).single.duration, 0.5);
    });

    test('a hand can be assigned to the whole sequence', () {
      expect(seq('C3:1', hand: Hand.left).single.hand, Hand.left);
    });

    test('a sequence can start partway through a song', () {
      expect(seq('C4:1', start: 8).single.beat, 8);
    });

    test('fractional beats do not drift', () {
      // A third of a beat, twelve times, must land exactly on beat 4.
      final triplets = seq('C4:0.333333*12');
      expect(triplets.last.beat, closeTo(3.666663, 1e-6));
    });

    test('reject malformed tokens', () {
      expect(() => seq('C4:0'), throwsFormatException);
      expect(() => seq('C4:x'), throwsFormatException);
      expect(() => seq('C4'), throwsFormatException);
      expect(() => seq('C4:1@2'), throwsFormatException,
          reason: 'velocity above 1');
      expect(() => seq('C4:1*0'), throwsFormatException);
    });
  });
}
