import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../game/chart.dart';
import '../music/note.dart';
import '../game/stage_geometry.dart';
import '../theme/app_theme.dart';

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

  @override
  void paint(Canvas canvas, Size size) {
    final geometry = StageGeometry(size: size);

    _paintBackground(canvas, size, geometry);
    if (chart.separatesHands) _paintHandDivide(canvas, size, geometry);
    _paintHitLine(canvas, size, geometry);
    _paintNotes(canvas, geometry);
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
    final glowRadius = size.width * 0.75;
    canvas.drawCircle(
      glowCentre,
      glowRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppTheme.accent.withValues(alpha: 0.20),
            AppTheme.accent.withValues(alpha: 0.0),
          ],
        ).createShader(
            Rect.fromCircle(center: glowCentre, radius: glowRadius)),
    );
  }

  /// The line where notes are due.
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
            AppTheme.accentSoft.withValues(alpha: 0.22 + flash * 0.22),
            AppTheme.accentSoft.withValues(alpha: 0.0),
          ],
          const [0.0, 0.5, 1.0],
        ),
    );

    canvas.drawLine(
      Offset(0, y),
      Offset(size.width, y),
      Paint()
        ..strokeWidth = 2
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
      // finger is meant to stay down until its end does. So a hold is judged
      // gone by its tail, and stays on screen for as long as it is still
      // being asked for.
      final tailProgress =
          StageGeometry.progressFor(tap.endBeat - beat, windowInBeats);
      final departed = tap.isHold ? tailProgress : progress;

      final colour = AppTheme.chordColor(tap.voices);
      final radius = g.noteRadiusAt(progress);

      // Distant notes are dimmer; ones past the line drop away quickly, so
      // the eye is never asked whether a note below the line still counts.
      final fade = departed > 1
          ? (1 - (departed - 1) / 0.16).clamp(0.0, 1.0)
          : (0.35 + progress.clamp(0.0, 1.0) * 0.65).clamp(0.0, 1.0);
      if (fade <= 0.01) continue;

      if (group.length > 1) {
        _paintChordBand(canvas, g, group, progress, colour, fade);
      }

      for (final member in group) {
        // A long note is drawn as a bar reaching back the way it came: the
        // finger is meant to stay down for its length, and the bar is how
        // long. Struck notes stay plain circles, so the two never look alike.
        if (member.isHold) {
          _paintHoldBar(canvas, g, member, progress, tailProgress, radius,
              colour, fade);
        }
        _paintNote(canvas, g, member, progress, radius, colour, fade);
      }
    }
  }

  /// The band tying a chord's notes together.
  ///
  /// Without it three dots in a row are three separate notes to the eye, and
  /// the player answers them one at a time. The band says: these are one
  /// gesture, put three fingers down at once.
  void _paintChordBand(Canvas canvas, StageGeometry g, List<Tap> group,
      double progress, Color colour, double fade) {
    var lowest = 1.0;
    var highest = 0.0;
    for (final tap in group) {
      if (tap.across < lowest) lowest = tap.across;
      if (tap.across > highest) highest = tap.across;
    }

    final left = g.positionAtPosition(lowest, progress);
    final right = g.positionAtPosition(highest, progress);
    final thickness = g.noteRadiusAt(progress) * 1.35;

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
  void _paintHoldBar(Canvas canvas, StageGeometry g, Tap tap, double progress,
      double tailProgress, double radius, Color colour, double fade) {
    if (tailProgress >= progress) return;

    // The bar is exactly as long as the note: it starts at the head and
    // reaches back the distance the note lasts, and it keeps travelling until
    // its far end has crossed the line. However long it looks is how long the
    // finger stays down.
    final head = g.positionAtPosition(tap.across, progress);
    final tail = g.positionAtPosition(tap.across, tailProgress);
    final width = radius * 0.72;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(head.dx - width, tail.dy, head.dx + width, head.dy),
        Radius.circular(width),
      ),
      Paint()..color = colour.withValues(alpha: 0.35 * fade),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(head.dx - width, tail.dy, head.dx + width, head.dy),
        Radius.circular(width),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.white.withValues(alpha: 0.28 * fade),
    );
  }

  void _paintNote(Canvas canvas, StageGeometry g, Tap tap, double progress,
      double radius, Color colour, double fade) {
    final centre = g.positionAtPosition(tap.across, progress);

    // The halo is a gradient, not a blur: a blur filter here costs more per
    // frame than everything else on screen put together.
    canvas.drawCircle(
      centre,
      radius * 2.0,
      Paint()
        ..shader = RadialGradient(
          colors: [
            colour.withValues(alpha: 0.42 * fade),
            colour.withValues(alpha: 0.16 * fade),
            colour.withValues(alpha: 0.0),
          ],
          stops: const [0.35, 0.6, 1.0],
        ).createShader(Rect.fromCircle(center: centre, radius: radius * 2.0)),
    );

    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Color.lerp(Colors.white, colour, 0.15)!.withValues(alpha: fade),
            colour.withValues(alpha: fade),
            colour.withValues(alpha: 0.75 * fade),
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: centre, radius: radius)),
    );

    // A bright rim reads as a hard edge at any size.
    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = Colors.white.withValues(alpha: 0.55 * fade),
    );

    // How many notes this one touch carries, as pips inside it. On the easier
    // levels a chord arrives under a single finger, and without these there
    // is nothing to say that three notes are about to sound rather than one.
    if (tap.notes.length > 1) {
      final count = tap.notes.length;
      final pip = (radius * 0.17).clamp(1.6, 4.0);
      final spacing = pip * 2.6;
      final start = -(count - 1) / 2 * spacing;
      for (var i = 0; i < count; i++) {
        canvas.drawCircle(
          Offset(centre.dx + start + i * spacing, centre.dy),
          pip,
          Paint()..color = Colors.white.withValues(alpha: 0.9 * fade),
        );
      }
    }
  }

  @override
  bool shouldRepaint(StagePainter old) =>
      old.beat != beat ||
      old.chart != chart ||
      old.windowInBeats != windowInBeats ||
      old.holding != holding ||
      old.litHands != litHands;
}
