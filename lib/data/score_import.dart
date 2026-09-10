import 'dart:typed_data';

import '../music/midi_reader.dart';
import '../music/note.dart';
import '../music/song.dart';
import 'song_info.dart';

/// Turns an engraved score into a song the game can lay out.
///
/// The songs in `assets/songs/` are MIDI rendered straight from a published
/// LilyPond edition, so the pitches and rhythms are exactly what is on the
/// page — which is the point, since the hand-written library before this was
/// typed out from memory and had an octave wrong in it.
///
/// What an engraving will not tell us is how the piece should sit in a game:
/// which note value the player counts as a beat, how loud each hand is, and
/// what to do with ornaments that no finger could catch. That is what this
/// does, from the [SongInfo] that `tool/build_library.dart` worked out at
/// build time.
abstract final class ScoreImport {
  /// Read a rendered score and shape it for play.
  static Song read(Uint8List midi, SongInfo info) {
    final raw = MidiReader.read(midi);

    final notes = <Note>[];
    for (final note in raw.notes) {
      if (note.duration < _ornamentBelow) continue; // an ornament; see below
      // [SongInfo.beatsPerQuarter] converts MIDI's quarter notes into the
      // beat the piece is felt in — 2 for a piece in eighths, which is how
      // 3/8 is counted.
      final beat = _snap(note.beat) * info.beatsPerQuarter;
      final duration = _snap(note.duration) * info.beatsPerQuarter;
      notes.add(Note(
        beat: beat,
        duration: duration,
        midi: note.midi,
        velocity: note.hand == Hand.left
            ? info.leftVelocity
            : info.rightVelocity,
        hand: note.hand,
      ));
    }

    return Song(
      id: info.id,
      title: info.title,
      composer: info.composer,
      bpm: info.bpm,
      beatsPerBar: info.beatsPerBar,
      source: info.source,
      notes: notes,
    );
  }

  /// Shorter than this, in quarter notes, and the note is an ornament.
  ///
  /// LilyPond gives a grace note a sliver of stolen time, far below any
  /// written value — the shortest real note in either of these pieces is a
  /// thirty-second, at 0.125. An ornament cannot be a touch of its own: it
  /// lands a few milliseconds before the note it decorates, which no finger
  /// can separate and no screen can draw apart. So it is dropped, and the
  /// note it was leading into is played plain.
  static const double _ornamentBelow = 0.0625;

  /// Divisions of a quarter note that every onset is rounded to.
  ///
  /// Forty-eight covers thirty-seconds and triplets alike, which is
  /// everything these two pieces use. Rounding matters because a chord whose
  /// notes land a few floating-point ticks apart would be drawn — and asked
  /// for — as several separate touches.
  static const double _grid = 48;

  static double _snap(double quarters) {
    final steps = (quarters * _grid).roundToDouble();
    // Nothing rounds away to silence: an on-grid note keeps at least one step.
    return (steps < 1 ? 1.0 : steps) / _grid;
  }
}
