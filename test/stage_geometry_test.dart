import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:piano_flow/game/stage_geometry.dart';

void main() {
  const size = Size(390, 844);
  const g = StageGeometry(size: size, beamCount: 4);

  test('the hit line sits two thirds down the screen', () {
    expect(g.hitLineY, closeTo(844 * 0.68, 0.01));
  });

  test('pitch spreads evenly across the fan', () {
    final places = [for (var i = 0; i <= 10; i++) g.xAtPosition(i / 10, 1.0)];
    expect(places, orderedEquals([...places]..sort()),
        reason: 'higher pitches must sit further right');
    final gaps = [
      for (var i = 1; i < places.length; i++) places[i] - places[i - 1]
    ];
    // Equal steps of pitch are equal steps of angle, so the horizontal gaps
    // narrow slightly toward the edges of the fan. What matters is that no
    // gap collapses or doubles — the spread stays readable end to end.
    for (final gap in gaps) {
      expect(gap, greaterThan(gaps.first * 0.8));
      expect(gap, lessThan(gaps.first * 1.25));
    }
  });

  test('every note is the same distance from the origin when it is due', () {
    // This is what makes the arc the mark rather than a straight line: an
    // outer note must not arrive before a middle one.
    for (final across in [0.0, 0.25, 0.5, 0.75, 1.0]) {
      final place = g.positionAtPosition(across, 1.0);
      expect((place - g.origin).distance, closeTo(g.hitRadius, 0.01));
    }
  });

  test('the outermost notes stay clear of the screen edge', () {
    // A note at the very edge would have its glow clipped and sit under the
    // thumb holding the phone.
    expect(g.xAtPosition(0, 1.0), greaterThan(size.width * 0.04));
    expect(g.xAtPosition(1, 1.0), lessThan(size.width * 0.96));
  });

  test('neighbouring pitches sit next to each other, not in columns', () {
    // Two pitches a hair apart must land a hair apart on screen.
    final a = g.xAtPosition(0.50, 1.0);
    final b = g.xAtPosition(0.51, 1.0);
    expect((b - a).abs(), lessThan(size.width * 0.02));
    expect(b, greaterThan(a));
  });

  test('notes are born at one point and fan out from it', () {
    // Everything starts at the origin and spreads as it travels: that is the
    // depth cue, and it is why a note appears to come from beyond the screen.
    for (final across in [0.0, 0.5, 1.0]) {
      expect(g.positionAtPosition(across, 0), g.origin);
    }
    final spreadEarly =
        (g.xAtPosition(1, 0.25) - g.xAtPosition(0, 0.25)).abs();
    final spreadLate = (g.xAtPosition(1, 1.0) - g.xAtPosition(0, 1.0)).abs();
    expect(spreadEarly, lessThan(spreadLate));
  });

  test('the fan does not open so far that the arc swallows the screen', () {
    for (final screen in [const Size(390, 844), const Size(844, 390),
        const Size(1024, 300)]) {
      final wide = StageGeometry(size: screen, beamCount: 4);
      final middle = wide.positionAtPosition(0.5, 1.0).dy;
      final edge = wide.positionAtPosition(0.0, 1.0).dy;
      expect(middle - edge, lessThan(screen.height * 0.32),
          reason: 'arc sags too far on \$screen');
    }
  });

  test('the origin sits beyond the top of the screen', () {
    expect(g.origin.dy, lessThan(0));
    expect(g.origin.dx, closeTo(size.width / 2, 0.01));
  });

  test('the layout is symmetric about the centre', () {
    for (final progress in [0.0, 0.5, 1.0]) {
      final left = g.xAt(0, progress);
      final right = g.xAt(3, progress);
      expect(left + right, closeTo(size.width, 0.01));
    }
  });

  test('the fan reaches most of the width without spilling off it', () {
    final left = g.xAtPosition(0, 1.0);
    final right = g.xAtPosition(1, 1.0);
    expect(left, greaterThan(0));
    expect(right, lessThan(size.width));
    expect(right - left, greaterThan(size.width * 0.8));
  });

  test('notes travel at a constant speed', () {
    // Equal steps in progress must cover equal distance: easing the motion
    // would quietly shift where the beat appears to fall.
    final steps = [for (var i = 0; i <= 10; i++) g.yAt(i / 10)];
    final deltas = [
      for (var i = 1; i < steps.length; i++) steps[i] - steps[i - 1]
    ];
    for (final delta in deltas) {
      expect(delta, closeTo(deltas.first, 0.001));
    }
  });

  test('a note reaches the line exactly when it is due', () {
    expect(StageGeometry.progressFor(0, 4), 1.0);
    expect(g.yAt(StageGeometry.progressFor(0, 4)), g.hitLineY);
  });

  test('progress runs from the top of the screen to the line', () {
    expect(StageGeometry.progressFor(4, 4), 0.0, reason: 'a full window away');
    expect(StageGeometry.progressFor(2, 4), 0.5);
    expect(StageGeometry.progressFor(-1, 4), greaterThan(1.0));
  });

  test('notes grow as they approach and shrink once past', () {
    expect(g.noteRadiusAt(0.2), lessThan(g.noteRadiusAt(0.8)));
    expect(g.noteRadiusAt(0.8), lessThan(g.noteRadiusAt(1.0)));
    expect(g.noteRadiusAt(1.2), lessThan(g.noteRadiusAt(1.0)));
  });

  test('beams stay wide enough to hit on a small screen', () {
    const narrow = StageGeometry(size: Size(320, 568), beamCount: 4);
    expect(narrow.beamWidthAt(1.0), greaterThan(44),
        reason: 'below the minimum comfortable touch target');
  });

  test('a single beam is centred', () {
    const solo = StageGeometry(size: size, beamCount: 1);
    expect(solo.xAt(0, 1.0), closeTo(size.width / 2, 0.01));
  });
}
