// Reads an arrangement written here, in the game's own notation.
//
// Most of the library is engraved by somebody else and fetched. A folk tune
// is not: nobody publishes a LilyPond edition of House of the Rising Sun,
// because there is no edition — there is a melody people have been singing
// since before anyone wrote it down. So we write the arrangement, in the
// notation `lib/music/notation.dart` already reads, and it becomes a song by
// the same road as everything else.
//
// The file is plain text, so it can be read and corrected by eye:
//
//     bpm: 80
//     beats-per-bar: 4
//
//     [right]
//     A4:1.5 B4:0.5 | C5:1.5 E5:0.5
//
//     [left]
//     A2:1 E3:0.5 A3:0.5
//
// A line starting with `#` is a comment — only at the start, because `#` is
// also a sharp and `G#3:1` is a note, not a remark. `|` is a bar line and is
// ignored, and blank lines mean nothing. See `notation.dart` for the note
// tokens themselves.
library;

import 'dart:typed_data';

import 'package:piano_flow/music/note.dart';
import 'package:piano_flow/music/notation.dart';

import 'midi_writer.dart';

class Arrangement {
  const Arrangement({
    required this.bpm,
    required this.beatsPerBar,
    required this.right,
    required this.left,
  });

  final double bpm;
  final int beatsPerBar;
  final String right;
  final String left;

  Uint8List toMidi() => writeMidi(
        right: seq(right, hand: Hand.right),
        left: seq(left, hand: Hand.left),
        bpm: bpm,
        beatsPerBar: beatsPerBar,
      );

  static Arrangement parse(String source) {
    double? bpm;
    var beatsPerBar = 4;
    final parts = <String, StringBuffer>{};
    StringBuffer? current;

    for (final raw in source.split('\n')) {
      final line = raw.trim();
      // Only at the start of a line: `#` is a sharp everywhere else.
      if (line.isEmpty || line.startsWith('#')) continue;

      if (line.startsWith('[') && line.endsWith(']')) {
        current = parts.putIfAbsent(
            line.substring(1, line.length - 1).trim(), StringBuffer.new);
        continue;
      }

      if (current == null) {
        final colon = line.indexOf(':');
        if (colon == -1) throw FormatException('Expected a setting: "$line"');
        final key = line.substring(0, colon).trim();
        final value = line.substring(colon + 1).trim();
        switch (key) {
          case 'bpm':
            bpm = double.parse(value);
          case 'beats-per-bar':
            beatsPerBar = int.parse(value);
          default:
            throw FormatException('Unknown setting "$key"');
        }
        continue;
      }

      current.write(' $line');
    }

    if (bpm == null) throw const FormatException('The arrangement has no bpm');
    for (final hand in ['right', 'left']) {
      if (!parts.containsKey(hand)) {
        throw FormatException('The arrangement has no [$hand]');
      }
    }
    return Arrangement(
      bpm: bpm,
      beatsPerBar: beatsPerBar,
      right: parts['right']!.toString(),
      left: parts['left']!.toString(),
    );
  }
}
