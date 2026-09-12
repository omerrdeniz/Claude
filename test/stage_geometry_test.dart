import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:piano_flow/game/chart.dart';
import 'package:piano_flow/game/stage_geometry.dart';

import 'support/library.dart';

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

  test('a triad fits across one hand without piling up', () {
    // Three notes side by side is what a chord asks for, and the hand's zone
    // is a third of the screen. Bigger notes than this and a triad cannot be
    // drawn as three things however they are spaced.
    for (final screen in [
      const Size(320, 568),
      const Size(390, 844),
      const Size(844, 390),
    ]) {
      final any = StageGeometry(size: screen);
      final zone =
          (Chart.rightZoneEnd - Chart.rightZoneStart) * screen.width;
      expect(any.noteRadius * 2 * 3, lessThanOrEqualTo(zone),
          reason: 'three notes do not fit in one hand at $screen');
    }
  });

  test('notes stay clear of each other on a short screen', () {
    const landscape = StageGeometry(size: Size(844, 390));
    expect(landscape.noteRadius * 2, lessThan(390 * 0.15));
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
      expect(any.noteRadius, greaterThan(8));
    }
  });

  group('a held note waits at the line', () {
    test('an ordinary note carries on past it', () {
      expect(StageGeometry.headProgressFor(1.4, isHold: false), 1.4);
      expect(StageGeometry.headProgressFor(0.5, isHold: false), 0.5);
    });

    test('a held one stops there', () {
      expect(StageGeometry.headProgressFor(1.4, isHold: true), 1.0);
      expect(StageGeometry.headProgressFor(3.0, isHold: true), 1.0);
    });

    test('but travels normally on the way in', () {
      expect(StageGeometry.headProgressFor(0.4, isHold: true), 0.4);
      expect(StageGeometry.headProgressFor(1.0, isHold: true), 1.0);
    });

    test('so its bar can only shorten once it has arrived', () {
      const g = StageGeometry(size: Size(390, 844));
      double barLength(double progress, double tailProgress) {
        final head = g.yAt(StageGeometry.headProgressFor(progress, isHold: true));
        return head - g.yAt(tailProgress);
      }
      // Head on the line, tail closing in: shorter every time.
      final lengths = [
        barLength(1.0, 0.4),
        barLength(1.4, 0.7),
        barLength(1.8, 0.9),
        barLength(2.0, 1.0),
      ];
      for (var i = 1; i < lengths.length; i++) {
        expect(lengths[i], lessThan(lengths[i - 1]));
      }
      expect(lengths.last, 0);
    });
  });

  group('a chord is opened out so its notes can be counted', () {
    List<double> spread(List<double> places, {double gap = 0.12}) =>
        StageGeometry.spreadChord(places,
            minGap: gap, zoneStart: 0.58, zoneEnd: 0.91);

    test('notes on top of each other are pushed apart', () {
      final out = spread([0.60, 0.62, 0.64]);
      for (var i = 1; i < out.length; i++) {
        expect(out[i] - out[i - 1], greaterThanOrEqualTo(0.12 - 1e-9));
      }
    });

    test('a chord already spread out is left where its pitches put it', () {
      final wide = [0.60, 0.75, 0.90];
      expect(spread(wide), wide);
    });

    test('the order of the notes is never changed', () {
      final out = spread([0.60, 0.605, 0.61, 0.615]);
      for (var i = 1; i < out.length; i++) {
        expect(out[i], greaterThan(out[i - 1]));
      }
    });

    test('nothing is pushed into the other hand', () {
      // Pressed hard against the top of the zone.
      final out = spread([0.88, 0.89, 0.90]);
      expect(out.first, greaterThanOrEqualTo(0.58 - 1e-9));
      expect(out.last, lessThanOrEqualTo(0.91 + 1e-9));
    });

    test('more notes than the zone can hold share it out evenly', () {
      // Five notes needing 0.12 each would want 0.48; the zone is 0.33.
      final out = spread([0.60, 0.61, 0.62, 0.63, 0.64]);
      expect(out.first, closeTo(0.58, 1e-9));
      expect(out.last, closeTo(0.91, 1e-9));
      final steps = [
        for (var i = 1; i < out.length; i++) out[i] - out[i - 1]
      ];
      for (final step in steps) {
        expect(step, closeTo(steps.first, 1e-9), reason: 'evenly, not piled');
      }
    });

    test('a chord keeps its own proportions', () {
      // What the player asked for: "bu üç notayı birbirlerine olan
      // mesafelerine göre konumlandıralım". The Gnossienne opens on
      // C4-F4-C5 — five semitones then seven — and both gaps used to come
      // out at the minimum, so a third looked like a fifth.
      final out = StageGeometry.spreadChord([0.60, 0.65, 0.72],
          minGap: 0.12, zoneStart: 0.55, zoneEnd: 0.95);
      final first = out[1] - out[0], second = out[2] - out[1];
      expect(second / first, closeTo(0.07 / 0.05, 0.02),
          reason: 'five to seven, as it is written');
      expect(first, greaterThanOrEqualTo(0.12 - 1e-9),
          reason: 'and the closest pair still clears');
    });

    test('a single note is left alone', () {
      expect(spread([0.7]), [0.7]);
      expect(spread([]), isEmpty);
    });
  });

  group('a held note\'s bar stops short of what comes next', () {
    const radius = 20.0;
    // Screen coordinates grow downwards: the head is below the tail.
    double? top(double headY, double tailY) =>
        StageGeometry.holdBarTop(headY, tailY, radius);

    test('it does not reach the end of the note', () {
      final drawn = top(500, 100)!;
      expect(drawn, greaterThan(100),
          reason: 'the bar has to leave room for the next note');
      expect(drawn, closeTo(100 + radius * StageGeometry.holdBarClearance, 1e-9));
    });

    test('and the room it leaves clears a whole note', () {
      // Whatever is struck next sits at the tail with its own radius.
      expect(top(500, 100)! - 100, greaterThan(radius * 2 * 0.7),
          reason: 'daylight, not just a touch');
    });

    test('a long note still gets most of its length', () {
      final length = 500 - top(500, 100)!;
      expect(length, greaterThan(400 * 0.85));
    });

    test('nothing is drawn once there is no bar left', () {
      expect(top(500, 500), isNull, reason: 'the tail has caught the head');
      expect(top(500, 501), isNull, reason: 'and gone past it');
      expect(top(500, 490), isNull, reason: 'a stub, not a bar');
    });
  });

  group('a tail too short to be worth calling a hold', () {
    const radius = 20.0;
    bool reads(double length) => StageGeometry.holdReadsAsBar(length, radius);

    test('a long tail is a hold', () {
      expect(reads(400), isTrue);
    });

    test('a short one is just a note', () {
      expect(reads(radius), isFalse,
          reason: 'a tail no longer than the note is wide says nothing');
      expect(reads(0), isFalse);
    });

    test('the cut is exactly where the bar stops being drawn', () {
      // One rule, asked two ways: if this says a hold, the bar has something
      // to draw, and if it says no, there was never a bar to lose. Drifting
      // apart would leave notes that stop at the line with nothing behind
      // them, which is the very thing being fixed.
      for (var length = 0.0; length < 300; length += 0.5) {
        expect(reads(length), StageGeometry.holdBarTop(length, 0, radius) != null,
            reason: 'disagreed about a tail $length long');
      }
    });

    // A phone, the song at its written speed, and the 1.9 seconds a note
    // takes to come down the screen — PlaySession.approachSeconds.
    double tailPixels(Tap tap, double bpm) =>
        (tap.drawnEndBeat - tap.beat) / (1.9 * bpm / 60) * g.hitLineY;

    List<Tap> quiet(String id) {
      final song = shipped(id);
      final chart = Chart.build(song);
      return chart.taps
          .where((t) =>
              t.isHold &&
              !StageGeometry.holdReadsAsBar(
                  tailPixels(t, song.bpm), g.noteRadius))
          .toList();
    }

    test('nothing loses its bar unless the hand was being taken away', () {
      // The whole reason this is safe. A tail is short only because the hand
      // is wanted again before the note ends, and such a note goes on
      // sounding after the finger leaves it anyway (Tap.sustains). So the
      // picture stops promising a stay the player cannot make, and not one
      // note sounds differently for it.
      for (final info in [for (final s in shippedSongs) s]) {
        for (final tap in quiet(info.id)) {
          expect(tap.sustains, isTrue,
              reason: '${info.id}: a note at beat ${tap.beat} would lose its '
                  'bar without the hand being called away');
        }
      }
    });

    test('it catches the ones the player found, and spares the rest', () {
      // Satie's first Gnossienne is where this was reported.
      expect(quiet('gnossienne-1'), isNotEmpty);
      // The canon's walking bass is the opposite case: a quarter note at 55
      // that rings for 1.09 seconds with nothing crowding it. It was made a
      // hold on purpose and stays one.
      expect(quiet('canon-in-d'), isEmpty);
    });

    test('the bar it lets through is longer than it is thick', () {
      final least = (StageGeometry.holdBarClearance + StageGeometry.holdBarLeast) *
          radius;
      final bar = least - StageGeometry.holdBarClearance * radius;
      expect(bar, greaterThan(radius * StageGeometry.holdBarWidth * 2),
          reason: 'a bar, not a lump under the note');
    });
  });
}
