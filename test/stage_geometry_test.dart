import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:piano_flow/game/stage_geometry.dart';

void main() {
  const size = Size(390, 844);
  const g = StageGeometry(size: size, beamCount: 4);

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

  test('the outermost notes stay clear of the screen edge', () {
    // A note at the very edge would have its glow clipped and sit under the
    // thumb holding the phone.
    expect(g.xAtPosition(0), greaterThan(size.width * 0.04));
    expect(g.xAtPosition(1), lessThan(size.width * 0.96));
  });

  test('the layout uses most of the width', () {
    expect(g.xAtPosition(1) - g.xAtPosition(0), greaterThan(size.width * 0.7));
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
      final left = g.xAtPosition(across);
      final right = g.xAtPosition(1 - across);
      expect(left + right, closeTo(size.width, 0.01));
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
    const landscape = StageGeometry(size: Size(844, 390), beamCount: 6);
    expect(landscape.noteRadiusAt(1.0) * 2, lessThan(390 * 0.15));
  });

  test('the layout holds up at any shape of screen', () {
    for (final screen in [
      const Size(320, 568),
      const Size(390, 844),
      const Size(844, 390),
      const Size(1024, 300),
    ]) {
      final any = StageGeometry(size: screen, beamCount: 4);
      expect(any.xAtPosition(0), greaterThan(0));
      expect(any.xAtPosition(1), lessThan(screen.width));
      expect(any.hitLineY, lessThan(screen.height));
      expect(any.noteRadiusAt(1.0), greaterThan(8));
    }
  });
}
