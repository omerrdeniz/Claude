import '../music/note.dart';
import '../music/song.dart';

/// How much of the instrument the player is asked to be.
///
/// The steps are not "more notes" but three different skills, each built on
/// the one before: keeping time, keeping the hands apart, and fingering a
/// chord. That is the order a person actually learns a keyboard in.
enum Difficulty {
  /// One zone, one finger. A chord arrives under a single touch and dense
  /// runs are thinned. Only timing is being asked for.
  easy,

  /// The screen splits into a left hand and a right hand, and each has to be
  /// answered in its own half. A chord is still one touch per hand — what is
  /// new is that the two hands must work at once.
  normal,

  /// As normal, but a chord is only accepted under as many fingers as it has
  /// notes. Real fingering.
  hard,
}

extension DifficultyLabel on Difficulty {
  String get label => switch (this) {
        Difficulty.easy => 'Kolay',
        Difficulty.normal => 'Normal',
        Difficulty.hard => 'Zor',
      };

  String get description => switch (this) {
        Difficulty.easy => 'Tek alan, akorlar tek parmakla',
        Difficulty.normal => 'Eller ayrı, akorlar tek parmakla',
        Difficulty.hard => 'Eller ayrı, akorun her notası ayrı parmakla',
      };

  /// Whether the screen is divided between the hands.
  bool get separatesHands => this != Difficulty.easy;

  /// Whether a chord needs a finger per note.
  bool get fingersChords => this == Difficulty.hard;
}

/// One thing the player touches.
class Tap {
  Tap({
    required this.beat,
    required this.notes,
    required this.hand,
    required this.across,
  }) : assert(notes.isNotEmpty);

  /// When it should be played, in beats from the start of the song.
  final double beat;

  /// The notes that sound.
  final List<Note> notes;

  /// Which hand it belongs to. When the difficulty does not separate the
  /// hands this is still set, but nothing is matched against it.
  final Hand hand;

  /// Where it sits across the screen, 0 at the left edge and 1 at the right.
  /// For a touch carrying several notes this is their centre.
  final double across;

  /// Where each of its notes sits, in the same order as [notes].
  ///
  /// A chord is drawn as the notes it actually contains, at the pitches they
  /// actually are, even when the level lets one finger take them all. The
  /// player should see the music, not the input scheme.
  late final List<double> noteAcross;

  /// Which run of fast notes this touch belongs to, and where in it.
  ///
  /// A run is a stretch the hand cannot answer one tap at a time — see
  /// [Chart.runs]. Null for everything else, which is most of the music.
  int? runId;

  /// Position within [runId]'s run, counting from zero.
  int runIndex = 0;

  /// How many notes sound together in this hand at this moment.
  ///
  /// Counted in notes rather than touches on purpose: a three-note chord is a
  /// three-note chord whether the level asks for one finger or three, and the
  /// colour should say so either way. What changes with the level is how many
  /// fingers it takes, not what the music is.
  int voices = 1;

  /// The longest note in the touch.
  double get duration =>
      notes.map((n) => n.duration).reduce((a, b) => a > b ? a : b);

  /// Long enough that the finger is expected to stay down.
  bool get isHold => duration >= holdThreshold;

  /// Beats a note has to last before it is held rather than struck. Under
  /// this, asking for a hold would be asking for a press the hand cannot
  /// meaningfully control.
  static const double holdThreshold = 1.25;

  double get endBeat => beat + duration;

  @override
  String toString() =>
      'Tap(${beat.toStringAsFixed(2)}, ${hand.name}, ${notes.length} note(s))';
}

/// A song laid out for play: what the player touches, and what plays itself.
class Chart {
  Chart({
    required this.song,
    required this.difficulty,
    required List<Tap> taps,
    required List<Note> autoNotes,
    Map<int, List<Tap>> runs = const {},
  })  : taps = List.unmodifiable(taps),
        autoNotes = List.unmodifiable(autoNotes),
        runs = Map.unmodifiable(runs);

  final Song song;
  final Difficulty difficulty;

  /// What the player plays, in time order.
  final List<Tap> taps;

  /// What the game plays on the player's behalf, in time order.
  final List<Note> autoNotes;

  /// Stretches of notes that arrive faster than a finger can answer one at a
  /// time, keyed by id and each in time order.
  ///
  /// Beethoven's rondo has one sixty-two notes long and Chopin's cadenza runs
  /// at seventy-six milliseconds a note. Tapping those is not hard, it is
  /// impossible — and a passage nobody can play is a passage that teaches
  /// nothing. So a run is entered by tapping its first note and then carried
  /// by keeping the finger down and sliding it; see [PlaySession.drag].
  final Map<int, List<Tap>> runs;

  bool get separatesHands => difficulty.separatesHands;

  /// Where each hand's half of the screen begins and ends, with a gap down
  /// the middle so the two are plainly separate places.
  ///
  /// The outer edges stop short of the screen by more than a note's radius:
  /// a note placed hard against the edge has its glow clipped and sits under
  /// the hand holding the phone.
  static const double leftZoneStart = 0.09;
  static const double leftZoneEnd = 0.42;
  static const double rightZoneStart = 0.58;
  static const double rightZoneEnd = 0.91;

  /// Which hand a touch at [across] belongs to.
  static Hand handAt(double across) => across < 0.5 ? Hand.left : Hand.right;

  static Chart build(Song song, {Difficulty difficulty = Difficulty.normal}) {
    final (played, auto) = _divideVoices(song, difficulty);
    final taps = <Tap>[];

    // Pitch ranges, per hand when the hands are separated and overall when
    // they are not.
    final ranges = <Hand, (int, int)>{};
    for (final hand in Hand.values) {
      final inHand = difficulty.separatesHands
          ? played.where((n) => n.hand == hand)
          : played;
      if (inHand.isEmpty) continue;
      var low = 127;
      var high = 0;
      for (final n in inHand) {
        if (n.midi < low) low = n.midi;
        if (n.midi > high) high = n.midi;
      }
      ranges[hand] = (low, high);
    }

    double acrossOf(Hand hand, double pitch) {
      final range = ranges[hand];
      if (range == null) return 0.5;
      final (low, high) = range;
      final span = (high - low).toDouble();
      final position = span <= 0 ? 0.5 : ((pitch - low) / span).clamp(0.0, 1.0);
      if (!difficulty.separatesHands) {
        return leftZoneStart + position * (rightZoneEnd - leftZoneStart);
      }
      return hand == Hand.left
          ? leftZoneStart + position * (leftZoneEnd - leftZoneStart)
          : rightZoneStart + position * (rightZoneEnd - rightZoneStart);
    }

    for (final moment in _byOnset(played)) {
      // Within a moment, the hands are answered separately when the level
      // separates them; otherwise the whole moment is one touch.
      final groups = <Hand, List<Note>>{};
      for (final note in moment) {
        final hand = difficulty.separatesHands ? note.hand : Hand.right;
        (groups[hand] ??= []).add(note);
      }

      for (final entry in groups.entries) {
        final hand = entry.key;
        final notes = entry.value;
        if (difficulty.fingersChords) {
          for (final note in notes) {
            final at = acrossOf(hand, note.midi.toDouble());
            taps.add(Tap(
              beat: moment.first.beat,
              notes: [note],
              hand: hand,
              across: at,
            )..noteAcross = [at]);
          }
        } else {
          final places = [
            for (final note in notes) acrossOf(hand, note.midi.toDouble())
          ];
          taps.add(Tap(
            beat: moment.first.beat,
            notes: notes,
            hand: hand,
            across: places.reduce((a, b) => a + b) / places.length,
          )..noteAcross = places);
        }
      }
    }

    taps.sort((a, b) => a.beat != b.beat
        ? a.beat.compareTo(b.beat)
        : a.across.compareTo(b.across));

    // Tell every touch how many fingers its hand needs at that moment.
    for (var i = 0; i < taps.length;) {
      var end = i;
      while (end < taps.length &&
          (taps[end].beat - taps[i].beat).abs() <= onsetTolerance) {
        end++;
      }
      for (var j = i; j < end; j++) {
        taps[j].voices = taps
            .sublist(i, end)
            .where((t) => t.hand == taps[j].hand)
            .fold(0, (sum, t) => sum + t.notes.length);
      }
      i = end;
    }

    return Chart(
      song: song,
      difficulty: difficulty,
      taps: taps,
      autoNotes: auto,
      runs: _findRuns(taps, song, difficulty.separatesHands),
    );
  }

  /// The most a run's notes may be apart, in seconds.
  ///
  /// Not a claim about what a hand can do in general — a practised one taps
  /// faster than this. It is where a *stranger's* hand stops being able to
  /// pick out individual notes and starts needing the whole passage to be one
  /// gesture, which is the moment this game is built around.
  static const double runGapSeconds = 0.15;

  /// How many notes in a row it takes to be worth sliding through. Two fast
  /// notes are a flourish; three are a run.
  static const int runLength = 3;

  /// Find the stretches too fast to tap, hand by hand.
  ///
  /// Hand by hand because the two are answered separately and independently:
  /// a left-hand chord landing in the middle of a right-hand run does not
  /// interrupt it, and should not break the slide.
  ///
  /// Notes struck *together* end a run rather than extending it — a chord is
  /// not a fast passage, it is one moment with several notes in it, and the
  /// hard level splits it into a touch per note.
  static Map<int, List<Tap>> _findRuns(
      List<Tap> taps, Song song, bool separatesHands) {
    final secondsPerBeat = 60 / song.bpm;
    final byHand = <Hand, List<Tap>>{};
    for (final tap in taps) {
      (byHand[separatesHands ? tap.hand : Hand.right] ??= []).add(tap);
    }

    final runs = <int, List<Tap>>{};
    var nextId = 1;
    for (final line in byHand.values) {
      var start = 0;
      for (var i = 1; i <= line.length; i++) {
        final gapBeats =
            i < line.length ? line[i].beat - line[i - 1].beat : double.infinity;
        final continues =
            gapBeats > onsetTolerance && gapBeats * secondsPerBeat <= runGapSeconds;
        if (continues) continue;

        if (i - start >= runLength) {
          final run = line.sublist(start, i);
          final id = nextId++;
          for (var j = 0; j < run.length; j++) {
            run[j].runId = id;
            run[j].runIndex = j;
          }
          runs[id] = List.unmodifiable(run);
        }
        start = i;
      }
    }
    return runs;
  }

  /// How far apart two notes can be and still count as struck together. Wide
  /// enough to absorb the jitter of a human-performed MIDI file.
  static const double onsetTolerance = 0.03;

  /// Split the song into what the player plays and what plays itself.
  static (List<Note>, List<Note>) _divideVoices(
      Song song, Difficulty difficulty) {
    final all = [...song.melody, ...song.accompaniment];
    if (difficulty != Difficulty.easy) return (all, const []);

    // Easy thins dense passages rather than dropping them: what the player is
    // not asked to hit is played for them, so the piece still sounds whole. A
    // run of sixteenth notes is a wall to a beginner, and a wall teaches
    // nothing except that they cannot play.
    const minGap = 0.5; // beats between one touch and the next
    final kept = <Note>[];
    final passed = <Note>[];
    var lastKept = double.negativeInfinity;

    for (final moment in _byOnset(all)) {
      if (moment.first.beat >= lastKept + minGap - 0.001) {
        lastKept = moment.first.beat;
        kept.addAll(moment);
      } else {
        passed.addAll(moment);
      }
    }
    return (kept, passed);
  }

  /// Group notes that are struck together.
  static List<List<Note>> _byOnset(List<Note> notes) {
    final sorted = [...notes]..sort((a, b) => a.beat.compareTo(b.beat));
    final out = <List<Note>>[];
    for (final note in sorted) {
      if (out.isNotEmpty &&
          note.beat - out.last.first.beat <= onsetTolerance) {
        out.last.add(note);
      } else {
        out.add([note]);
      }
    }
    return out;
  }

  /// Touches close enough to the hit line to be on screen.
  ///
  /// [window] is how far ahead the player can see, in beats; the small margin
  /// behind keeps a touch visible just long enough for a late hit to land on,
  /// and no longer — a note lingering under the line reads as still playable.
  Iterable<Tap> visibleAt(double beat, double window) sync* {
    for (final tap in taps) {
      if (tap.beat > beat + window) break; // taps are in time order
      if (tap.endBeat >= beat - 0.3) yield tap;
    }
  }

  /// Notes the game plays on the player's behalf, between two moments.
  Iterable<Note> accompanimentBetween(double fromBeat, double toBeat) =>
      autoNotes.where((n) => n.beat >= fromBeat && n.beat < toBeat);

  double get lengthInBeats => song.lengthInBeats;
}
