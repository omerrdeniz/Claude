import 'package:flutter_test/flutter_test.dart';
import 'package:piano_flow/game/calibration.dart';

/// Play a whole calibration: [taps] clicks, each answered [lateMs] later,
/// with [jitterMs] alternating either side so the taps are not identical.
LatencyTally run({
  required double lateMs,
  int taps = 16,
  double period = 600,
  double jitterMs = 0,
  LatencyTally? into,
}) {
  final tally = into ?? LatencyTally();
  for (var i = 0; i < taps; i++) {
    final click = 1000 + i * period;
    tally.addClick(click);
    tally.addTap(click + lateMs + (i.isEven ? jitterMs : -jitterMs));
  }
  return tally;
}

void main() {
  group('measuring', () {
    test('a hand that is consistently late reads as exactly that', () {
      expect(run(lateMs: 120).measuredMs, closeTo(120, 0.001));
    });

    test('and one that is early reads negative', () {
      expect(run(lateMs: -30).measuredMs, closeTo(-30, 0.001));
    });

    test('nothing is said until there are enough taps', () {
      final tally = LatencyTally(minimumTaps: 8);
      run(lateMs: 100, taps: 7, into: tally);
      expect(tally.measuredMs, isNull);
      expect(tally.hasEnough, isFalse);
      run(lateMs: 100, taps: 1, into: tally);
      expect(tally.hasEnough, isTrue);
      expect(tally.measuredMs, isNotNull);
    });

    test('it stops once it has what it asked for', () {
      final tally = run(lateMs: 100, taps: 30);
      expect(tally.taps, tally.wantedTaps);
      expect(tally.isDone, isTrue);
    });
  });

  group('taps that should not count', () {
    test('one nowhere near a click is ignored, not counted as wild', () {
      final tally = LatencyTally(windowMs: 280);
      run(lateMs: 40, taps: 12, into: tally);
      final before = tally.measuredMs;
      // Someone drumming their fingers halfway between two clicks.
      expect(tally.addTap(1000 + 12 * 600 + 300), isFalse);
      expect(tally.measuredMs, before);
    });

    test('a second tap on the same click does not count twice', () {
      final tally = LatencyTally();
      tally.addClick(1000);
      expect(tally.addTap(1050), isTrue);
      expect(tally.addTap(1060), isFalse, reason: 'that click is answered');
      expect(tally.taps, 1);
    });

    test('one bad tap does not drag the answer', () {
      // Eleven good taps at 100 ms and one caught very late.
      final tally = LatencyTally(windowMs: 280, wantedTaps: 12);
      for (var i = 0; i < 11; i++) {
        final click = 1000 + i * 600.0;
        tally.addClick(click);
        tally.addTap(click + 100);
      }
      final click = 1000 + 11 * 600.0;
      tally.addClick(click);
      tally.addTap(click + 270);
      // An average would be pulled to 114; the middle does not notice.
      expect(tally.measuredMs, closeTo(100, 0.001));
    });
  });

  test('the spread says how steady the tapping was', () {
    expect(run(lateMs: 100, jitterMs: 0).spreadMs, closeTo(0, 0.001));
    expect(run(lateMs: 100, jitterMs: 25).spreadMs, closeTo(25, 0.001));
  });

  group('what gets stored', () {
    // The game adds the device's own figure by itself, so only the part it
    // does not know about belongs in the manual setting.
    test('is what is left after the device has had its say', () {
      final tally = run(lateMs: 180);
      expect(tally.offsetAgainst(60), closeTo(120, 0.001));
    });

    test('and can be negative when the device overstates', () {
      final tally = run(lateMs: 40);
      expect(tally.offsetAgainst(90), closeTo(-50, 0.001));
    });

    test('so device plus offset comes back to what was measured', () {
      const device = 73.0;
      final tally = run(lateMs: 155);
      expect(device + tally.offsetAgainst(device)!,
          closeTo(tally.measuredMs!, 0.001));
    });

    test('nothing is offered before there is a measurement', () {
      expect(LatencyTally().offsetAgainst(50), isNull);
    });
  });

  test('starting over forgets everything', () {
    final tally = run(lateMs: 100);
    expect(tally.measuredMs, isNotNull);
    tally.reset();
    expect(tally.taps, 0);
    expect(tally.measuredMs, isNull);
    expect(tally.isDone, isFalse);
  });
}
