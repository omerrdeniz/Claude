import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../game/chart.dart';
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
    this.litBeams = const {},
  });

  final Chart chart;

  /// The moment being drawn, in beats from the start of the song.
  final double beat;

  /// How far ahead the player can see.
  final double windowInBeats;

  /// Beams flashing from a recent hit, mapped to how fresh it is (1 to 0).
  final Map<int, double> litBeams;

  @override
  void paint(Canvas canvas, Size size) {
    final geometry = StageGeometry(size: size, beamCount: chart.beamCount);

    _paintBackground(canvas, size, geometry);
    _paintBeams(canvas, size, geometry);
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

  void _paintBeams(Canvas canvas, Size size, StageGeometry g) {
    // Beams run past the hit line to the bottom of the screen; stopping them
    // at the line would make it look like a wall.
    final bottomProgress = size.height / g.hitLineY;

    for (var beam = 0; beam < chart.beamCount; beam++) {
      final colour = AppTheme.beamColor(beam, chart.beamCount);
      final lit = litBeams[beam] ?? 0.0;

      final topWidth = g.beamWidthAt(0) * 0.5;
      final bottomWidth = g.beamWidthAt(bottomProgress) * 0.5;
      final topX = g.xAt(beam, 0);
      final bottomX = g.xAt(beam, bottomProgress);

      final path = Path()
        ..moveTo(topX - topWidth, 0)
        ..lineTo(topX + topWidth, 0)
        ..lineTo(bottomX + bottomWidth, size.height)
        ..lineTo(bottomX - bottomWidth, size.height)
        ..close();

      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colour.withValues(alpha: 0.02),
              colour.withValues(alpha: 0.10 + lit * 0.28),
              colour.withValues(alpha: 0.03),
            ],
            stops: const [0.0, 0.68, 1.0],
          ).createShader(Offset.zero & size),
      );

      // Edges catch the light, which is what makes it read as a beam and not
      // a flat stripe.
      final edge = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colour.withValues(alpha: 0.0),
            colour.withValues(alpha: 0.35 + lit * 0.5),
            colour.withValues(alpha: 0.05),
          ],
          stops: const [0.0, 0.68, 1.0],
        ).createShader(Offset.zero & size);
      canvas.drawLine(Offset(topX - topWidth, 0),
          Offset(bottomX - bottomWidth, size.height), edge);
      canvas.drawLine(Offset(topX + topWidth, 0),
          Offset(bottomX + bottomWidth, size.height), edge);
    }
  }

  void _paintHitLine(Canvas canvas, Size size, StageGeometry g) {
    final y = g.hitLineY;

    // A soft band rather than a blurred line: a blur filter here costs more
    // per frame than everything else on screen put together, and on a phone
    // browser that is the difference between flowing and stuttering.
    final glow = Rect.fromLTWH(0, y - 22, size.width, 44);
    canvas.drawRect(
      glow,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, glow.top),
          Offset(0, glow.bottom),
          [
            AppTheme.accentSoft.withValues(alpha: 0.0),
            AppTheme.accentSoft.withValues(alpha: 0.28),
            AppTheme.accentSoft.withValues(alpha: 0.0),
          ],
          const [0.0, 0.5, 1.0],
        ),
    );

    canvas.drawLine(
      Offset(0, y),
      Offset(size.width, y),
      Paint()
        ..strokeWidth = 2.4
        ..shader = LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.10),
            Colors.white.withValues(alpha: 1.0),
            Colors.white.withValues(alpha: 0.10),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromLTWH(0, y - 2, size.width, 4)),
    );

    // A ring on each beam, marking where that beam's notes land. The line
    // says when; these say where.
    final targetRadius = g.noteRadiusAt(1.0);
    for (var beam = 0; beam < chart.beamCount; beam++) {
      final centre = Offset(g.xAt(beam, 1.0), y);
      final lit = litBeams[beam] ?? 0.0;
      final colour = AppTheme.beamColor(beam, chart.beamCount);

      canvas.drawCircle(
        centre,
        targetRadius * 1.18,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = colour.withValues(alpha: 0.30 + lit * 0.6),
      );
      if (lit > 0) {
        canvas.drawCircle(
          centre,
          targetRadius * (1.2 + (1 - lit) * 1.6),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3 * lit
            ..color = colour.withValues(alpha: 0.5 * lit),
        );
      }
    }
  }

  void _paintNotes(Canvas canvas, StageGeometry g) {
    // Far notes first, so nearer ones overlap them.
    final visible = chart.visibleAt(beat, windowInBeats).toList()
      ..sort((a, b) => b.beat.compareTo(a.beat));

    for (final tap in visible) {
      final progress =
          StageGeometry.progressFor(tap.beat - beat, windowInBeats);
      if (progress < -0.05) continue;

      final colour = AppTheme.beamColor(tap.beam, chart.beamCount);
      final centre = g.positionAt(tap.beam, progress);
      final radius = g.noteRadiusAt(progress);

      // Distant notes are dimmer; ones past the line drop away quickly, so
      // the eye is never asked whether a note below the line still counts.
      final fade = progress > 1
          ? (1 - (progress - 1) / 0.16).clamp(0.0, 1.0)
          : (0.35 + progress * 0.65).clamp(0.0, 1.0);
      if (fade <= 0.01) continue;

      if (tap.isHold) _paintHoldTail(canvas, g, tap, progress, colour, fade);

      // The halo is a gradient, not a blur, for the same reason as the line.
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

      // A chord carries more than one note, so it is drawn heavier.
      if (tap.notes.length > 1) {
        canvas.drawCircle(
          centre,
          radius * 0.45,
          Paint()..color = Colors.white.withValues(alpha: 0.85 * fade),
        );
      }
    }
  }

  /// A held note trails behind itself, as long as the note lasts.
  void _paintHoldTail(Canvas canvas, StageGeometry g, Tap tap, double progress,
      Color colour, double fade) {
    final tailProgress = StageGeometry.progressFor(
        tap.beat + tap.duration - beat, windowInBeats);
    if (tailProgress >= progress) return;

    final head = g.positionAt(tap.beam, progress);
    final tail = g.positionAt(tap.beam, math.max(tailProgress, -0.2));

    canvas.drawLine(
      tail,
      head,
      Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = g.noteRadiusAt(progress) * 1.1
        ..shader = ui.Gradient.linear(tail, head, [
          colour.withValues(alpha: 0.05 * fade),
          colour.withValues(alpha: 0.45 * fade),
        ]),
    );
  }

  @override
  bool shouldRepaint(StagePainter old) =>
      old.beat != beat ||
      old.chart != chart ||
      old.windowInBeats != windowInBeats ||
      old.litBeams != litBeams;
}
