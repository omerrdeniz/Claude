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

  /// Wedges of light fanning out from the point the notes come from.
  ///
  /// They are scenery, not lanes: nothing has to be tapped on one, and none of
  /// them is a boundary. They give the notes somewhere to come *from* — depth
  /// the eye can read — and tint the stage by register, cool at the bottom of
  /// the range and warm at the top.
  void _paintBeams(Canvas canvas, Size size, StageGeometry g) {
    const wedges = 11;
    final reach = g.hitRadius * 1.5;

    for (var i = 0; i < wedges; i++) {
      final across = i / (wedges - 1);
      final colour = AppTheme.colorAcross(across);
      final angle = g.angleAt(across);
      final half = g.spreadAngle / wedges * 0.62;

      // A thin triangle from the origin outward: narrow at the source, wide
      // where the notes arrive, like light through a gap.
      final path = Path()..moveTo(g.origin.dx, g.origin.dy);
      for (final edge in [angle - half, angle + half]) {
        path.lineTo(
          g.origin.dx + math.sin(edge) * reach,
          g.origin.dy + math.cos(edge) * reach,
        );
      }
      path.close();

      canvas.drawPath(
        path,
        Paint()
          ..shader = ui.Gradient.radial(
            g.origin,
            reach,
            [
              colour.withValues(alpha: 0.0),
              colour.withValues(alpha: 0.11),
              colour.withValues(alpha: 0.02),
            ],
            const [0.25, 0.72, 1.0],
          ),
      );
    }
  }

  /// The arc where notes are due.
  ///
  /// An arc rather than a straight line, because every note is the same
  /// distance from the origin when its moment comes; drawing it straight would
  /// put the outer notes past the mark while the middle ones were still short.
  void _paintHitLine(Canvas canvas, Size size, StageGeometry g) {
    final bounds = Rect.fromCircle(center: g.origin, radius: g.hitRadius);
    final start = math.pi / 2 - g.spreadAngle;
    final sweep = g.spreadAngle * 2;
    final flash = litBeams.values.fold(0.0, (max, v) => v > max ? v : max);

    // A soft band under the arc, rather than a blur filter: on a phone browser
    // a blur here costs more per frame than everything else put together.
    canvas.drawArc(
      bounds,
      start,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 26
        ..color = AppTheme.accentSoft.withValues(alpha: 0.10 + flash * 0.10),
    );
    canvas.drawArc(
      bounds,
      start,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..color = AppTheme.accentSoft.withValues(alpha: 0.20 + flash * 0.18),
    );
    canvas.drawArc(
      bounds,
      start,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..color = Colors.white.withValues(alpha: 0.85),
    );
  }

  void _paintNotes(Canvas canvas, StageGeometry g) {
    // Far notes first, so nearer ones overlap them.
    final visible = chart.visibleAt(beat, windowInBeats).toList()
      ..sort((a, b) => b.beat.compareTo(a.beat));

    for (final tap in visible) {
      final progress =
          StageGeometry.progressFor(tap.beat - beat, windowInBeats);
      if (progress < -0.05) continue;

      final colour = AppTheme.colorAcross(tap.across);
      final centre = g.positionAtPosition(tap.across, progress);
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
