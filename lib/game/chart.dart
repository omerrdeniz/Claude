import '../music/note.dart';
import '../music/song.dart';

/// One thing the player taps: a single note, or a chord struck together.
class Tap {
  Tap({required this.beat, required this.notes, required this.beam})
      : assert(notes.isNotEmpty);

  /// When it should be played, in beats from the start of the song.
  final double beat;

  /// The notes that sound. More than one means a chord under one finger.
  final List<Note> notes;

  /// Which beam it travels down.
  final int beam;

  /// The longest note in the tap — how long the beam should stay lit.
  double get duration =>
      notes.map((n) => n.duration).reduce((a, b) => a > b ? a : b);

  /// A note long enough to be worth holding rather than striking.
  bool get isHold => duration >= 1.5;

  /// Average pitch, which is what decides the beam.
  double get pitch =>
      notes.map((n) => n.midi).reduce((a, b) => a + b) / notes.length;

  @override
  String toString() =>
      'Tap(${beat.toStringAsFixed(2)}, beam $beam, ${notes.length} note(s))';
}

/// A song laid out for play: the melody grouped into taps, each assigned to a
/// beam by pitch.
///
/// Beams are the game's one real spatial cue. Putting them in pitch order —
/// low on the left, high on the right, like a keyboard — means a rising line
/// sweeps right, and the player reads the shape of the music before reading
/// any individual note.
class Chart {
  Chart({
    required this.song,
    required this.beamCount,
    required List<Tap> taps,
  }) : taps = List.unmodifiable(taps);

  final Song song;
  final int beamCount;
  final List<Tap> taps;

  static const int defaultBeamCount = 4;

  static Chart build(Song song, {int beamCount = defaultBeamCount}) {
    assert(beamCount > 0);
    final chords = song.chordsOf(song.melody);

    // Spread beams across the range this song actually uses, not the whole
    // keyboard, so every beam earns its place however narrow the tune is.
    var low = 127;
    var high = 0;
    for (final chord in chords) {
      for (final note in chord) {
        if (note.midi < low) low = note.midi;
        if (note.midi > high) high = note.midi;
      }
    }
    final span = (high - low).toDouble();

    final taps = <Tap>[];
    for (final chord in chords) {
      final pitch = chord.map((n) => n.midi).reduce((a, b) => a + b) / chord.length;
      // A song on one pitch has no spread to divide; centre it.
      final position = span <= 0 ? 0.5 : (pitch - low) / span;
      final beam =
          (position * beamCount).floor().clamp(0, beamCount - 1);
      taps.add(Tap(beat: chord.first.beat, notes: chord, beam: beam));
    }
    return Chart(song: song, beamCount: beamCount, taps: taps);
  }

  /// Taps close enough to the hit line to be on screen.
  ///
  /// [window] is how far ahead the player can see, in beats; the small margin
  /// behind keeps a tap visible just long enough for a late hit to land on,
  /// and no longer — a note lingering under the line reads as still playable.
  Iterable<Tap> visibleAt(double beat, double window) sync* {
    for (final tap in taps) {
      if (tap.beat > beat + window) break; // taps are in time order
      if (tap.beat >= beat - 0.3) yield tap;
    }
  }

  /// Notes the game plays on the player's behalf, between two moments.
  Iterable<Note> accompanimentBetween(double fromBeat, double toBeat) =>
      song.accompaniment.where((n) => n.beat >= fromBeat && n.beat < toBeat);

  double get lengthInBeats => song.lengthInBeats;
}
