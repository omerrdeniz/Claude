import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:piano_flow/game/stage_geometry.dart';

void main() {
  const size = Size(390, 844);
  const g = StageGeometry(size: size);

  test('the hit line sits two thirds down the screen', () {
    expect(g.hitLineY, closeTo(844 * 0.68, 0.01));
  });

  test('pitch maps evenly across the screen', () {
    final places = [for (var i = 0; i <= 10; i++) g.xAtPosition(i / 10)];
    expect(places, orderedEquals([...places]..sort()),
        reason: 'higher pitches must sit further right');
    final gaps = [
      for (var i = 1; i < places.length; i++) places[i] - places[i - 1]
    ];
    for (final gap in gaps) {
      expect(gap, closeTo(gaps.first, 0.01), reason: 'no jumps between pitches');
    }
  });

  test('neighbouring pitches sit next to each other, not in columns', () {
    final a = g.xAtPosition(0.50);
    final b = g.xAtPosition(0.51);
    expect((b - a).abs(), lessThan(size.width * 0.02));
    expect(b, greaterThan(a));
  });

  test('a position is a fraction of the width', () {
    // Where a note sits is decided by the chart, which keeps its own margins
    // and hand zones; the geometry only turns that into pixels.
    expect(g.xAtPosition(0), 0);
    expect(g.xAtPosition(0.5), size.width / 2);
    expect(g.xAtPosition(1), size.width);
  });

  test('a note keeps its place across the screen as it falls', () {
    // Nothing drifts sideways on the way down: where a note will land is
    // readable from the moment it appears.
    for (final progress in [0.0, 0.3, 0.7, 1.0, 1.2]) {
      expect(g.positionAtPosition(0.25, progress).dx,
          closeTo(g.xAtPosition(0.25), 0.001));
    }
  });

  test('every note reaches the line at the same moment', () {
    for (final across in [0.0, 0.25, 0.5, 0.75, 1.0]) {
      expect(g.positionAtPosition(across, 1.0).dy, closeTo(g.hitLineY, 0.01));
    }
  });

  test('the layout is symmetric about the centre', () {
    for (final across in [0.0, 0.25, 0.5]) {
      expect(g.xAtPosition(across) + g.xAtPosition(1 - across),
          closeTo(size.width, 0.01));
    }
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

  test('notes stay clear of each other on a short screen', () {
    const landscape = StageGeometry(size: Size(844, 390));
    expect(landscape.noteRadiusAt(1.0) * 2, lessThan(390 * 0.15));
  });

  test('the layout holds up at any shape of screen', () {
    for (final screen in [
      const Size(320, 568),
      const Size(390, 844),
      const Size(844, 390),
      const Size(1024, 300),
    ]) {
      final any = StageGeometry(size: screen);
      expect(any.hitLineY, lessThan(screen.height));
      expect(any.noteRadiusAt(1.0), greaterThan(8));
    }
  });
}
