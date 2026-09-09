import '../music/note.dart';
import '../music/song.dart';

/// How much of the song the player is responsible for.
///
/// The game this one takes after is at its best when a passage needs two,
/// three, even four fingers at once — that is the moment it stops feeling like
/// tapping and starts feeling like playing. The levels here are graded by how
/// much of the harmony is handed to the player rather than played for them.
enum Difficulty {
  /// Melody only, thinned so the notes never come faster than a beginner can
  /// answer, and a chord arrives under a single finger. For a first go.
  easy,

  /// The whole piece, chords under several fingers. Nothing plays itself:
  /// a note the player did not ask to be spared is a note taken away from
  /// them.
  normal,

  /// The whole piece, judged tightly. The notes are the same as normal; what
  /// changes is how close to the beat a tap has to land.
  hard,
}

extension DifficultyLabel on Difficulty {
  String get label => switch (this) {
        Difficulty.easy => 'Kolay',
        Difficulty.normal => 'Normal',
        Difficulty.hard => 'Zor',
      };

  String get description => switch (this) {
        Difficulty.easy => 'Tek parmak, sade ezgi',
        Difficulty.normal => 'Her nota senden, akorlar çok parmakla',
        Difficulty.hard => 'Aynı notalar, dar zamanlama',
      };
}

/// One thing the player taps: a single note, or notes that share a beam.
class Tap {
  Tap({
    required this.beat,
    required this.notes,
    required this.beam,
    required this.across,
  }) : assert(notes.isNotEmpty);

  /// When it should be played, in beats from the start of the song.
  final double beat;

  /// The notes that sound.
  final List<Note> notes;

  /// Which beam it travels down. Beams still exist as a way of grouping the
  /// notes of a chord onto separate fingers; they are no longer somewhere the
  /// player has to aim.
  final int beam;

  /// Where it sits across the screen, 0 at the lowest pitch in the song and 1
  /// at the highest. Continuous, so neighbouring pitches sit side by side
  /// instead of snapping into columns.
  final double across;

  /// How many fingers the moment this tap belongs to needs, counting every
  /// tap struck with it. Drives the colour, so the hand knows what is coming
  /// before it gets there.
  int fingers = 1;

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

/// A song laid out for play: what the player taps, and what plays itself.
///
/// Beams are the game's one real spatial cue. Putting them in pitch order —
/// low on the left, high on the right, like a keyboard — means a rising line
/// sweeps right, and the player reads the shape of the music before reading
/// any individual note. It also means the notes of a chord land on different
/// beams, which is what makes a chord a two- or three-finger gesture.
class Chart {
  Chart({
    required this.song,
    required this.beamCount,
    required this.difficulty,
    required List<Tap> taps,
    required List<Note> autoNotes,
  })  : taps = List.unmodifiable(taps),
        autoNotes = List.unmodifiable(autoNotes);

  final Song song;
  final int beamCount;
  final Difficulty difficulty;

  /// What the player plays, in time order.
  final List<Tap> taps;

  /// What the game plays on the player's behalf, in time order.
  final List<Note> autoNotes;

  static const int defaultBeamCount = 4;

  /// How many beams fit on a screen of a given width.
  ///
  /// This is what makes the difference between the two orientations a
  /// gameplay one rather than a cosmetic one. Portrait leaves room for four
  /// beams, which one thumb can cover. Landscape fits six: the low ones fall
  /// under the left thumb and the high ones under the right, which is how a
  /// pianist's hands divide a keyboard.
  ///
  /// The divisor is set so a portrait phone lands on four beams — about 97
  /// logical pixels each, twice the minimum comfortable touch target — and a
  /// sideways one on six. Six is the ceiling: past that a thumb cannot reach
  /// across without the hand leaving the phone.
  static int beamsForWidth(double width) => (width / 97).round().clamp(3, 6);

  static Chart build(
    Song song, {
    int beamCount = defaultBeamCount,
    Difficulty difficulty = Difficulty.normal,
  }) {
    assert(beamCount > 0);

    final (played, auto) = _divideVoices(song, difficulty);
    final chords = song.chordsOf(played);

    // Beams span the range the player actually covers, so every beam earns its
    // place however narrow the part is.
    var low = 127;
    var high = 0;
    for (final note in played) {
      if (note.midi < low) low = note.midi;
      if (note.midi > high) high = note.midi;
    }
    final span = (high - low).toDouble();

    /// Where a pitch sits across the screen, 0 to 1.
    double acrossOf(double pitch) =>
        span <= 0 ? 0.5 : ((pitch - low) / span).clamp(0.0, 1.0);

    int beamOf(double pitch) {
      if (span <= 0) return beamCount ~/ 2; // one pitch: centre it
      return (acrossOf(pitch) * beamCount).floor().clamp(0, beamCount - 1);
    }

    final taps = <Tap>[];
    for (final chord in chords) {
      if (difficulty == Difficulty.easy) {
        // One finger for the whole chord.
        final pitch =
            chord.map((n) => n.midi).reduce((a, b) => a + b) / chord.length;
        taps.add(Tap(
          beat: chord.first.beat,
          notes: chord,
          beam: beamOf(pitch),
          across: acrossOf(pitch),
        ));
        continue;
      }

      // Each note takes the beam its pitch belongs to; notes that land on the
      // same beam stay under one finger.
      final byBeam = <int, List<Note>>{};
      for (final note in chord) {
        (byBeam[beamOf(note.midi.toDouble())] ??= []).add(note);
      }
      for (final entry in byBeam.entries) {
        final pitch = entry.value.map((n) => n.midi).reduce((a, b) => a + b) /
            entry.value.length;
        taps.add(Tap(
          beat: chord.first.beat,
          notes: entry.value,
          beam: entry.key,
          across: acrossOf(pitch),
        ));
      }
    }
    taps.sort((a, b) => a.beat != b.beat
        ? a.beat.compareTo(b.beat)
        : a.across.compareTo(b.across));

    // Tell every tap how many fingers its moment needs.
    for (var i = 0; i < taps.length;) {
      var end = i;
      while (end < taps.length && (taps[end].beat - taps[i].beat).abs() <= 0.03) {
        end++;
      }
      for (var j = i; j < end; j++) {
        taps[j].fingers = end - i;
      }
      i = end;
    }

    return Chart(
      song: song,
      beamCount: beamCount,
      difficulty: difficulty,
      taps: taps,
      autoNotes: auto,
    );
  }

  /// Split the song into what the player plays and what plays itself.
  static (List<Note>, List<Note>) _divideVoices(
      Song song, Difficulty difficulty) {
    final melody = song.melody.toList();
    final accompaniment = song.accompaniment.toList();

    switch (difficulty) {
      case Difficulty.easy:
        // Dense passages are thinned rather than dropped: what the player is
        // not asked to hit is played for them, so the piece still sounds
        // whole. A run of sixteenth notes is a wall to a beginner, and a wall
        // teaches nothing except that they cannot play.
        const minGap = 0.5; // beats between one tap and the next
        final kept = <Note>[];
        final passed = <Note>[...accompaniment];
        var lastKept = double.negativeInfinity;

        for (final chord in _byOnset(melody)) {
          if (chord.first.beat >= lastKept + minGap - 0.001) {
            lastKept = chord.first.beat;
            kept.addAll(chord);
          } else {
            passed.addAll(chord);
          }
        }
        return (kept, passed);

      case Difficulty.normal:
      case Difficulty.hard:
        return ([...melody, ...accompaniment], const []);
    }
  }

  /// Group notes that are struck together.
  static List<List<Note>> _byOnset(List<Note> notes) {
    final sorted = [...notes]..sort((a, b) => a.beat.compareTo(b.beat));
    final out = <List<Note>>[];
    for (final note in sorted) {
      if (out.isNotEmpty && note.beat - out.last.first.beat <= 0.03) {
        out.last.add(note);
      } else {
        out.add([note]);
      }
    }
    return out;
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
      autoNotes.where((n) => n.beat >= fromBeat && n.beat < toBeat);

  double get lengthInBeats => song.lengthInBeats;
}
