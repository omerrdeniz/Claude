import 'package:flutter_test/flutter_test.dart';
import 'package:piano_flow/music/midi_reader.dart';
import 'package:piano_flow/music/note.dart';

import '../tool/arrangement.dart';

/// An arrangement written here has to survive the round trip out to MIDI and
/// back, because that is the road every song takes: the game never reads the
/// notation, it reads what the notation was turned into.
void main() {
  const source = '''
# A bar of each hand, and a comment that is not a sharp.
bpm: 90
beats-per-bar: 3

[right]
A4:1.5 B4:0.5 | C5:1

[left]
A2:1 E3:0.5 A3:0.5 | G#2:1
''';

  test('a comment does not eat the sharp in a note name', () {
    final arrangement = Arrangement.parse(source);
    expect(arrangement.left, contains('G#2:1'));
  });

  test('the settings come back off the file', () {
    final arrangement = Arrangement.parse(source);
    expect(arrangement.bpm, 90);
    expect(arrangement.beatsPerBar, 3);
  });

  test('the written notes are the notes that come back out of the MIDI', () {
    final song = MidiReader.read(Arrangement.parse(source).toMidi());

    expect(song.bpm, closeTo(90, 0.01));
    expect(song.beatsPerBar, 3);

    final right = song.notes.where((n) => n.hand == Hand.right).toList()
      ..sort((a, b) => a.beat.compareTo(b.beat));
    expect(right.map((n) => n.midi), [69, 71, 72]);
    expect(right.map((n) => n.beat), [0, 1.5, 2]);
    expect(right.map((n) => n.duration), [1.5, 0.5, 1]);

    final left = song.notes.where((n) => n.hand == Hand.left).toList()
      ..sort((a, b) => a.beat.compareTo(b.beat));
    expect(left.map((n) => n.midi), [45, 52, 57, 44]);
  });

  test('the lower hand is read as the left one, not the second one', () {
    // Nothing in the file says which hand is which; the reader decides by
    // pitch. Worth pinning, because an arrangement whose left hand climbed
    // above its right would silently swap the player's hands.
    final song = MidiReader.read(Arrangement.parse(source).toMidi());
    final left = song.notes.where((n) => n.hand == Hand.left);
    final right = song.notes.where((n) => n.hand == Hand.right);
    expect(left.map((n) => n.midi).reduce((a, b) => a > b ? a : b),
        lessThan(right.map((n) => n.midi).reduce((a, b) => a < b ? a : b)));
  });

  test('an arrangement missing a hand or a tempo says so', () {
    expect(() => Arrangement.parse('bpm: 90\n[right]\nC4:1'),
        throwsA(isA<FormatException>()));
    expect(() => Arrangement.parse('[right]\nC4:1\n[left]\nC3:1'),
        throwsA(isA<FormatException>()));
    expect(() => Arrangement.parse('tempo: 90\n[right]\nC4:1\n[left]\nC3:1'),
        throwsA(isA<FormatException>()));
  });
}
