import 'package:flutter_test/flutter_test.dart';
import 'package:piano_flow/game/judgement.dart';

void main() {
  const judge = Judge();

  group('verdicts', () {
    test('dead on the beat is perfect', () {
      expect(judge.verdictFor(0), Verdict.perfect);
    });

    test('early and late are treated alike', () {
      for (final error in [30.0, 80.0, 150.0, 400.0]) {
        expect(judge.verdictFor(error), judge.verdictFor(-error),
            reason: 'rushing and dragging by ${error}ms should score the same');
      }
    });

    test('each window gives its own verdict', () {
      expect(judge.verdictFor(49), Verdict.perfect);
      expect(judge.verdictFor(51), Verdict.great);
      expect(judge.verdictFor(99), Verdict.great);
      expect(judge.verdictFor(101), Verdict.good);
      expect(judge.verdictFor(169), Verdict.good);
      expect(judge.verdictFor(171), Verdict.miss);
    });

    test('quality falls off from dead on to the edge of the window', () {
      expect(judge.quality(0), 1.0);
      expect(judge.quality(judge.goodMs), 0.0);
      expect(judge.quality(85), closeTo(0.5, 0.01));
      expect(judge.quality(9999), 0.0, reason: 'never negative');
    });
  });

  group('scoring', () {
    late Scoreboard board;
    setUp(() => board = Scoreboard());

    test('starts empty', () {
      expect(board.score, 0);
      expect(board.combo, 0);
      expect(board.grade, '-');
    });

    test('a hit scores and extends the streak', () {
      board.register(Verdict.perfect);
      expect(board.score, 100);
      expect(board.combo, 1);
    });

    test('a miss scores nothing and breaks the streak', () {
      board.register(Verdict.perfect);
      board.register(Verdict.miss);
      expect(board.combo, 0);
      expect(board.score, 100);
    });

    test('the best streak survives a break', () {
      for (var i = 0; i < 5; i++) {
        board.register(Verdict.great);
      }
      board.register(Verdict.miss);
      expect(board.bestCombo, 5);
      expect(board.combo, 0);
    });

    test('the multiplier climbs in steps', () {
      expect(board.multiplier, 1);
      for (var i = 0; i < 10; i++) {
        board.register(Verdict.good);
      }
      expect(board.multiplier, 2);
      for (var i = 0; i < 15; i++) {
        board.register(Verdict.good);
      }
      expect(board.multiplier, 3);
      for (var i = 0; i < 25; i++) {
        board.register(Verdict.good);
      }
      expect(board.multiplier, 4);
    });

    test('staying clean pays, and pays more the longer it lasts', () {
      // The same number of well-played notes, one run unbroken and one
      // interrupted, over runs of growing length.
      double advantageOver(int notes) {
        final clean = Scoreboard();
        final broken = Scoreboard();
        for (var i = 0; i < notes; i++) {
          clean.register(Verdict.perfect);
          broken.register(Verdict.perfect);
          broken.register(Verdict.miss);
        }
        return clean.score / broken.score;
      }

      expect(advantageOver(30), greaterThan(1.5));
      expect(advantageOver(120), greaterThan(advantageOver(30)),
          reason: 'the reward for a streak should grow with it');
      // It closes on the top multiplier from below but can never reach it:
      // every run has to climb through the lower tiers first.
      expect(advantageOver(120), greaterThan(3));
      expect(advantageOver(120), lessThan(4));
    });

    test('accuracy reflects how cleanly it was played', () {
      for (var i = 0; i < 10; i++) {
        board.register(Verdict.perfect);
      }
      expect(board.accuracy, 1.0);
      expect(board.grade, 'S');

      final sloppy = Scoreboard();
      for (var i = 0; i < 10; i++) {
        sloppy.register(Verdict.good);
      }
      expect(sloppy.accuracy, closeTo(0.4, 0.001));
      expect(sloppy.grade, 'D');
    });

    test('every note is counted', () {
      board.register(Verdict.perfect);
      board.register(Verdict.miss);
      board.register(Verdict.good);
      expect(board.notesPlayed, 3);
      expect(board.counts[Verdict.perfect], 1);
      expect(board.counts[Verdict.miss], 1);
    });

    test('reset clears everything', () {
      board.register(Verdict.perfect);
      board.reset();
      expect(board.score, 0);
      expect(board.notesPlayed, 0);
      expect(board.bestCombo, 0);
    });
  });
}
