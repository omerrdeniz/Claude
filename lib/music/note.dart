/// Which hand plays a note.
///
/// The game only asks the player to tap one voice; the other is played for
/// them. Melody is normally the right hand, so this also decides what the
/// player is responsible for.
enum Hand { right, left }

/// A single note in a song.
///
/// Times are in beats rather than seconds on purpose: a beat is what the
/// player feels, and it lets tempo change — including following the player's
/// own timing — without rewriting the song.
class Note {
  const Note({
    required this.beat,
    required this.midi,
    required this.duration,
    this.velocity = 0.75,
    this.hand = Hand.right,
  })  : assert(beat >= 0),
        assert(duration > 0),
        assert(midi >= 0 && midi <= 127),
        assert(velocity > 0 && velocity <= 1);

  /// Onset, in beats from the start of the song.
  final double beat;

  /// MIDI note number: 60 is middle C, 69 is A440.
  final int midi;

  /// How long the note sounds, in beats.
  final double duration;

  /// How hard it is struck, 0..1.
  final double velocity;

  final Hand hand;

  double get endBeat => beat + duration;

  Note copyWith({
    double? beat,
    int? midi,
    double? duration,
    double? velocity,
    Hand? hand,
  }) {
    return Note(
      beat: beat ?? this.beat,
      midi: midi ?? this.midi,
      duration: duration ?? this.duration,
      velocity: velocity ?? this.velocity,
      hand: hand ?? this.hand,
    );
  }

  @override
  String toString() =>
      'Note(${beat.toStringAsFixed(3)}, $midi, ${duration.toStringAsFixed(3)}, ${hand.name})';

  @override
  bool operator ==(Object other) =>
      other is Note &&
      other.beat == beat &&
      other.midi == midi &&
      other.duration == duration &&
      other.velocity == velocity &&
      other.hand == hand;

  @override
  int get hashCode => Object.hash(beat, midi, duration, velocity, hand);
}
