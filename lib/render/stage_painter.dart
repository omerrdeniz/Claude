import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../game/chart.dart';
import '../game/play_session.dart' show RunBead;
import '../music/note.dart';
import '../game/stage_geometry.dart';
import '../theme/app_theme.dart';
import 'hit_sparks.dart';

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

  _Dot movedTo(double newAcross) => _Dot(
        across: newAcross,
        midi: midi,
        endBeat: endBeat,
        isHold: isHold,
        isHeld: isHeld,
        isPlayed: isPlayed,
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
    this.litHands = const {},
    this.holding = false,
    this.heldNotes = const {},
    this.runBeads = const [],
    this.playedNotes = const {},
    this.sparks = const [],
    this.heat = 0,
  });

  final Chart chart;

  /// The moment being drawn, in beats from the start of the song.
  final double beat;

  /// How far ahead the player can see.
  final double windowInBeats;

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

  @override
  void paint(Canvas canvas, Size size) {
    final geometry = StageGeometry(size: size);

    _paintBackground(canvas, size, geometry);
    if (chart.separatesHands) _paintHandDivide(canvas, size, geometry);
    _paintHitLine(canvas, size, geometry);
    _paintNotes(canvas, geometry);
    _paintSparks(canvas, geometry);
  }

  /// The light a hit leaves on the line: a ring opening outwards and a flash
  /// dying where the note landed.
  ///
  /// Rings and discs rather than anything blurred — a blur filter here costs
  /// more per frame than the rest of the screen put together, and this fires
  /// a dozen times a second in a fast passage.
  void _paintSparks(Canvas canvas, StageGeometry g) {
    if (sparks.isEmpty) return;
    final y = g.hitLineY;
    final radius = g.noteRadius;

    for (final spark in sparks) {
      final at = Offset(g.xAtPosition(spark.across), y);
      final life = spark.age.clamp(0.0, 1.0);
      final fade = (1 - life) * (0.5 + spark.quality * 0.5);
      final colour = AppTheme.chordColor(spark.voices);

      // The ring opens out and thins as it goes. It carries the effect;
      // anything solid and note-sized here reads as another note, which is
      // the last thing the line needs.
      canvas.drawCircle(
        at,
        radius * (0.6 + life * 2.6),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = radius * 0.40 * (1 - life)
          ..color = colour.withValues(alpha: 0.75 * fade),
      );

      // A hot point at the moment of contact, small and gone almost at once.
      final flash = (1 - life * 5).clamp(0.0, 1.0);
      if (flash > 0) {
        canvas.drawCircle(
          at,
          radius * (0.20 + flash * 0.34),
          Paint()..color = Colors.white.withValues(alpha: 0.9 * flash),
        );
      }
    }
  }

  void _paintBackground(Canvas canvas, Size size, StageGeometry g) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF13132A), Color(0xFF08080F)],
        ).createShader(Offset.zero & size),
    );

    // A pool of light on the floor where the beams land, so the hit line feels
    // like a place rather than a rule drawn across the screen.
    final glowCentre = Offset(size.width / 2, g.hitLineY);
    final glowRadius = size.width * (0.75 + heat * 0.35);
    canvas.drawCircle(
      glowCentre,
      glowRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppTheme.accent.withValues(alpha: 0.20 + heat * 0.22),
            AppTheme.accent.withValues(alpha: 0.0),
          ],
        ).createShader(
            Rect.fromCircle(center: glowCentre, radius: glowRadius)),
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
            AppTheme.accentSoft
                .withValues(alpha: 0.22 + flash * 0.22 + heat * 0.30),
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
      final progress =
          StageGeometry.progressFor(tap.beat - beat, windowInBeats);
      if (progress < -0.05) continue;

      // A held note is not finished when its head crosses the line — the
      // finger is meant to stay down until its end does.
      final tailProgress =
          StageGeometry.progressFor(tap.drawnEndBeat - beat, windowInBeats);

      // Every note that sounds at this moment in this hand, wherever its
      // pitch puts it. A chord is drawn as its notes even when one finger
      // takes them all: the picture is of the music, not of the input.
      var dots = <_Dot>[];
      for (final member in group) {
        for (var i = 0; i < member.notes.length; i++) {
          final note = member.notes[i];
          dots.add(_Dot(
            across: member.noteAcross[i],
            midi: note.midi,
            // The tail stops at the next thing this hand is asked for, not
            // at the note's written end — see [Tap.drawnEndBeat]. The sound
            // still runs its full length.
            endBeat: member.drawnEndBeat < member.beat + note.duration
                ? member.drawnEndBeat
                : member.beat + note.duration,
            isHold: member.isHold,
            isHeld: heldNotes.contains((member.beat, note.midi)),
            isPlayed: playedNotes.contains((member.beat, note.midi)),
          ));
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

      final colour = AppTheme.chordColor(tap.voices);
      final radius = g.noteRadius;
      dots = _spreadChord(dots, g, radius, tap.hand);

      double headOf(_Dot dot) => StageGeometry.headProgressFor(progress,
          isHold: dot.isHold && dot.isHeld);

      if (dots.length > 1) {
        _paintChordBand(canvas, g, dots, headOf(dots.first), colour, fade);
      }

      for (final dot in dots) {
        final head = headOf(dot);
        // A note that was played is spent at the line — the burst of light
        // there is what happened to it. Only what nobody caught goes on
        // falling, which is how the screen says which is which.
        if (dot.isPlayed && head > 1) continue;
        if (dot.isHold) {
          _paintHoldBar(
            canvas,
            g,
            dot.across,
            head,
            StageGeometry.progressFor(dot.endBeat - beat, windowInBeats),
            radius,
            colour,
            fade,
          );
        }
        _paintNote(canvas, g, dot.across, head, radius, tap.voices, fade);
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
      final radius = g.noteRadius * 1.15;

      // A disc of the floor behind it, so the ring reads as a ring and not
      // as one more note. A run's beads touch each other; an outline drawn
      // straight over them disappears into the crowd, which is no use for
      // the one thing on screen that is asking to be touched.
      canvas.drawCircle(
        centre,
        radius,
        Paint()..color = const Color(0xFF08080F).withValues(alpha: 0.75),
      );

      if (bead.tracked) {
        // A finger is on it: light it up, so the hand can feel it is on the
        // rails without looking away from the notes coming down.
        canvas.drawCircle(
          centre,
          radius * 2.2,
          Paint()
            ..shader = RadialGradient(
              colors: [
                AppTheme.accentSoft.withValues(alpha: 0.45),
                AppTheme.accentSoft.withValues(alpha: 0.0),
              ],
            ).createShader(
                Rect.fromCircle(center: centre, radius: radius * 2.2)),
        );
        canvas.drawCircle(
          centre,
          radius,
          Paint()..color = Colors.white.withValues(alpha: 0.85),
        );
      }

      // Hollow when nobody is on it — a ring on the line saying "here, put a
      // finger here" rather than a note pretending to have been played.
      canvas.drawCircle(
        centre,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = bead.tracked ? 3.0 : 2.4
          ..color = bead.tracked
              ? Colors.white
              : AppTheme.accentSoft.withValues(alpha: 0.95),
      );
    }
  }

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
    final (zoneStart, zoneEnd) = chart.separatesHands
        ? (hand == Hand.left
            ? (Chart.leftZoneStart, Chart.leftZoneEnd)
            : (Chart.rightZoneStart, Chart.rightZoneEnd))
        : (Chart.leftZoneStart, Chart.rightZoneEnd);

    final places = StageGeometry.spreadChord(
      [for (final dot in sorted) dot.across],
      // Edge to edge plus a little daylight, in the 0..1 the chart works in.
      minGap: radius * 2.3 / g.size.width,
      zoneStart: zoneStart,
      zoneEnd: zoneEnd,
    );

    return [
      for (var i = 0; i < sorted.length; i++) sorted[i].movedTo(places[i]),
    ];
  }

  /// The band tying a chord's notes together.
  ///
  /// Without it, notes side by side read as separate notes and the player
  /// answers them one at a time. The band says: these belong together, and
  /// whether they take one finger or three, they sound at once.
  void _paintChordBand(
      Canvas canvas,
      StageGeometry g,
      List<_Dot> dots,
      double progress,
      Color colour,
      double fade) {
    var lowest = 1.0;
    var highest = 0.0;
    for (final dot in dots) {
      if (dot.across < lowest) lowest = dot.across;
      if (dot.across > highest) highest = dot.across;
    }

    final left = g.positionAtPosition(lowest, progress);
    final right = g.positionAtPosition(highest, progress);
    final thickness = g.noteRadius * 1.35;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(left.dx, left.dy - thickness / 2, right.dx,
            right.dy + thickness / 2),
        Radius.circular(thickness / 2),
      ),
      Paint()
        ..shader = ui.Gradient.linear(left, right, [
          colour.withValues(alpha: 0.30 * fade),
          colour.withValues(alpha: 0.46 * fade),
          colour.withValues(alpha: 0.30 * fade),
        ], const [0.0, 0.5, 1.0]),
    );
  }

  /// The body of a note that has to be held down, drawn as a bar as long as
  /// the note lasts.
  void _paintHoldBar(Canvas canvas, StageGeometry g, double across,
      double progress, double tailProgress, double radius, Color colour,
      double fade) {
    if (tailProgress >= progress) return;

    // The bar reaches from the head back the distance the note lasts. Once
    // the head has stopped at the line the bar can only shorten, its far end
    // sliding down to meet it — so however long it looks is how much of the
    // note is still to come.
    final head = g.positionAtPosition(across, progress);
    final tail = g.positionAtPosition(across, tailProgress);
    final width = radius * StageGeometry.holdBarWidth;

    final top = StageGeometry.holdBarTop(head.dy, tail.dy, radius);
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

  void _paintNote(Canvas canvas, StageGeometry g, double across,
      double progress, double radius, int voices, double fade) {
    final centre = g.positionAtPosition(across, progress);
    final brush = _Brushes.forNote(voices, fade, radius);

    // The brushes are baked around the origin so they can be reused, so the
    // canvas is moved to the note rather than the note to the canvas.
    canvas.save();
    canvas.translate(centre.dx, centre.dy);

    // The halo is a gradient, not a blur: a blur filter here costs more per
    // frame than everything else on screen put together.
    canvas.drawCircle(Offset.zero, radius * 2.0, brush.halo);
    canvas.drawCircle(Offset.zero, radius, brush.body);
    // A bright rim reads as a hard edge at any size.
    canvas.drawCircle(Offset.zero, radius, brush.rim);

    canvas.restore();
  }

  @override
  bool shouldRepaint(StagePainter old) =>
      old.beat != beat ||
      old.chart != chart ||
      old.windowInBeats != windowInBeats ||
      old.holding != holding ||
      old.litHands != litHands ||
      old.heat != heat ||
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

  /// One entry per (voices, fade step). Cleared when the note size changes,
  /// which happens only when the screen does.
  static final Map<int, _Brushes> _cache = {};
  static double _cachedRadius = -1;

  static _Brushes forNote(int voices, double fade, double radius) {
    if (radius != _cachedRadius) {
      _cache.clear();
      _cachedRadius = radius;
    }
    final colours = AppTheme.chordColors.length;
    final index = (voices - 1).clamp(0, colours - 1);
    final step = (fade * _fadeSteps).round().clamp(0, _fadeSteps);
    return _cache[index * (_fadeSteps + 1) + step] ??=
        _build(AppTheme.chordColors[index], step / _fadeSteps, radius);
  }

  static _Brushes _build(Color colour, double fade, double radius) {
    return _Brushes(
      Paint()
        ..shader = RadialGradient(
          colors: [
            colour.withValues(alpha: 0.42 * fade),
            colour.withValues(alpha: 0.16 * fade),
            colour.withValues(alpha: 0.0),
          ],
          stops: const [0.35, 0.6, 1.0],
        ).createShader(
            Rect.fromCircle(center: Offset.zero, radius: radius * 2.0)),
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
