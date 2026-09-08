import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:piano_flow/game/stage_geometry.dart';

void main() {
  const size = Size(390, 844);
  const g = StageGeometry(size: size, beamCount: 4);

  test('the hit line sits two thirds down the screen', () {
    expect(g.hitLineY, closeTo(844 * 0.68, 0.01));
  });

  test('beams are evenly spaced at the line and fill the width', () {
    final centres = [for (var i = 0; i < 4; i++) g.xAt(i, 1.0)];
    expect(centres, orderedEquals([...centres]..sort()));
    final gaps = [
      for (var i = 1; i < centres.length; i++) centres[i] - centres[i - 1]
    ];
    for (final gap in gaps) {
      expect(gap, closeTo(size.width / 4, 0.01));
    }
  });

  test('beams converge toward the top, which is what makes it look deep', () {
    final atTop = g.xAt(0, 0) - size.width / 2;
    final atLine = g.xAt(0, 1) - size.width / 2;
    expect(atTop.abs(), lessThan(atLine.abs()));
    expect(atTop.sign, atLine.sign, reason: 'a beam must not cross the centre');
  });

  test('the layout is symmetric about the centre', () {
    for (final progress in [0.0, 0.5, 1.0]) {
      final left = g.xAt(0, progress);
      final right = g.xAt(3, progress);
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
