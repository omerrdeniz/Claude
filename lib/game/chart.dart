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

  /// Which figure this touch belongs to, and which step of it.
  ///
  /// A figure is a stretch fast enough that tapping every note of it is a
  /// chore rather than a pleasure — see [Chart.figures]. Null for everything
  /// else. [figureStep] is -1 on the touch that catches the figure, which is
  /// tapped like any other, and the step's index on the rest.
  int? figureId;
  int figureStep = -1;

  /// The movement the hand has to make *from this note*, if any.
  ///
  /// The mark used to sit on the first note of the step it opened, which is
  /// not the note the hand is on when it has to move: *"hangi nota hangi yön
  /// hepsi karışıyor."* A movement is made from somewhere. So it is written
  /// on the note the finger is already on — the touch that catches the
  /// figure for the first movement, and the last note of the movement before
  /// for the rest.
  Swipe? figureTurn;

  /// Position within [runId]'s run, counting from zero.
  int runIndex = 0;

  /// The earliest beat this run may put its bead on the line. Meaningful on
  /// the first touch of a run and ignored everywhere else.
  ///
  /// A bead wants as much warning as it can get — see
  /// [PlaySession.dragLeadMs] — but not so much that it is sitting on the
  /// line while the hand still has an ordinary note to play there. The canon
  /// has three-note runs a second apart, and a nine-hundred-millisecond lead
  /// put a ring under every note between them: *"birleştirme olmayan
  /// notalarda da çizgi üzerinde boş yuvarlak çıkıyor."* So it never comes
  /// out before the hand's previous touch has had its moment.
  double runOpensAt = 0;

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

  /// The pitch the ornament is drawn and lit in. Where it is more than one
  /// note the lowest names it, which is the one the ear hears it as.
  int? get graceMidi => grace.isEmpty
      ? null
      : grace.map((note) => note.midi).reduce((a, b) => a < b ? a : b);

  /// How far in front of this touch its ornament lands, in beats.
  ///
  /// One touch sounds both, the little note first — see
  /// [PlaySession._sound]. So the two do not happen at the same instant, and
  /// the screen should not say they did.
  double get graceLeadBeats => grace.isEmpty ? 0 : beat - grace.first.beat;

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
    final mine =
        notes.map((n) => n.midi).reduce((a, b) => a + b) / notes.length;
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

  /// And whether the touch it stops at carries an ornament.
  ///
  /// The ornament's mark is drawn *below* its touch — sooner is nearer the
  /// line — so a tail that stops at that touch runs straight through it. The
  /// picture has to leave room for the little note as well as the big one.
  bool drawnEndOrnamented = false;

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

/// Which way the hand is asked to move.
///
/// Left and right mean what they do on the screen, which is down and up in
/// pitch. Up and down mean nothing musically and are used where the music
/// does not move — a figure that turns on itself, like the Rondo's opening —
/// so the hand still has something to do that is not the same as last time.
enum Swipe { left, right, up, down }

/// The notes of a figure one movement of the hand is worth, and which way.
///
/// See [Chart.figures].
class FigureStep {
  FigureStep({required this.taps, required this.direction, required this.from});

  final List<Tap> taps;
  final Swipe direction;

  /// The note the hand is on when it has to move: the touch that catches the
  /// figure for the first movement, the last note of the movement before for
  /// the rest. Where the mark goes, and where the ribbon starts.
  final Tap from;
}

/// A song laid out for play: what the player touches, and what plays itself.
class Chart {
  Chart({
    required this.song,
    required this.difficulty,
    required List<Tap> taps,
    required List<Note> autoNotes,
    Map<int, List<Tap>> runs = const {},
    Map<int, List<FigureStep>> figures = const {},
  }) : taps = List.unmodifiable(taps),
       autoNotes = List.unmodifiable(autoNotes),
       runs = Map.unmodifiable(runs),
       figures = Map.unmodifiable(figures);

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

  /// Stretches the hand can answer one note at a time but has no fun doing,
  /// keyed by id and cut into the steps that play them.
  ///
  /// Not the same thing as a [runs]. A run is *impossible* to tap — seventy
  /// milliseconds a note — and is carried by keeping a finger on a bead. A
  /// figure is merely relentless: a fifth of a second a note, for pages. The
  /// player can hit every one of them and said, twice and about two different
  /// pieces, that doing so is what takes the pleasure out: *"arka arkaya
  /// gelen hızlı notalara sürekli basmaya çalışmak oyun zevkini ciddi
  /// azaltıyor."*
  ///
  /// The measurement that settles it: the notes that wear the player out in
  /// the Rondo and in the Entertainer are the same distance apart, a fifth of
  /// a second, and our run rule had always answered *"a hand can do that"* —
  /// which is true, and the wrong question. This one asks whether it is worth
  /// doing.
  ///
  /// So: the first note is tapped like any other, and the rest come in steps
  /// of two or three, each played by moving the hand the way the step says.
  /// A gesture for every two or three notes instead of a tap for every one.
  final Map<int, List<FigureStep>> figures;

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

  /// The share of a hand's notes at each end of its range that count as rare
  /// rather than as the range itself.
  ///
  /// A fiftieth. Small enough that it only ever discounts notes a piece
  /// visits a handful of times, which is exactly what stretches a range
  /// without filling it.
  static const double pitchTailShare = 0.05;

  /// The share of a hand's zone kept at each end for those rare notes.
  ///
  /// A tenth each, so the common range gets the middle four fifths. They are
  /// not simply pinned to the edge: a run climbing out of the common range
  /// would stop moving across the screen half way up, which the picture must
  /// never say.
  static const double pitchEdgeShare = 0.05;

  static Chart build(Song song, {Difficulty difficulty = Difficulty.normal}) {
    final onsetTolerance = onsetToleranceAt(song.bpm);
    final (played, auto) = _divideVoices(song, difficulty);
    final taps = <Tap>[];

    // Pitch ranges, per hand when the hands are separated and overall when
    // they are not.
    //
    // Four numbers rather than two: the outright lowest and highest, and the
    // lowest and highest of all but the rarest [pitchTailShare] at each end.
    // Spreading a hand over its outright range hands the whole width to its
    // extremes, and a piece has extremes it visits twice — the Rondo's right
    // hand runs to a top C it plays four times in nine hundred notes, and
    // stretching to reach it left nine notes in ten crammed into the left
    // half of the hand's zone: *"notalar hep belirli yerlerde toplanıyor."*
    final ranges = <Hand, (int, int, int, int)>{};
    for (final hand in Hand.values) {
      final inHand = difficulty.separatesHands
          ? played.where((n) => n.hand == hand)
          : played;
      if (inHand.isEmpty) continue;
      final sorted = [for (final n in inHand) n.midi]..sort();
      final tail = (sorted.length * pitchTailShare).floor();
      ranges[hand] = (
        sorted.first,
        sorted[tail],
        sorted[sorted.length - 1 - tail],
        sorted.last,
      );
    }

    /// Where a pitch sits within its hand's zone, 0 at the left of it and 1
    /// at the right.
    ///
    /// The common range gets the middle [1 - 2 * pitchEdgeShare] of the zone
    /// and the rare notes beyond it share the strips at either end. Still one
    /// note one place, and still higher further right — what changes is that
    /// the width goes to the notes that use it.
    double placeOf(double pitch, int low, int common, int high, int far) {
      if (pitch < common) {
        return common <= low
            ? 0.0
            : pitchEdgeShare * (pitch - low) / (common - low);
      }
      if (pitch > high) {
        return far <= high
            ? 1.0
            : 1 - pitchEdgeShare + pitchEdgeShare * (pitch - high) / (far - high);
      }
      if (high <= common) return 0.5;
      return pitchEdgeShare +
          (1 - 2 * pitchEdgeShare) * (pitch - common) / (high - common);
    }

    double acrossOf(Hand hand, double pitch) {
      final range = ranges[hand];
      if (range == null) return 0.5;
      final (low, common, high, far) = range;
      final position = placeOf(pitch, low, common, high, far).clamp(0.0, 1.0);
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
            taps.add(
              Tap(
                beat: moment.first.beat,
                notes: [note],
                hand: hand,
                across: at,
              )..noteAcross = [at],
            );
          }
        } else {
          final places = [
            for (final note in notes) acrossOf(hand, note.midi.toDouble()),
          ];
          taps.add(
            Tap(
              beat: moment.first.beat,
              notes: notes,
              hand: hand,
              across: places.reduce((a, b) => a + b) / places.length,
            )..noteAcross = places,
          );
        }
      }
    }

    taps.sort(
      (a, b) => a.beat != b.beat
          ? a.beat.compareTo(b.beat)
          : a.across.compareTo(b.across),
    );

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
      figures: _findFigures(taps, song, difficulty.separatesHands),
    );
  }

  /// Cut the relentless stretches into figures, and those into steps.
  ///
  /// A figure is a stretch of one hand's touches, each within
  /// [figureGapSeconds] of the last, and at least [figureLeastTouches] of
  /// them. Notes already in a run are left out:
  /// a run cannot be tapped at all and has its own answer, and two mechanics
  /// on one note is one too many.
  static Map<int, List<FigureStep>> _findFigures(
    List<Tap> taps,
    Song song,
    bool separatesHands,
  ) {
    final secondsPerBeat = 60 / song.bpm;
    final onsetTolerance = onsetToleranceAt(song.bpm);
    final byHand = <Hand, List<Tap>>{};
    for (final tap in taps) {
      if (tap.runId != null) continue;
      (byHand[separatesHands ? tap.hand : Hand.right] ??= []).add(tap);
    }

    final figures = <int, List<FigureStep>>{};
    var nextId = 1;
    for (final line in byHand.values) {
      var start = 0;
      for (var i = 1; i <= line.length; i++) {
        final gap = i < line.length
            ? (line[i].beat - line[i - 1].beat) * secondsPerBeat
            : double.infinity;
        if (gap > onsetTolerance * secondsPerBeat && gap <= figureGapSeconds) {
          continue;
        }
        if (i - start >= figureLeastTouches) {
          final id = nextId++;
          figures[id] = _cutIntoSteps(
            line.sublist(start, i),
            id,
            secondsPerBeat,
          );
        }
        start = i;
      }
    }
    return figures;
  }

  /// Divide a figure into the steps a hand answers it in.
  ///
  /// The first touch is the catch: tapped like any other note, because a
  /// figure has to be *entered* and because the oldest rule in the game says
  /// the player's finger is what makes the first sound. The rest go by the
  /// clock: [figureStepSeconds] of music to a movement, never one note on its
  /// own, and never one left behind at the end.
  ///
  /// A movement used to be worth three notes whatever they were, and three
  /// notes is a different amount of time in every passage. Für Elise's
  /// opening runs nine sixteenths in eight tenths of a second, so the hand
  /// was asked for three movements — three *different* directions — inside
  /// one second: *"şu anda sürüklemeye devam etmem gerekiyor gibi."* The
  /// player is a hand, not a note counter, and how often it is asked to do
  /// something is a length of time. Seconds, not notes — the same reason the
  /// timing tolerances are in seconds and not beats.
  static List<FigureStep> _cutIntoSteps(
    List<Tap> figure,
    int id,
    double secondsPerBeat,
  ) {
    figure.first.figureId = id;
    figure.first.figureStep = -1;

    final rest = figure.sublist(1);
    final steps = <FigureStep>[];
    var at = 0;
    while (at < rest.length) {
      final left = rest.length - at;
      final opens = rest[at].beat;
      var take = 1;
      while (take < left &&
          (rest[at + take].beat - opens) * secondsPerBeat <=
              figureStepSeconds) {
        take += 1;
      }
      // Never one on its own: a gesture for a single note is no saving at all.
      if (take < 2 && left >= 2) take = 2;
      // And never one left behind: two remaining come along.
      if (left - take == 1) take = left;
      final notes = rest.sublist(at, at + take);

      // Which way the hand goes. Measured from where it was — the note before
      // the step — to where the step ends, so a step that climbs reads as a
      // climb however it wanders on the way.
      final from = rest[at - 1 > -1 ? at - 1 : 0];
      final before = at == 0 ? figure.first : from;
      final net = notes.last.notes.first.midi - before.notes.first.midi;

      // The music stays where it is — the Rondo's opening turns on two notes
      // for five beats — or it goes the way the hand is already going. Either
      // way there is nothing to point at, so the hand is asked for the other
      // axis, and for the opposite of last time so it keeps moving.
      final other = steps.isNotEmpty && steps.last.direction == Swipe.up
          ? Swipe.down
          : Swipe.up;
      var direction = net >= figureTurnSemitones
          ? Swipe.right
          : net <= -figureTurnSemitones
          ? Swipe.left
          : other;
      // Never the same way twice running. Asking a hand already travelling
      // left to go left again is asking it to keep going, and that is what
      // the player found unplayable. Joining the two into one movement was
      // tried instead and was worse: the same eight-note passage came out as
      // one movement in one place and two in another, and one long movement
      // is a tap and then a wait — *"tek parça olursa basıyor ve
      // bekliyoruz."* The hand stays in it.
      if (steps.isNotEmpty && direction == steps.last.direction) {
        direction = other;
      }

      steps.add(FigureStep(taps: notes, direction: direction, from: before));
      at += take;
    }

    for (var i = 0; i < steps.length; i++) {
      steps[i].from.figureTurn = steps[i].direction;
      for (final tap in steps[i].taps) {
        tap.figureId = id;
        tap.figureStep = i;
      }
    }
    return steps;
  }

  /// The most two touches of a figure may be apart, in seconds.
  ///
  /// A fifth of a second and a bit over a quarter. Not a claim about what a
  /// hand cannot do — see [runGapSeconds] for that line, which is lower — but
  /// about where doing it stops being play and starts being work.
  ///
  /// It was 0.21, from the two passages the player first named: the Rondo's
  /// opening and the Entertainer, both a fifth of a second a note. The canon's
  /// right hand is 0.273 and was left outside by two hundredths of a second,
  /// which the player found and asked about. It is in now.
  static const double figureGapSeconds = 0.28;

  /// How many touches in a row it takes to be worth a gesture rather than
  /// taps.
  ///
  /// *"Bir el çok defa arka arkaya tıklama yapıyorsa"* — the player's own
  /// words, and they are a count. Four was the first line and it was too low:
  /// the Rondo is full of four-note groups with a breath between them, and
  /// turning each into a touch and a gesture is not relief, it is a second
  /// thing to get right.
  ///
  /// This is the whole entry rule, and it is the same rule everywhere:
  /// *"Bir kural koyuyorsak tüm oyunda aynı kural olmalı."* It was briefly
  /// two rules — a short line for fast music and a long one for merely brisk
  /// music — which came to the same answers but read as two numbers picked to
  /// suit two songs. Seven in a row is one number, and because
  /// [figureGapSeconds] caps how far apart they may be, seven of them are
  /// between nine tenths of a second and two seconds however the piece is
  /// written.
  ///
  /// Seconds still decide how *often* the hand is asked to move once it is
  /// inside a figure — see [figureStepSeconds]. That is a different question:
  /// there the answer is a rhythm, here it is a count.
  static const int figureLeastTouches = 7;

  /// How much music one movement of the hand is worth, in seconds.
  ///
  /// A second. Für Elise asks for a movement every one and a quarter seconds
  /// at this length, which is a rhythm a hand can keep; at three notes a
  /// movement it asked for three inside one second, which it cannot.
  static const double figureStepSeconds = 1.0;

  /// How far a step has to move in pitch before it counts as going somewhere,
  /// in semitones. Under this the music is turning on itself.
  static const int figureTurnSemitones = 2;

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

  /// How far from the note it is playing a finger may be and still be
  /// following a run, as a fraction of the screen's width.
  ///
  /// About a finger's width either side on a phone. Generous on purpose: the
  /// skill being asked for is staying with a passage, not hitting a target.
  /// It is also what stops a parked finger from collecting a whole run — the
  /// beads of a real run travel most of the hand's zone, so a hand that does
  /// not travel with them falls off.
  ///
  /// It lives here rather than with the session that enforces it because the
  /// chart has to build runs a finger can actually follow: see [_widen].
  static const double dragReach = 0.15;

  /// How far out a run reaches for the note on either side of it, as a
  /// multiple of its own closest spacing. See [_widen].
  ///
  /// Twice. The canon's runs are a seventh of a second between notes and the
  /// ordinary notes either side are two sevenths away — the next thing the
  /// hand does, not the next phrase.
  static const double runShoulderSpacings = 2.0;

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
    List<Tap> taps,
    Song song,
    bool separatesHands,
  ) {
    final secondsPerBeat = 60 / song.bpm;
    final onsetTolerance = onsetToleranceAt(song.bpm);
    final byHand = <Hand, List<Tap>>{};
    for (final tap in taps) {
      (byHand[separatesHands ? tap.hand : Hand.right] ??= []).add(tap);
    }

    final runs = <int, List<Tap>>{};
    var nextId = 1;
    for (final line in byHand.values) {
      // Found first, extended second, and only then handed out ids: a run's
      // shoulders (see [_widen]) depend on what is next to it, and that is
      // not known while the runs are still being found.
      final found = <(int, int)>[]; // half-open [start, end)
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

        if (running && i - start >= runLength) found.add((start, i));
        start = i;
        running = false;
      }

      for (final (from, to) in _widen(found, line, secondsPerBeat)) {
        final run = line.sublist(from, to);
        final id = nextId++;
        for (var j = 0; j < run.length; j++) {
          run[j].runId = id;
          run[j].runIndex = j;
        }
        // Half way back to whatever this hand was last asked for, so the
        // bead is never on the line at the same moment as an ordinary note.
        run.first.runOpensAt = from == 0
            ? double.negativeInfinity
            : (line[from - 1].beat + run.first.beat) / 2;
        runs[id] = List.unmodifiable(run);
      }
    }
    return runs;
  }

  /// Take in the note on each side of a run, where the music leaves it close
  /// enough to be part of the same gesture.
  ///
  /// The canon's semiquaver variations are built as *one ordinary note,
  /// three too fast to tap, one ordinary note*, over and over about a second
  /// apart. Read strictly, that asks the hand to tap, then put a finger down
  /// and slide, then tap again, every quarter of a second — and the player
  /// said plainly it cannot be done at speed. The shoulders are what make it
  /// one movement instead of three.
  ///
  /// **This is a step back towards something that was once rejected**, and
  /// deliberately a small one. Widening [runGapSeconds] itself was tried and
  /// sent back: the canon breathes every fourth note, and carrying the thread
  /// across every breath turned ten bars into two runs of seventy-nine and a
  /// hundred and twelve notes. So this takes *one* note on each side and only
  /// where it is within [runShoulderSpacings] of the run's own spacing —
  /// close enough to be the same gesture, and never a chain.
  static List<(int, int)> _widen(
    List<(int, int)> found,
    List<Tap> line,
    double secondsPerBeat,
  ) {
    final out = <(int, int)>[];
    // Where the previous run ended, so two runs never claim the same note.
    var taken = 0;
    for (var r = 0; r < found.length; r++) {
      var (from, to) = found[r];
      // The run's own pace: the closest its notes come, which is what makes
      // it a run in the first place.
      var pace = double.infinity;
      for (var i = from + 1; i < to; i++) {
        final gap = (line[i].beat - line[i - 1].beat) * secondsPerBeat;
        if (gap < pace) pace = gap;
      }
      final reach = pace * runShoulderSpacings;

      // Near enough in time to be the same gesture, and near enough across
      // the screen that the hand can hold both. A shoulder further off than
      // [dragReach] is one the finger cannot be on and reach the run from:
      // the player pressed it, heard it, held still, and the rest of the run
      // said nothing.
      bool holdable(int shoulder, int body) =>
          (line[shoulder].across - line[body].across).abs() <= dragReach;

      if (from - 1 >= taken &&
          (line[from].beat - line[from - 1].beat) * secondsPerBeat <= reach &&
          holdable(from - 1, from)) {
        from -= 1;
      }
      final nextFrom = r + 1 < found.length ? found[r + 1].$1 : line.length;
      if (to < nextFrom &&
          (line[to].beat - line[to - 1].beat) * secondsPerBeat <= reach &&
          holdable(to, to - 1)) {
        to += 1;
      }
      taken = to;
      out.add((from, to));
    }
    return out;
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
            line[i].drawnEndOrnamented = line[j].hasGrace;
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
    Song song,
    Difficulty difficulty,
  ) {
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
        _leansInto(
          moments[i],
          i + 1 < moments.length ? moments[i + 1] : null,
          song.bpm,
        ),
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
      if (out.isNotEmpty && note.beat - out.last.first.beat <= onsetTolerance) {
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
