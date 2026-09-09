import 'note.dart';

/// A piece the player can perform.
///
/// Songs come from two places — hand-written data in the library, and MIDI
/// files the player imports — so this is deliberately the only shape the rest
/// of the game knows about.
class Song {
  Song({
    required this.id,
    required this.title,
    required this.composer,
    required this.bpm,
    required List<Note> notes,
    this.beatsPerBar = 4,
    this.source = '',
  })  : assert(bpm > 0),
        assert(beatsPerBar > 0),
        notes = List.unmodifiable(_sorted(notes));

  final String id;
  final String title;
  final String composer;

  /// Written tempo. During play the conductor may follow the player instead,
  /// but this is what the piece is notated at.
  final double bpm;

  final int beatsPerBar;

  /// Every note, ordered by onset then pitch.
  final List<Note> notes;

  /// Where the music came from, and under what terms.
  final String source;

  static List<Note> _sorted(List<Note> notes) {
    final copy = [...notes];
    copy.sort((a, b) => a.beat != b.beat
        ? a.beat.compareTo(b.beat)
        : a.midi.compareTo(b.midi));
    return copy;
  }

  /// Notes the player taps.
  Iterable<Note> get melody => notes.where((n) => n.hand == Hand.right);

  /// Notes played for the player.
  Iterable<Note> get accompaniment => notes.where((n) => n.hand == Hand.left);

  /// Length in beats, to the end of the last note.
  double get lengthInBeats =>
      notes.fold(0.0, (max, n) => n.endBeat > max ? n.endBeat : max);

  Duration get duration => Duration(
      milliseconds: (lengthInBeats / bpm * 60 * 1000).round());

  /// Lowest and highest pitch, which the game uses to lay out the beams.
  (int, int) get pitchRange {
    if (notes.isEmpty) return (60, 60);
    var low = notes.first.midi;
    var high = notes.first.midi;
    for (final n in notes) {
      if (n.midi < low) low = n.midi;
      if (n.midi > high) high = n.midi;
    }
    return (low, high);
  }

  /// Notes grouped by onset: everything struck together is one tap.
  ///
  /// The tolerance absorbs the jitter of a human-performed MIDI file, where
  /// the notes of a chord land a few milliseconds apart.
  List<List<Note>> chordsOf(Iterable<Note> voice, {double tolerance = 0.03}) {
    final sorted = [...voice]..sort((a, b) => a.beat.compareTo(b.beat));
    final out = <List<Note>>[];
    for (final note in sorted) {
      if (out.isNotEmpty && note.beat - out.last.first.beat <= tolerance) {
        out.last.add(note);
      } else {
        out.add([note]);
      }
    }
    return out;
  }

  @override
  String toString() =>
      'Song($title, ${notes.length} notes, ${lengthInBeats.toStringAsFixed(1)} beats @ $bpm bpm)';
}
