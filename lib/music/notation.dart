/// A compact notation for writing songs by hand, so the library stays
/// readable and reviewable instead of being a wall of numbers.
///
///     'E5:0.5 D#5:0.5 R:1 C4+E4+G4:2'
///
/// Tokens are read left to right, advancing a cursor measured in beats:
///
///   `C4:1`        one note, one beat long
///   `C4+E4+G4:2`  a chord — all three share the onset
///   `R:0.5`       a rest
///   `C4:0.5*4`    repeat the token four times
///   `C4:1@0.4`    play this one at velocity 0.4
///   `|`           bar line, ignored — purely for legibility
///
/// A beat is a quarter note.
library;

import 'note.dart';

const _pitchClasses = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11};

const _noteNames = [
  'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B',
];

final _noteNamePattern = RegExp(r'^([A-Ga-g])([#b]*)(-?\d+)$');

/// 'C4' -> 60, 'A4' -> 69, 'Db4' -> 61.
int noteToMidi(String name) {
  final match = _noteNamePattern.firstMatch(name.trim());
  if (match == null) throw FormatException('Bad note name: "$name"');
  var midi = _pitchClasses[match.group(1)!.toUpperCase()]! +
      (int.parse(match.group(3)!) + 1) * 12;
  for (final accidental in match.group(2)!.split('')) {
    midi += accidental == '#' ? 1 : -1;
  }
  if (midi < 0 || midi > 127) {
    throw FormatException('Note out of MIDI range: "$name"');
  }
  return midi;
}

/// 60 -> 'C4'. Sharps only; this is for display and debugging.
String midiToNote(int midi) =>
    '${_noteNames[midi % 12]}${midi ~/ 12 - 1}';

/// Parse a sequence into notes with absolute onsets.
///
/// [gate] shortens each note against its written length. It is 1 — a note
/// lasts as long as it is written — and wants a reason to be anything else.
/// It used to be 0.92, to make a repeated pitch re-articulate; that is not
/// needed, because striking a pitch that is already sounding restarts it, and
/// all the shortening did was put a gap under every note in the piece.
List<Note> seq(
  String source, {
  double start = 0,
  double velocity = 0.75,
  Hand hand = Hand.right,
  double gate = 1.0,
}) {
  final notes = <Note>[];
  var cursor = start;

  for (final raw in source.split(RegExp(r'\s+'))) {
    final token = raw.trim();
    if (token.isEmpty || token == '|') continue;

    var body = token;
    var noteVelocity = velocity;
    var repeat = 1;

    final at = body.indexOf('@');
    if (at != -1) {
      noteVelocity = double.tryParse(body.substring(at + 1)) ??
          (throw FormatException('Bad velocity in "$token"'));
      if (noteVelocity <= 0 || noteVelocity > 1) {
        throw FormatException('Velocity must be in 0..1 in "$token"');
      }
      body = body.substring(0, at);
    }

    final star = body.indexOf('*');
    if (star != -1) {
      repeat = int.tryParse(body.substring(star + 1)) ??
          (throw FormatException('Bad repeat count in "$token"'));
      if (repeat < 1) throw FormatException('Bad repeat count in "$token"');
      body = body.substring(0, star);
    }

    final parts = body.split(':');
    if (parts.length != 2) {
      throw FormatException('Expected PITCH:DURATION in "$token"');
    }
    final duration = double.tryParse(parts[1]);
    if (duration == null || duration <= 0) {
      throw FormatException('Bad duration in "$token"');
    }

    for (var r = 0; r < repeat; r++) {
      if (parts[0].toUpperCase() != 'R') {
        for (final pitch in parts[0].split('+')) {
          notes.add(Note(
            beat: _round(cursor),
            midi: noteToMidi(pitch),
            duration: _round(duration * gate),
            velocity: noteVelocity,
            hand: hand,
          ));
        }
      }
      cursor = _round(cursor + duration);
    }
  }
  return notes;
}

/// Beats are written as simple fractions; rounding here keeps float drift from
/// splitting what should be a single chord onset into several.
double _round(double x) => (x * 1e6).roundToDouble() / 1e6;
