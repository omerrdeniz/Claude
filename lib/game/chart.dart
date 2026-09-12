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

  /// Notes crushed into this touch: an ornament sounding an instant before
  /// the notes it decorates, from the same finger.
  ///
  /// An acciaccatura is written as a note but is not one to play: it lands
  /// some sixty milliseconds before the note it leans into, which no hand can
  /// answer as a second touch. So it rides the touch it belongs to, and the
  /// game gives the gap between them — see [PlaySession].
  List<Note> grace = const [];

  bool get hasGrace => grace.isNotEmpty;

  /// Where the ornament sits across the screen, as [across] does.
  double graceAcross = 0;

  /// Which way the ornament leans: 1 where the touch is above the ornament
  /// and the hand moves right, -1 where it is below and the hand moves left.
  /// 0 where there is no ornament.
  ///
  /// This is the whole of what the flick asks for. The *distance* between an
  /// ornament and its note cannot be asked for: most of them are a semitone
  /// or two, which on a screen where place comes from pitch is a few pixels —
  /// too small to aim at and too small to see. Direction is real, size is not.
  int get graceLean {
    if (grace.isEmpty) return 0;
    final mine = notes.map((n) => n.midi).reduce((a, b) => a + b) / notes.length;
    final its = grace.map((n) => n.midi).reduce((a, b) => a + b) / grace.length;
    return mine == its ? 0 : (mine > its ? 1 : -1);
  }

  /// The longest note in the touch.
  double get duration =>
      notes.map((n) => n.duration).reduce((a, b) => a > b ? a : b);

  /// Long enough that the finger is expected to stay down.
  bool get isHold => duration >= holdFrom;

  /// Whether this hand is asked for something else before this touch ends.
  ///
  /// Set by [Chart.build]. A hand has one finger here, so where a held note
  /// still has time to run and the next note is already due, the player has
  /// no choice but to lift — and the note has to go on sounding anyway,
  /// because that is what the music says. Bach's left hand does this under
  /// every bar of the first prelude; Satie's does it in both hands.
  bool sustains = false;

  /// Where this touch's tail is *drawn* to: the next touch this hand has, or
  /// the note's own end if nothing comes before it.
  ///
  /// The sound still lasts as long as the edition says. The picture stops at
  /// the next thing the hand is asked for, because that is what the player
  /// needs to know — how long to stay before moving. Drawn to the written
  /// end instead, a hand full of overlapping notes reads as a ladder of bars
  /// with the notes buried in it.
  double drawnEndBeat = 0;

  /// How long this touch has to last to be held rather than struck, in this
  /// song's beats. Set by [Chart.build] from the tempo.
  ///
  /// The default is what [holdSeconds] comes to at 120 beats a minute, for a
  /// touch built outside a chart.
  double holdFrom = holdSeconds * 2;

  /// Seconds a note has to last before it is held rather than struck. Under
  /// this, asking for a hold would be asking for a press the hand cannot
  /// meaningfully control.
  ///
  /// **In seconds, and that matters.** It used to be beats, which meant it
  /// was a different length of time in every piece: 469 ms in the Ode, 1364
  /// in the canon. A hand does not know what a beat is. The canon showed it
  /// plainly — its walking bass is a quarter note at 55, which rings for
  /// 1.09 seconds and sounds held to anybody listening, but fell short of a
  /// 1.25-beat threshold and was drawn as a tap. Five of its eight hundred
  /// touches were holds; now two hundred and ninety-three are, which is what
  /// the piece actually is.
  static const double holdSeconds = 0.7;

  /// An ornament's own length, and how long before its note it may land, in
  /// seconds. Longer than this and it is a note in its own right.
  ///
  /// Satie's first Gnossienne settles the number on its own: all hundred of
  /// its ornaments are 63 ms long and land 63 ms before the note they lean
  /// into, every one of them. Twice that leaves room for another edition to
  /// write them a little wider without letting an ordinary short note in.
  static const double graceSeconds = 0.12;

  /// How long the note being decorated has to last, in seconds.
  ///
  /// Without this a wall of fast notes reads as ornament after ornament:
  /// in a run everything is short, and what makes an ornament an ornament is
  /// that it leans into something that stays. It is what tells the two apart
  /// in Handel's passacaglia, where the loose rule found 119 and the true
  /// count is 26.
  static const double graceMainSeconds = 0.25;

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

  /// The lowest and highest note in the piece, worked out once.
  ///
  /// The painter colours every note against it and would otherwise ask the
  /// song to count its own notes on every frame.
  late final (int, int) pitchRange = song.pitchRange;

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
    final onsetTolerance = onsetToleranceAt(song.bpm);
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

    for (final moment in _byOnset(played, onsetTolerance)) {
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

    _crushOrnaments(taps, song);

    // How long a note has to last, in this song's beats, to be held.
    final holdFrom = Tap.holdSeconds * song.bpm / 60;
    for (final tap in taps) {
      tap.holdFrom = holdFrom;
    }
    _markSustained(taps, difficulty.separatesHands);

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

  /// A run ends where its notes stop being close together — there is no
  /// second, wider threshold that carries one over a breath.
  ///
  /// There was, briefly. The canon's semiquaver variations breathe every
  /// fourth note, 273 ms where the rest are 136, and carrying across that
  /// turned ten bars into two runs of seventy-nine and a hundred and twelve
  /// notes. It was the wrong reading: the player, who can see the notes,
  /// said plainly that the gap is there and the thread should not be drawn
  /// straight through it. A run is what arrives faster than a hand can
  /// answer, and after 273 ms a hand has answered.

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
    final onsetTolerance = onsetToleranceAt(song.bpm);
    final byHand = <Hand, List<Tap>>{};
    for (final tap in taps) {
      (byHand[separatesHands ? tap.hand : Hand.right] ??= []).add(tap);
    }

    final runs = <int, List<Tap>>{};
    var nextId = 1;
    for (final line in byHand.values) {
      var start = 0;
      // Whether anything in the chain so far was fast enough to make it a
      // run. Until something is, a wide gap is just a wide gap.
      var running = false;

      for (var i = 1; i <= line.length; i++) {
        final gap = i < line.length
            ? (line[i].beat - line[i - 1].beat) * secondsPerBeat
            : double.infinity;
        final together = gap <= onsetTolerance * secondsPerBeat;

        if (!together && gap <= runGapSeconds) {
          running = true;
          continue;
        }

        if (running && i - start >= runLength) {
          final run = line.sublist(start, i);
          final id = nextId++;
          for (var j = 0; j < run.length; j++) {
            run[j].runId = id;
            run[j].runIndex = j;
          }
          runs[id] = List.unmodifiable(run);
        }
        start = i;
        running = false;
      }
    }
    return runs;
  }

  /// Fold each ornament into the touch it decorates.
  ///
  /// An acciaccatura — the small note with a stroke through its stem — is
  /// played by crushing it into the note it leans on: one movement of the
  /// hand, not two touches. Left as a touch of its own it asks for a second
  /// finger sixty milliseconds after the first, which nobody can give, so
  /// every one of them was missed. Satie's first Gnossienne has a hundred.
  ///
  /// What it looks like in the notes: a short note, landing a breath before a
  /// long one in the same hand. Both breaths are measured in seconds, because
  /// a hand does not know what a beat is.
  static void _crushOrnaments(List<Tap> taps, Song song) {
    final grace = Tap.graceSeconds * song.bpm / 60;
    final mainLeast = Tap.graceMainSeconds * song.bpm / 60;

    // By the hand that plays it, whatever the level does with the hands. An
    // ornament belongs to one hand by definition — it is the same finger
    // rolling into the next note. Grouping by zone instead, as the easy level
    // would, crushed one hand's note into the other's.
    final byHand = <Hand, List<Tap>>{};
    for (final tap in taps) {
      (byHand[tap.hand] ??= []).add(tap);
    }

    final crushed = <Tap>{};
    for (final line in byHand.values) {
      for (var i = 0; i < line.length - 1; i++) {
        final ornament = line[i], main = line[i + 1];
        final gap = main.beat - ornament.beat;
        if (gap <= 0 || gap > grace) continue;
        if (ornament.duration > grace) continue;
        if (main.duration < mainLeast) continue;
        main.grace = ornament.notes;
        main.graceAcross = ornament.across;
        crushed.add(ornament);
      }
    }
    taps.removeWhere(crushed.contains);
  }

  /// Say which touches have to keep sounding after the finger has gone.
  ///
  /// A touch is sustained if the same hand is asked for another one before
  /// this touch's written end. There is one finger to a hand, so the player
  /// cannot both hold this and answer that; the game must not take the note
  /// away from them for doing the only thing they can do.
  static void _markSustained(List<Tap> taps, bool separatesHands) {
    final byHand = <Hand, List<Tap>>{};
    for (final tap in taps) {
      (byHand[separatesHands ? tap.hand : Hand.right] ??= []).add(tap);
    }
    for (final line in byHand.values) {
      for (var i = 0; i < line.length; i++) {
        line[i].drawnEndBeat = line[i].endBeat;
        for (var j = i + 1; j < line.length; j++) {
          if (line[j].beat <= line[i].beat) continue; // struck together
          if (line[j].beat < line[i].endBeat) {
            line[i].sustains = true;
            line[i].drawnEndBeat = line[j].beat;
          }
          break;
        }
      }
    }
  }

  /// How far apart two notes can be and still count as struck together, in
  /// seconds.
  ///
  /// Wide enough to absorb the jitter of a human-performed MIDI file, and to
  /// take in the ornaments some editions write out as real notes rather than
  /// grace notes — the Minute Waltz has a pair twenty-two milliseconds apart,
  /// which no hand plays as two touches and no ear hears as two attacks.
  ///
  /// **In seconds, and that matters.** It was in beats, which made it 14 ms
  /// in the Rondo and 33 in the canon; the third setting in this game to
  /// have been written in beats and mean something different in every piece.
  static const double onsetSeconds = 0.03;

  /// The same, in the beats of a piece at [bpm].
  static double onsetToleranceAt(double bpm) => onsetSeconds * bpm / 60;

  /// Split the song into what the player plays and what plays itself.
  static (List<Note>, List<Note>) _divideVoices(
      Song song, Difficulty difficulty) {
    final onsetTolerance = onsetToleranceAt(song.bpm);
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

    final moments = _byOnset(all, onsetTolerance);
    final leans = [
      for (var i = 0; i < moments.length; i++)
        _leansInto(moments[i], i + 1 < moments.length ? moments[i + 1] : null,
            song.bpm)
    ];

    for (var i = 0; i < moments.length; i++) {
      // An ornament is not a moment of its own: it stands or falls with the
      // note it leans into. Deciding them apart is how Satie's Gnossienne
      // came out with its hundred small notes kept and the melody they lean
      // on played by the game — the thinning met the ornament first, kept it
      // because it was first, and dropped the note a tenth of a beat later.
      if (leans[i]) continue;
      final moment = moments[i];
      final ornament = i > 0 && leans[i - 1] ? moments[i - 1] : const <Note>[];

      if (moment.first.beat >= lastKept + minGap - 0.001) {
        lastKept = moment.first.beat;
        kept.addAll(ornament);
        kept.addAll(moment);
      } else {
        passed.addAll(ornament);
        passed.addAll(moment);
      }
    }
    return (kept, passed);
  }

  /// Whether [moment] is an ornament crushed into [next].
  ///
  /// The same rule [_crushOrnaments] uses, asked of notes rather than
  /// touches: short itself, landing a breath before something that stays.
  static bool _leansInto(List<Note> moment, List<Note>? next, double bpm) {
    if (next == null) return false;
    final grace = Tap.graceSeconds * bpm / 60;
    final mainLeast = Tap.graceMainSeconds * bpm / 60;
    double longest(List<Note> ns) =>
        ns.map((n) => n.duration).reduce((a, b) => a > b ? a : b);
    final gap = next.first.beat - moment.first.beat;
    return gap > 0 &&
        gap <= grace &&
        longest(moment) <= grace &&
        longest(next) >= mainLeast;
  }

  /// Group notes that are struck together.
  static List<List<Note>> _byOnset(List<Note> notes, double onsetTolerance) {
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
