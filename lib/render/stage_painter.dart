import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../game/chart.dart';
import '../game/play_session.dart' show RunBead;
import '../music/note.dart';
import '../game/stage_geometry.dart';
import '../theme/app_theme.dart';
import 'hit_sparks.dart';
import 'stage_shader.dart';

/// One note as it is drawn: where it sits across the screen, when it ends,
/// and whether the finger is meant to be — and actually is — on it.
class _Dot {
  const _Dot({
    required this.across,
    required this.midi,
    required this.endBeat,
    required this.isHold,
    required this.isHeld,
    required this.isPlayed,
    this.clearsOrnament = false,
    this.syncopated = false,
  });

  final double across;
  final int midi;
  final double endBeat;

  /// Long enough that the player is asked to keep a finger down.
  final bool isHold;

  /// And it is sounding right now — either under a finger, or ringing on
  /// after one had to leave to play the next note.
  final bool isHeld;

  /// The player has already dealt with it, so it ends at the line.
  final bool isPlayed;

  /// Its tail stops at a touch that carries an ornament, whose little note is
  /// drawn below that touch — so the tail has further to stop short of.
  final bool clearsOrnament;

  /// It pushes against the beat — see [Tap.syncopated].
  final bool syncopated;

  _Dot movedTo(double newAcross) => _Dot(
    across: newAcross,
    midi: midi,
    endBeat: endBeat,
    isHold: isHold,
    isHeld: isHeld,
    isPlayed: isPlayed,
    clearsOrnament: clearsOrnament,
    syncopated: syncopated,
  );
}

/// Draws the playfield: the beams, the hit line, and the notes travelling down
/// toward it.
///
/// Everything is derived from one number — the current beat — so the same
/// painter serves playback, practice and replay without knowing which it is.
class StagePainter extends CustomPainter {
  StagePainter({
    required this.chart,
    required this.beat,
    required this.windowInBeats,
    this.approachSeconds = 1.9,
    this.litHands = const {},
    this.holding = false,
    this.heldNotes = const {},
    this.runBeads = const [],
    this.playedNotes = const {},
    this.sparks = const [],
    this.heat = 0,
    this.seconds = 0,
    this.ground = AppTheme.defaultGround,
  });

  final Chart chart;

  /// The moment being drawn, in beats from the start of the song.
  final double beat;

  /// How far ahead the player can see.
  final double windowInBeats;

  /// And how long that is in seconds — the same span as [windowInBeats], in
  /// the other unit, so the painter can ask how long a tail lasts and not
  /// only how long it is drawn.
  ///
  /// Both, because the two are what the picture is made of: where a note is
  /// comes from beats, and what is being asked of the hand comes from
  /// seconds. Deriving one from the other needs the tempo, which is the
  /// session's business and not the painter's.
  final double approachSeconds;

  /// How long [beats] of this song last, at the speed it is being played.
  double _secondsOf(double beats) => beats / windowInBeats * approachSeconds;

  /// Hands flashing from a recent hit, mapped to how fresh it is (1 to 0).
  final Map<Hand, double> litHands;

  /// Whether a long note is being held right now.
  final bool holding;

  /// The long notes actually sounding, as (beat, pitch).
  ///
  /// Only these stop at the line. A long note nobody caught is not sounding,
  /// and pinning it there would draw a promise the player never made — it
  /// carries on down and leaves, tail and all, like any other missed note.
  final Set<(double, int)> heldNotes;

  /// Where each run on screen has got to, and whether a finger is on it.
  final List<RunBead> runBeads;

  /// The notes the player has already dealt with. A note that was hit ends
  /// at the line; only what nobody caught goes on falling past it.
  final Set<(double, int)> playedNotes;

  /// Hits still burning on the line.
  final List<Spark> sparks;

  /// How far into a streak the player is, 0 to 1.
  ///
  /// The stage warms with it. Fifty notes in a row used to look exactly like
  /// three, which is a strange thing for a game to say nothing about.
  final double heat;

  /// Seconds since the performance began, for anything that moves on its own.
  final double seconds;

  /// The colours this piece is played on. See [Ground].
  final Ground ground;

  @override
  void paint(Canvas canvas, Size size) {
    final geometry = StageGeometry(size: size);

    _paintBackground(canvas, size, geometry);
    if (chart.separatesHands) _paintHandDivide(canvas, size, geometry);
    _paintBarLines(canvas, size, geometry);
    _paintHitLine(canvas, size, geometry);
    _paintNotes(canvas, geometry);
    _paintSparks(canvas, geometry);
  }

  /// The light a hit leaves: a white core on the line, and a plume falling
  /// away below it.
  ///
  /// Three goes at this, and the failures are worth keeping because each was
  /// wrong for a different reason.
  ///
  /// 1. **Rings expanding outwards.** A dozen a second cross each other and
  ///    the notes above them; the player called it ripples on water.
  /// 2. **A small flare where the note was.** Note-sized and note-coloured,
  ///    so it read as a note gone slightly dim — as good as nothing.
  /// 3. **A bloom lying along the line.** Invisible: the hit line is the
  ///    brightest thing on the screen, and lighting it up a bit more says
  ///    nothing at all.
  ///
  /// What works is putting the burst where there is room for it. Below the
  /// line the screen is empty — no notes ever go there — so a plume falling
  /// through reads instantly, cannot collide with anything coming down, and
  /// several at once simply stand side by side at their own pitches. The
  /// core stays on the line and stays **white**, because white is the one
  /// colour no note is.
  ///
  /// Discs and ovals, no blur: a blur filter here costs more per frame than
  /// the rest of the screen put together.
  void _paintSparks(Canvas canvas, StageGeometry g) {
    if (sparks.isEmpty) return;
    final y = g.hitLineY;
    final radius = g.noteRadius;

    for (final spark in sparks) {
      if (spark.places.isEmpty) continue;
      final strength = 0.7 + spark.quality * 0.3;
      final (low, high) = chart.pitchRange;
      // Laid out exactly as the notes were, or a chord's light stands beside
      // the notes it came from.
      final places = _spreadPlaces(spark.places, g, radius, spark.hand);

      // Each plume in its own note's colour: the light is what happened to
      // *that* note, so it is that note that should be recognisable in it.
      //
      // [life] is how far through its own life this plume is, which is not
      // the same for all of them: an ornament sounds before the notes it
      // leans into, so its light is further along from the start.
      void plume(double x, int midi, double scale, double life) {
        if (life >= 1) return;
        final open = 1 - (1 - life) * (1 - life); // quick out, slow settle
        // Bright for most of its life and then away quickly, rather than
        // dimming from the first frame. A hit has to be *seen*, and three
        // hundred milliseconds of steadily fading light is three hundred
        // milliseconds of nearly nothing.
        final burn = 1 - life * life * life;

        // The plume: a shaft driven down through the line, bright where it
        // leaves the note and fading out along its length.
        //
        // A linear gradient down the shaft, not a radial one over an oval: a
        // radial gradient spreads the same light over an area and what
        // reaches the eye is a faint smudge. This keeps all of it at the
        // line, where the hit was.
        final reach = radius * (1.2 + open * 3.6);
        final half = radius * (1.0 - open * 0.45);
        // The core: white, bigger than a note, and gone in a breath. This is
        // the part the eye reads as the hit itself.
        final flash = (1 - life * 1.8).clamp(0.0, 1.0);

        final colour = AppTheme.pitchColor(midi, low: low, high: high);
        final width = half * scale;
        final length = reach * scale;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(x - width, y, x + width, y + length),
            Radius.circular(width),
          ),
          Paint()
            ..shader = ui.Gradient.linear(
              Offset(x, y),
              Offset(x, y + length),
              [
                Color.lerp(
                  colour,
                  Colors.white,
                  0.7,
                )!.withValues(alpha: burn * strength),
                Color.lerp(
                  colour,
                  Colors.white,
                  0.2,
                )!.withValues(alpha: 0.7 * burn * strength),
                colour.withValues(alpha: 0.0),
              ],
              const [0.0, 0.35, 1.0],
            ),
        );

        if (flash > 0) {
          canvas.drawCircle(
            Offset(x, y),
            radius * (0.8 + (1 - flash) * 1.1) * scale,
            Paint()..color = Colors.white.withValues(alpha: flash),
          );
        }
      }

      final life = spark.age.clamp(0.0, 1.0);
      for (var i = 0; i < places.length; i++) {
        plume(g.xAtPosition(places[i]), spark.midis[i], 1, life);
      }

      // And the ornament, where the touch carried one. From under its own
      // mark, by the same rule that put the mark there, and at the size that
      // mark was. It used to come up from the middle of the touch, which
      // since the mark moved to one side meant it rose from under a
      // different note: "efekt diğer notanın altından çıkıyor".
      //
      // And *before* the rest of it. One touch sounds both, the little note
      // first, so lighting them together said the hand had done one thing
      // where the ear plainly heard two — "gerçekte o notaya daha önce
      // basıyoruz". Its light is that much further through its life from the
      // start, which makes it open and go out ahead of the others without
      // holding anything back from the player's own touch.
      final graceMidi = spark.graceMidi;
      if (graceMidi != null) {
        final (place, _) = _gracePlace(
          places,
          spark.midis,
          graceMidi,
          spark.graceAcross,
          spark.hand,
          g,
        );
        plume(
          g.xAtPosition(place),
          graceMidi,
          _graceScale,
          (life + spark.graceLead).clamp(0.0, 1.0),
        );
      }
    }
  }

  void _paintBackground(Canvas canvas, Size size, StageGeometry g) {
    final stage = Offset.zero & size;
    final shader = StageShader.forStage(
      size: size,
      seconds: seconds,
      heat: heat,
      top: ground.top,
      bottom: ground.bottom,
      glow: ground.glow,
      hitLineFraction: g.hitLineFraction,
    );

    if (shader != null) {
      canvas.drawRect(stage, Paint()..shader = shader);
      return;
    }

    // No shader: the ground the game had before there was one. Two gradients
    // and no movement, but a game rather than a black screen.
    canvas.drawRect(
      stage,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [ground.top, ground.bottom],
        ).createShader(stage),
    );

    final glowCentre = Offset(size.width / 2, g.hitLineY);
    final glowRadius = size.width * (0.75 + heat * 0.35);
    canvas.drawCircle(
      glowCentre,
      glowRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            ground.glow.withValues(alpha: 0.20 + heat * 0.22),
            ground.glow.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: glowCentre, radius: glowRadius)),
    );
  }

  /// The line down the middle, where one hand's territory ends and the
  /// other's begins.
  ///
  /// Faint on purpose: it is a reminder of which side to answer on, not
  /// something to look at. The notes themselves carry the information.
  void _paintHandDivide(Canvas canvas, Size size, StageGeometry g) {
    final x = size.width / 2;
    canvas.drawRect(
      Rect.fromLTWH(x - 1, 0, 2, size.height),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(x, 0),
          Offset(x, size.height),
          [
            Colors.white.withValues(alpha: 0.0),
            Colors.white.withValues(alpha: 0.10),
            Colors.white.withValues(alpha: 0.0),
          ],
          const [0.0, 0.55, 1.0],
        ),
    );
  }

  void _paintHitLine(Canvas canvas, Size size, StageGeometry g) {
    final y = g.hitLineY;
    final flash = litHands.values.fold(0.0, (max, v) => v > max ? v : max);

    // A soft band rather than a blurred line: a blur filter here costs more
    // per frame than everything else on screen put together, and on a phone
    // browser that is the difference between flowing and stuttering.
    final glow = Rect.fromLTWH(0, y - 24, size.width, 48);
    canvas.drawRect(
      glow,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, glow.top),
          Offset(0, glow.bottom),
          [
            AppTheme.accentSoft.withValues(alpha: 0.0),
            AppTheme.accentSoft.withValues(
              alpha: 0.22 + flash * 0.22 + heat * 0.30,
            ),
            AppTheme.accentSoft.withValues(alpha: 0.0),
          ],
          const [0.0, 0.5, 1.0],
        ),
    );

    canvas.drawLine(
      Offset(0, y),
      Offset(size.width, y),
      Paint()
        ..strokeWidth = 2 + heat * 1.5
        ..color = Colors.white.withValues(alpha: 0.75 + flash * 0.25),
    );
  }

  /// The bar lines, falling with the music.
  ///
  /// The screen shows less than a bar in most pieces — a third of one in the
  /// nocturne, half in the canon, one and a half in Für Elise — so there was
  /// nothing on it to say where the music's own counting was. A line every
  /// bar gives the falling notes a frame: it arrives on the beat the bar
  /// does, and the player can feel a bar coming rather than only a note.
  ///
  /// Faint on purpose. It is a ruling under the music, not a thing to read;
  /// anything stronger competes with the notes for the same glance.
  void _paintBarLines(Canvas canvas, Size size, StageGeometry g) {
    final perBar = chart.song.beatsPerBar.toDouble();
    if (perBar <= 0) return;

    // A note's own radius, in beats: the line is drawn that far above the
    // beat it belongs to, so it passes over the heads of the notes on that
    // beat rather than through the middle of them. Level with them it cut
    // them in half, which was tolerable only while the line was too faint to
    // see.
    final lift = g.noteRadius / g.hitLineY * windowInBeats;

    // Everything the screen can show, above the line and below it — and one
    // note further down, since the lift can bring a line back into view.
    final firstVisible =
        beat -
        windowInBeats * (1 - g.hitLineFraction) / g.hitLineFraction -
        lift;
    final lastVisible = beat + windowInBeats;

    final paint = Paint()..strokeWidth = 1;
    for (
      var bar = (firstVisible / perBar).ceil() * perBar;
      bar <= lastVisible;
      bar += perBar
    ) {
      // Plus the lift, not minus: further from the line is higher up.
      final progress = StageGeometry.progressFor(
        bar - beat + lift,
        windowInBeats,
      );
      final y = g.yAt(progress);
      // Dimmer the further off it is, like the notes, so the top of the
      // screen stays quiet.
      final near = progress.clamp(0.0, 1.0);
      paint.color = Colors.white.withValues(
        alpha: (0.10 + near * 0.12) * (progress > 1 ? 0.4 : 1),
      );
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  void _paintNotes(Canvas canvas, StageGeometry g) {
    // Far notes first, so nearer ones overlap them.
    final visible = chart.visibleAt(beat, windowInBeats).toList()
      ..sort((a, b) => b.beat.compareTo(a.beat));

    // Notes struck together *by the same hand*, grouped so the band behind
    // them can be drawn first. Grouping by moment alone would run the band
    // across the divide and paint one hand in the other's colour.
    final moments = <(double, Hand), List<Tap>>{};
    for (final tap in visible) {
      final key = ((tap.beat * 1000).roundToDouble(), tap.hand);
      (moments[key] ??= []).add(tap);
    }

    for (final entry in moments.entries) {
      final group = entry.value;
      final tap = group.first;
      final progress = StageGeometry.progressFor(
        tap.beat - beat,
        windowInBeats,
      );
      if (progress < -0.05) continue;

      // A held note is not finished when its head crosses the line — the
      // finger is meant to stay down until its end does.
      final tailProgress = StageGeometry.progressFor(
        tap.drawnEndBeat - beat,
        windowInBeats,
      );

      // Every note that sounds at this moment in this hand, wherever its
      // pitch puts it. A chord is drawn as its notes even when one finger
      // takes them all: the picture is of the music, not of the input.
      var dots = <_Dot>[];
      for (final member in group) {
        for (var i = 0; i < member.notes.length; i++) {
          final note = member.notes[i];
          // The tail stops at the next thing this hand is asked for, not
          // at the note's written end — see [Tap.drawnEndBeat]. The sound
          // still runs its full length.
          final endBeat = member.drawnEndBeat < member.beat + note.duration
              ? member.drawnEndBeat
              : member.beat + note.duration;
          dots.add(
            _Dot(
              across: member.noteAcross[i],
              midi: note.midi,
              endBeat: endBeat,
              // Held in the picture only where there is a stay long enough
              // to be worth asking for. Whether the finger is meant to stay
              // is [Tap.isHold] and belongs to the sound; whether the bar is
              // worth drawing depends on how long the tail actually lasts,
              // which is the tempo and the speed the player chose. See
              // [StageGeometry.holdReadsAsBar].
              isHold:
                  member.isHold &&
                  StageGeometry.holdReadsAsBar(
                    _secondsOf(endBeat - member.beat),
                  ),
              isHeld: heldNotes.contains((member.beat, note.midi)),
              isPlayed: playedNotes.contains((member.beat, note.midi)),
              clearsOrnament:
                  member.drawnEndOrnamented && endBeat == member.drawnEndBeat,
              syncopated: member.syncopated,
            ),
          );
        }
      }

      // A note that is sounding stops at the line and waits there; one
      // nobody caught carries on down and leaves, tail and all. Catching it
      // is what earns the pause — not keeping a finger on it, which the
      // music often makes impossible.
      final held = dots.any((dot) => dot.isHold && dot.isHeld);
      final departed = held ? tailProgress : progress;

      // Distant notes are dimmer; ones past the line drop away quickly, so
      // the eye is never asked whether a note below the line still counts.
      final fade = departed > 1
          ? (1 - (departed - 1) / 0.16).clamp(0.0, 1.0)
          : (0.35 + progress.clamp(0.0, 1.0) * 0.65).clamp(0.0, 1.0);
      if (fade <= 0.01) continue;

      final radius = g.noteRadius;
      dots = _spreadChord(dots, g, radius, tap.hand);

      double headOf(_Dot dot) => StageGeometry.headProgressFor(
        progress,
        isHold: dot.isHold && dot.isHeld,
      );

      if (dots.length > 1) {
        _paintChordBand(canvas, g, dots, headOf(dots.first), fade);
      }

      // One mark for the whole touch, before the notes so they sit on top of
      // it. A chord is several notes and one hand: the instruction is to the
      // hand.
      //
      // Only until the touch is answered, and *answered* is the whole of it:
      // the moment the finger lands, whether or not the beat has come. The
      // mark is an instruction — there is a little note in this one — and a
      // touch that has been dealt with has no instruction left. It used to
      // wait for the beat as well, and a hand a few milliseconds early left
      // the mark sliding on down past the line looking unplayed while the
      // notes sounded correctly, which is exactly how the player found it.
      //
      // A pressed note goes on falling to the line because it is still
      // travelling and the screen says where things are. The mark is not
      // that: it says what to do.
      final ornament = group.where((m) => m.hasGrace).firstOrNull;
      final answered = dots.every((dot) => dot.isPlayed);
      if (ornament != null && !answered) {
        _paintGrace(
          canvas,
          g,
          dots,
          tap.hand,
          headOf(dots.first),
          radius,
          ornament.graceMidi!,
          ornament.graceAcross,
          fade,
        );
      }

      // Half the bar's thickness, as [_paintHoldBar] wants it: the tail comes
      // out about seven tenths of the note's width, narrower than the note so
      // the head still reads as the thing to aim at.
      final barWidth = g.noteWidth * 0.35;
      for (final dot in dots) {
        final head = headOf(dot);
        // A note that was played is spent at the line — the burst of light
        // there is what happened to it. Only what nobody caught goes on
        // falling, which is how the screen says which is which.
        if (dot.isPlayed && head > 1) continue;
        // Each note in its own colour: which note it is, and how high.
        final (low, high) = chart.pitchRange;
        final ink = AppTheme.pitchColor(dot.midi, low: low, high: high);
        if (dot.isHold) {
          _paintHoldBar(
            canvas,
            g,
            dot.across,
            head,
            StageGeometry.progressFor(dot.endBeat - beat, windowInBeats),
            radius,
            barWidth,
            ink,
            fade,
            _clearanceFor(g, dot.clearsOrnament),
          );
        }
        _paintNote(
          canvas,
          g,
          dot.across,
          head,
          radius,
          ink,
          fade,
          dot.syncopated,
        );
      }
    }

    _paintRunPaths(canvas, g, visible);
    _paintRunBeads(canvas, g);
  }

  /// The bead a run is on: the note due now, sitting on the hit line.
  ///
  /// This is the whole of what makes a run playable rather than something
  /// that happens near your hand. The thread says where the passage goes;
  /// the bead says where it is *now*, and following it with a finger is the
  /// game. Drawn last, over everything, because it is the thing to look at.
  void _paintRunBeads(Canvas canvas, StageGeometry g) {
    for (final bead in runBeads) {
      final centre = Offset(g.xAtPosition(bead.across), g.hitLineY);
      // A note's shape, a little larger — it stands where a note would and
      // asks for the same finger, so it should not be the one round thing
      // left on a screen of upright bars.
      final body = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: centre,
          width: g.noteWidth * _beadScale,
          height: g.noteRadius * 2 * _beadScale,
        ),
        Radius.circular(g.noteWidth * _beadScale / 2),
      );

      // A patch of the floor behind it, so the outline reads as an outline
      // and not as one more note. A run's beads touch each other; a line
      // drawn straight over them disappears into the crowd, which is no use
      // for the one thing on screen that is asking to be touched.
      canvas.drawRRect(
        body,
        Paint()..color = const Color(0xFF08080F).withValues(alpha: 0.75),
      );

      if (bead.tracked) {
        // A finger is on it: light it up, so the hand can feel it is on the
        // rails without looking away from the notes coming down.
        final glow = g.noteRadius * 2.5;
        canvas.drawCircle(
          centre,
          glow,
          Paint()
            ..shader = RadialGradient(
              colors: [
                AppTheme.accentSoft.withValues(alpha: 0.45),
                AppTheme.accentSoft.withValues(alpha: 0.0),
              ],
            ).createShader(Rect.fromCircle(center: centre, radius: glow)),
        );
        canvas.drawRRect(
          body,
          Paint()..color = Colors.white.withValues(alpha: 0.85),
        );
      }

      // Hollow when nobody is on it — an outline on the line saying "here,
      // put a finger here" rather than a note pretending to have been played.
      canvas.drawRRect(
        body,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = bead.tracked ? 3.0 : 2.4
          ..color = bead.tracked
              ? Colors.white
              : AppTheme.accentSoft.withValues(alpha: 0.95),
      );
    }
  }

  /// How much bigger than a note the bead is drawn.
  static const double _beadScale = 1.15;

  /// The thread through a run: a line joining notes that arrive faster than a
  /// finger can answer one at a time.
  ///
  /// It is the whole of how the slide is taught. Nothing else on screen says
  /// these notes are not to be tapped one by one, and a mechanic nobody
  /// discovers is a mechanic that does not exist — so the path the finger is
  /// meant to take is simply drawn, and the player follows a line.
  ///
  /// Over the notes, not under them. Under was tried first and vanished: a
  /// run this fast packs its notes edge to edge, so a line behind them is
  /// covered along its whole length. Threaded through the beads instead, it
  /// reads as one continuous thing to be followed.
  void _paintRunPaths(Canvas canvas, StageGeometry g, List<Tap> visible) {
    if (chart.runs.isEmpty) return;
    final thickness = (g.noteRadius * 0.22).clamp(1.5, 4.0);

    for (final tap in visible) {
      final runId = tap.runId;
      if (runId == null) continue;
      final run = chart.runs[runId]!;
      if (tap.runIndex + 1 >= run.length) continue;

      final next = run[tap.runIndex + 1];
      final here = StageGeometry.progressFor(tap.beat - beat, windowInBeats);
      final there = StageGeometry.progressFor(next.beat - beat, windowInBeats);
      // The near end has passed the line and gone; the far end is what is
      // left to play, so it decides whether there is anything to show.
      final fade = here > 1
          ? (1 - (here - 1) / 0.16).clamp(0.0, 1.0)
          : (0.35 + here.clamp(0.0, 1.0) * 0.65);
      if (fade <= 0.01) continue;

      canvas.drawLine(
        g.positionAtPosition(tap.across, here),
        g.positionAtPosition(next.across, there),
        Paint()
          ..strokeWidth = thickness
          ..strokeCap = StrokeCap.round
          ..color = Colors.white.withValues(alpha: 0.80 * fade),
      );
    }
  }

  /// Lays a chord's notes out so they do not overlap. See
  /// [StageGeometry.spreadChord] for what is and is not moved.
  ///
  /// This is worked out every frame even though it depends on nothing that
  /// changes between them — only on pitch, note size and which hand. Hoisting
  /// it into the chart was measured and left alone: the whole painter costs
  /// 314 µs a frame against a budget of 16700, and moving this would mean
  /// giving [Chart] a screen size it is deliberately free of.
  List<_Dot> _spreadChord(
    List<_Dot> dots,
    StageGeometry g,
    double radius,
    Hand hand,
  ) {
    if (dots.length < 2 || g.size.width <= 0) return dots;

    final sorted = [...dots]..sort((a, b) => a.across.compareTo(b.across));
    final places = _spreadPlaces(
      [for (final dot in sorted) dot.across],
      g,
      radius,
      hand,
    );

    return [
      for (var i = 0; i < sorted.length; i++) sorted[i].movedTo(places[i]),
    ];
  }

  /// The same layout, over bare positions.
  ///
  /// Notes and the sparks they leave have to come out in the same places, and
  /// the only way to be sure of that is for both to go through here.
  /// The stretch of screen a hand is drawn within.
  (double, double) _zoneOf(Hand hand) => chart.separatesHands
      ? (hand == Hand.left
            ? (Chart.leftZoneStart, Chart.leftZoneEnd)
            : (Chart.rightZoneStart, Chart.rightZoneEnd))
      : (Chart.leftZoneStart, Chart.rightZoneEnd);

  /// Where an ornament's mark goes, and which note it hangs off.
  ///
  /// **Outside the chord, never in among it.** A touch can be two or three
  /// notes, and an ornament belongs to the whole of it: measured across the
  /// library, of the twenty-four ornamented chords the little note is above
  /// all of them twenty-two times and below all of them twice, and inside one
  /// not once. So the chord's own pitch says which side, and the mark hangs
  /// off the outermost note on that side — which for a single note is that
  /// note, and for a chord keeps the mark and its tie clear of the others
  /// instead of threading between them.
  ///
  /// One rule, in one place, because two things are drawn from it: the mark
  /// on its way down, and the light it throws at the line. They were worked
  /// out separately and the light came up under the wrong note, which is
  /// exactly how the player reported it.
  ///
  /// [places] are where the touch's notes are actually drawn — after the
  /// chord has been opened out, not where their pitches put them.
  (double, double) _gracePlace(
    List<double> places,
    List<int> midis,
    int graceMidi,
    double graceAcross,
    Hand hand,
    StageGeometry g,
  ) {
    var mean = 0.0;
    var lower = places.first, upper = places.first;
    for (var i = 0; i < places.length; i++) {
      mean += midis[i] / midis.length;
      if (places[i] < lower) lower = places[i];
      if (places[i] > upper) upper = places[i];
    }

    final side = graceMidi < mean ? -1.0 : 1.0;
    final into = side < 0 ? lower : upper;
    final apart = (graceAcross - into).abs() * g.size.width;
    final least = g.noteWidth;
    final away = (apart > least ? apart : least) / g.size.width;

    // Inside the hand's own stretch of screen, like everything else drawn.
    final (zoneStart, zoneEnd) = _zoneOf(hand);
    final edge = g.noteWidth * _graceScale / 2 / g.size.width;
    return ((into + side * away).clamp(zoneStart + edge, zoneEnd - edge), into);
  }

  List<double> _spreadPlaces(
    List<double> places,
    StageGeometry g,
    double radius,
    Hand hand,
  ) {
    if (places.length < 2 || g.size.width <= 0) return places;

    final (zoneStart, zoneEnd) = _zoneOf(hand);

    return StageGeometry.spreadChord(
      [...places]..sort(),
      // Edge to edge plus a little daylight, in the 0..1 the chart works in.
      minGap: g.noteGap / g.size.width,
      zoneStart: zoneStart,
      zoneEnd: zoneEnd,
    );
  }

  /// The band tying a chord's notes together.
  ///
  /// Without it, notes side by side read as separate notes and the player
  /// answers them one at a time. The band says: these belong together, and
  /// whether they take one finger or three, they sound at once.
  ///
  /// It runs from the outermost note of the chord to the other, so it is
  /// drawn in *their* colours: one end the colour of the note it touches,
  /// the other end the colour of the note at the far end. Nothing has to be
  /// learned to read it. It used to be one flat colour standing for how many
  /// notes the chord had, which was the last thing on screen still coloured
  /// by something other than pitch — and with the notes themselves now told
  /// apart by colour, the count is there to be seen in them.
  void _paintChordBand(
    Canvas canvas,
    StageGeometry g,
    List<_Dot> dots,
    double progress,
    double fade,
  ) {
    var lowest = dots.first;
    var highest = dots.first;
    for (final dot in dots) {
      if (dot.across < lowest.across) lowest = dot;
      if (dot.across > highest.across) highest = dot;
    }

    final left = g.positionAtPosition(lowest.across, progress);
    final right = g.positionAtPosition(highest.across, progress);
    final thickness = g.noteWidth * 0.7;

    final (low, high) = chart.pitchRange;
    final from = AppTheme.pitchColor(lowest.midi, low: low, high: high);
    final to = AppTheme.pitchColor(highest.midi, low: low, high: high);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(
          left.dx,
          left.dy - thickness / 2,
          right.dx,
          right.dy + thickness / 2,
        ),
        Radius.circular(thickness / 2),
      ),
      Paint()
        ..shader = ui.Gradient.linear(
          left,
          right,
          [
            from.withValues(alpha: 0.30 * fade),
            // Brighter in the middle, as it always was: the band is behind
            // the notes, and its ends are under them.
            Color.lerp(from, to, 0.5)!.withValues(alpha: 0.46 * fade),
            to.withValues(alpha: 0.30 * fade),
          ],
          const [0.0, 0.5, 1.0],
        ),
    );
  }

  /// The mark on a touch that carries an ornament: the little note itself,
  /// set down and to one side of the note it leans into, and tied to it.
  ///
  /// **One per touch, not one per note.** An earlier drawing put a head
  /// beside each ornamented note, and on the eighteen chords that carry one
  /// in the Gnossienne it landed on top of the neighbouring note — the player
  /// called it exactly that. An ornament belongs to the hand, and a hand gets
  /// one mark however many notes it is holding.
  ///
  /// **Down, because that is when.** The ornament sounds *before* the note it
  /// leans on, and sooner is nearer the line, which is downwards.
  ///
  /// **And to the side the key is on.** Straight down said nothing about
  /// which way the hand moves, and the hand is the point: the player has to
  /// go from the little note to the big one. So the mark sits left of it or
  /// right of it, as the two keys sit on a piano.
  ///
  /// Its own pitch would be truer still and was tried first — the measurement
  /// is why it is not used as it stands. An acciaccatura leans into the note
  /// beside it, so the two are a semitone or a tone apart, which on this
  /// screen is a few pixels: across the library the middle ornament sits 5.6
  /// pixels from its note and 96 of Satie's hundred are within one note
  /// width, some of them exactly on top of it. A truthful offset nobody can
  /// see is a worse drawing than a legible one. So the *side* is the pitch's,
  /// always, and the *distance* is the pitch's too wherever that is far
  /// enough to see — with a floor of one note width, which is what makes it
  /// read as down-and-left or down-and-right rather than as down.
  ///
  /// The mark is not something to aim at, which is what makes that fair: the
  /// finger goes on the big note, and this only says a little one leans into
  /// it from that side.
  ///
  /// Where the touch is a chord the mark hangs off its outer note rather than
  /// its nearest — see the comment in the body.
  void _paintGrace(
    Canvas canvas,
    StageGeometry g,
    List<_Dot> dots,
    Hand hand,
    double progress,
    double radius,
    int midi,
    double graceAcross,
    double fade,
  ) {
    final (place, anchorAcross) = _gracePlace(
      [for (final dot in dots) dot.across],
      [for (final dot in dots) dot.midi],
      midi,
      graceAcross,
      hand,
      g,
    );

    final anchor = g.positionAtPosition(anchorAcross, progress);
    final centre = g.positionAtPosition(place, progress);
    final at = Offset(centre.dx, centre.dy + radius * _graceDrop);

    // Its own pitch, like every other note on the screen.
    final (lowest, highest) = chart.pitchRange;
    final colour = AppTheme.pitchColor(midi, low: lowest, high: highest);

    _paintGraceTie(canvas, at, anchor, colour, fade);

    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: at,
        width: g.noteWidth * _graceScale,
        height: radius * 2 * _graceScale,
      ),
      Radius.circular(g.noteWidth * _graceScale / 2),
    );

    canvas.drawRRect(
      body,
      Paint()..color = colour.withValues(alpha: 0.9 * fade),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = Colors.white.withValues(alpha: 0.75 * fade),
    );
  }

  /// The tie from the little note up into the one it leans on.
  ///
  /// **Not the chord band, and deliberately nothing like it.** The band is a
  /// straight, thick, filled bar joining notes that sound *together*; this
  /// joins two that sound one after the other, and if they looked alike the
  /// screen would be saying the same thing about two opposite instructions.
  /// So: a thin curved stroke, open rather than filled, running diagonally
  /// rather than level — which is also exactly what an acciaccatura is
  /// written with on paper. The slur is the notation for this mechanic and
  /// for nothing else in the piece.
  ///
  /// It leaves the little note straight up and bends into the big one, so the
  /// eye is taken along the way the hand has to go.
  void _paintGraceTie(
    Canvas canvas,
    Offset from,
    Offset to,
    Color colour,
    double fade,
  ) {
    final path = Path()
      ..moveTo(from.dx, from.dy)
      ..quadraticBezierTo(from.dx, to.dy, to.dx, to.dy);

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _graceTieWidth
        ..strokeCap = StrokeCap.round
        ..color = colour.withValues(alpha: 0.75 * fade),
    );
  }

  /// How far under its note the little one sits, in note radii.
  ///
  /// Clear of it rather than touching: the mark is now beside the note as
  /// well as below it, so at a tighter drop it would graze whatever is drawn
  /// next door.
  static const double _graceDrop = 1.8;

  /// How far outside an accented note its ring sits, in note radii.
  static const double _accentGap = 0.26;

  /// How thick the tie is drawn. A line, not a bar — see [_paintGraceTie].
  static const double _graceTieWidth = 1.8;

  /// How much room a tail has to leave where it stops at an ornamented touch,
  /// in note radii.
  ///
  /// The ordinary clearance leaves room for the note that comes next. An
  /// ornamented touch has *two* things drawn for it, and the little one hangs
  /// below the big one — so a tail stopping there at the usual distance ran
  /// straight through it, which is what the player saw. Far enough to clear
  /// the mark's own bottom edge ([_graceDrop] plus its half height), and a
  /// little daylight after that.
  static const double _graceClearance = _graceDrop + _graceScale + 0.35;

  /// And how big it is drawn, as a fraction of a note. Small enough to read
  /// as the little note it is written as, big enough to see at arm's length.
  ///
  /// Its brushes are not the notes' — [_Brushes] caches one size at a time
  /// and throws the cache away when the size changes, so asking it for a
  /// second size would rebuild every brush on screen, every frame.
  static const double _graceScale = 0.55;

  /// A note: an upright rounded bar, as tall as the disc it replaced and
  /// narrower.
  ///
  /// **The height does not say the duration.** It was tried, straight off a
  /// piano roll, and the player sent it back: the timing in this game is read
  /// from *where* a note is, so a note that changes height changes the one
  /// thing the eye is measuring. How long a note lasts is the bar behind it,
  /// as it always was.
  ///
  /// What the narrower shape is for is across, not down: the width of a note
  /// is the width of the smallest interval the screen can show apart. Ninety
  /// three of every hundred gaps inside a chord used to be stretched to clear
  /// a disc; a bar this wide leaves a quarter of them at the distance the
  /// music actually has.
  /// [accented] marks a note that pushes against the beat — see
  /// [Tap.syncopated]. Nothing on screen has ever said where in the bar a
  /// note falls, so one that jumps the beat looked exactly like one that
  /// lands on it. It is drawn with a ring around it: the note is unchanged,
  /// and something extra is set around it.
  void _paintNote(
    Canvas canvas,
    StageGeometry g,
    double across,
    double progress,
    double radius,
    Color colour,
    double fade,
    bool accented,
  ) {
    final centre = g.positionAtPosition(across, progress);
    final width = g.noteWidth;
    final brush = _Brushes.forNote(colour, fade, radius);

    // The brushes are baked around the origin so they can be reused, so the
    // canvas is moved to the note rather than the note to the canvas. They
    // are the disc's own gradients: only the outline changed, and painting
    // the new shape with new paint made a flat, half-transparent tile with
    // the tail showing through it.
    canvas.save();
    canvas.translate(centre.dx, centre.dy);

    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: width, height: radius * 2),
      Radius.circular(width / 2),
    );

    // The halo is a gradient, not a blur: a blur filter here costs more per
    // frame than everything else on screen put together.
    canvas.drawRRect(body.inflate(radius * 0.9), brush.halo);
    canvas.drawRRect(body, brush.body);
    // A bright rim reads as a hard edge at any size.
    canvas.drawRRect(body, brush.rim);

    if (accented) {
      canvas.drawRRect(
        body.inflate(radius * _accentGap),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = Colors.white.withValues(alpha: 0.8 * fade),
      );
    }

    canvas.restore();
  }

  /// How much room a tail leaves at its far end, in pixels.
  ///
  /// The larger of two things that are not the same kind of thing: a hand
  /// needs [StageGeometry.holdBarLiftSeconds] to come off one note and land
  /// on the next, and the picture needs enough daylight that the bar does not
  /// run into whatever is drawn there. An ornamented touch needs more of the
  /// second, because its little note hangs below it.
  double _clearanceFor(StageGeometry g, bool clearsOrnament) {
    final lift =
        StageGeometry.holdBarLiftSeconds / approachSeconds * g.hitLineY;
    final room =
        g.noteRadius *
        (clearsOrnament ? _graceClearance : StageGeometry.holdBarClearance);
    return lift > room ? lift : room;
  }

  /// The body of a note that has to be held down, drawn as a bar as long as
  /// the note lasts — and no wider than the note, so the two read as one
  /// thing rather than a head on a post.
  void _paintHoldBar(
    Canvas canvas,
    StageGeometry g,
    double across,
    double progress,
    double tailProgress,
    double radius,
    double width,
    Color colour,
    double fade,
    double clearance,
  ) {
    if (tailProgress >= progress) return;

    // The bar reaches from the head back the distance the note lasts. Once
    // the head has stopped at the line the bar can only shorten, its far end
    // sliding down to meet it — so however long it looks is how much of the
    // note is still to come.
    final head = g.positionAtPosition(across, progress);
    final tail = g.positionAtPosition(across, tailProgress);

    final top = StageGeometry.holdBarTop(head.dy, tail.dy, clearance);
    if (top == null) return;

    final bar = RRect.fromRectAndRadius(
      Rect.fromLTRB(head.dx - width, top, head.dx + width, head.dy),
      Radius.circular(width),
    );

    canvas.drawRRect(
      bar,
      Paint()..color = colour.withValues(alpha: 0.35 * fade),
    );
    canvas.drawRRect(
      bar,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.white.withValues(alpha: 0.28 * fade),
    );
  }

  @override
  bool shouldRepaint(StagePainter old) =>
      old.beat != beat ||
      old.chart != chart ||
      old.windowInBeats != windowInBeats ||
      old.holding != holding ||
      old.litHands != litHands ||
      old.heat != heat ||
      old.seconds != seconds ||
      old.ground != ground ||
      old.sparks.length != sparks.length ||
      old.runBeads.length != runBeads.length;
}

/// The paints a note is drawn with, kept between frames.
///
/// Building a radial gradient's shader was the most expensive thing this
/// painter did, and it did it twice for every note on screen, sixty times a
/// second. What a note looks like depends only on how many notes sound with
/// it, how faded it is and how big it is — never on where it is. So the
/// gradients are baked around the origin, shared by every note that looks the
/// same, and the canvas is moved instead.
///
/// Fade is continuous, so it is rounded into steps. Thirty-two is far finer
/// than an eye can follow a note dimming as it falls.
class _Brushes {
  const _Brushes(this.halo, this.body, this.rim);

  final Paint halo;
  final Paint body;
  final Paint rim;

  static const int _fadeSteps = 32;

  /// One entry per (colour, fade step). Cleared when the note size changes,
  /// which happens only when the screen does.
  ///
  /// There used to be four colours and so at most a hundred and thirty
  /// entries. Notes are coloured by pitch now, so it is one per note of the
  /// piece per step of fading — built as they are first needed, and a piece
  /// only ever uses the notes it is written from.
  static final Map<int, _Brushes> _cache = {};
  static double _cachedRadius = -1;

  static _Brushes forNote(Color colour, double fade, double radius) {
    if (radius != _cachedRadius) {
      _cache.clear();
      _cachedRadius = radius;
    }
    final step = (fade * _fadeSteps).round().clamp(0, _fadeSteps);
    return _cache[Object.hash(colour.toARGB32(), step)] ??= _build(
      colour,
      step / _fadeSteps,
      radius,
    );
  }

  static _Brushes _build(Color colour, double fade, double radius) {
    return _Brushes(
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                colour.withValues(alpha: 0.42 * fade),
                colour.withValues(alpha: 0.16 * fade),
                colour.withValues(alpha: 0.0),
              ],
              stops: const [0.35, 0.6, 1.0],
            ).createShader(
              Rect.fromCircle(center: Offset.zero, radius: radius * 2.0),
            ),
      Paint()
        ..shader = RadialGradient(
          colors: [
            Color.lerp(Colors.white, colour, 0.15)!.withValues(alpha: fade),
            colour.withValues(alpha: fade),
            colour.withValues(alpha: 0.75 * fade),
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: radius)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = Colors.white.withValues(alpha: 0.55 * fade),
    );
  }
}
