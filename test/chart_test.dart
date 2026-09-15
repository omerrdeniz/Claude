import 'package:flutter_test/flutter_test.dart';
import 'package:piano_flow/game/chart.dart';
import 'package:piano_flow/music/note.dart';
import 'package:piano_flow/music/song.dart';

import 'support/library.dart';

Song songOf(List<Note> notes, {double bpm = 120}) =>
    Song(id: 'test', title: 'Test', composer: '', bpm: bpm, notes: notes);

Note note(
  double beat,
  int midi, {
  double duration = 0.5,
  Hand hand = Hand.right,
}) => Note(beat: beat, midi: midi, duration: duration, hand: hand);

void main() {
  group('what the player is given', () {
    final twoHands = songOf([
      note(0, 72),
      note(0, 48, hand: Hand.left),
      note(0, 52, hand: Hand.left),
      note(0, 55, hand: Hand.left),
      note(1, 74),
    ]);

    test('easy is one zone and one finger', () {
      final chart = Chart.build(twoHands, difficulty: Difficulty.easy);
      expect(chart.separatesHands, isFalse);
      final atZero = chart.taps.where((t) => t.beat == 0);
      expect(atZero, hasLength(1), reason: 'the whole moment is one touch');
      expect(atZero.single.notes, hasLength(4));
    });

    test('normal splits the hands but keeps a chord under one finger', () {
      final chart = Chart.build(twoHands, difficulty: Difficulty.normal);
      expect(chart.separatesHands, isTrue);
      final atZero = chart.taps.where((t) => t.beat == 0).toList();
      expect(atZero, hasLength(2), reason: 'one touch per hand');
      expect(atZero.map((t) => t.hand).toSet(), {Hand.left, Hand.right});
      final left = atZero.firstWhere((t) => t.hand == Hand.left);
      expect(left.notes, hasLength(3), reason: 'the triad is one touch');
    });

    test('hard asks for a finger per note of a chord', () {
      final chart = Chart.build(twoHands, difficulty: Difficulty.hard);
      final atZero = chart.taps.where((t) => t.beat == 0).toList();
      expect(
        atZero,
        hasLength(4),
        reason: 'three in the left, one in the right',
      );
      expect(atZero.where((t) => t.hand == Hand.left), hasLength(3));
      expect(atZero.every((t) => t.notes.length == 1), isTrue);
    });

    test('nothing plays itself once the hands are separated', () {
      for (final difficulty in [Difficulty.normal, Difficulty.hard]) {
        expect(
          Chart.build(twoHands, difficulty: difficulty).autoNotes,
          isEmpty,
        );
      }
    });

    test('every note is either played or played for the player', () {
      for (final difficulty in Difficulty.values) {
        for (final song in shippedSongs) {
          final chart = Chart.build(song, difficulty: difficulty);
          // An ornament is played by the player too — it just rides the touch
          // it decorates rather than being one of its own. Counting it with
          // the touch is what keeps this sum honest.
          final tapped = chart.taps
              .expand((t) => [...t.notes, ...t.grace])
              .length;
          expect(
            tapped + chart.autoNotes.length,
            song.notes.length,
            reason: '${song.title} on ${difficulty.label}',
          );
        }
      }
    });
  });

  group('an ornament rides the note it leans on', () {
    Chart gnossienne() => Chart.build(shipped('gnossienne-1'));

    test('it is not a touch of its own', () {
      final chart = gnossienne();
      // Sixty milliseconds apart is not two touches; it is one movement of
      // the hand. Nothing in the chart may ask for a second finger that soon.
      final ms = 60000 / chart.song.bpm;
      for (final hand in Hand.values) {
        final line = chart.taps.where((t) => t.hand == hand).toList()
          ..sort((a, b) => a.beat.compareTo(b.beat));
        for (var i = 1; i < line.length; i++) {
          final gap = (line[i].beat - line[i - 1].beat) * ms;
          expect(
            gap,
            greaterThan(Tap.graceSeconds * 1000),
            reason:
                'two touches ${gap.toStringAsFixed(0)} ms apart at '
                'beat ${line[i].beat}',
          );
        }
      }
    });

    test('and the piece keeps all of them', () {
      final withGrace = gnossienne().taps.where((t) => t.hasGrace);
      expect(
        withGrace,
        hasLength(100),
        reason: "Satie's first Gnossienne is written with a hundred",
      );
    });

    test('it leans from its own pitch', () {
      for (final tap in gnossienne().taps.where((t) => t.hasGrace)) {
        final main = tap.notes.first.midi;
        final grace = tap.grace.first.midi;
        expect(
          tap.graceLean,
          main > grace ? 1 : -1,
          reason: 'the hand goes towards the note it lands on',
        );
      }
    });

    test('a run of short notes is not a string of ornaments', () {
      // What tells them apart is that an ornament leans into something that
      // stays. In a run everything is short, so nothing there is one.
      for (final song in shippedSongs) {
        for (final tap in Chart.build(song).taps.where((t) => t.hasGrace)) {
          expect(
            tap.duration * 60 / song.bpm,
            greaterThanOrEqualTo(Tap.graceMainSeconds),
            reason: '${song.title} at beat ${tap.beat}',
          );
        }
      }
    });

    test('the pieces without them are left alone', () {
      for (final id in ['canon-in-d', 'entertainer', 'prelude-in-c']) {
        expect(
          Chart.build(shipped(id)).taps.where((t) => t.hasGrace),
          isEmpty,
          reason: '$id has no acciaccatura in its edition',
        );
      }
    });
  });

  group('where the hands sit', () {
    final spread = songOf([
      note(0, 40, hand: Hand.left),
      note(0, 55, hand: Hand.left),
      note(1, 72),
      note(1, 84),
    ]);

    test('each hand keeps to its own side of the screen', () {
      final chart = Chart.build(spread, difficulty: Difficulty.hard);
      for (final tap in chart.taps) {
        if (tap.hand == Hand.left) {
          expect(tap.across, lessThan(0.5), reason: 'left of centre');
        } else {
          expect(tap.across, greaterThan(0.5), reason: 'right of centre');
        }
      }
    });

    test('a gap is left down the middle', () {
      final chart = Chart.build(spread, difficulty: Difficulty.hard);
      for (final tap in chart.taps) {
        expect(
          (tap.across - 0.5).abs(),
          greaterThan(0.04),
          reason: 'nothing should sit on the divide',
        );
      }
    });

    test('within a hand, higher notes sit further right', () {
      final chart = Chart.build(spread, difficulty: Difficulty.hard);
      final left = chart.taps.where((t) => t.hand == Hand.left).toList()
        ..sort((a, b) => a.notes.first.midi.compareTo(b.notes.first.midi));
      expect(left.first.across, lessThan(left.last.across));
    });

    test('on easy the notes use the whole width instead', () {
      // Separate moments, so nothing is merged and the extremes are visible.
      final chart = Chart.build(
        songOf([note(0, 40, hand: Hand.left), note(1, 84)]),
        difficulty: Difficulty.easy,
      );
      final places = chart.taps.map((t) => t.across).toList()..sort();
      expect(places.first, lessThan(0.15));
      expect(places.last, greaterThan(0.85));
      expect(
        places.last - places.first,
        greaterThan(0.7),
        reason: 'one zone, so the full width is used',
      );
    });

    test('notes stay on the screen', () {
      for (final difficulty in Difficulty.values) {
        for (final song in shippedSongs) {
          for (final tap in Chart.build(song, difficulty: difficulty).taps) {
            expect(tap.across, inInclusiveRange(0.0, 1.0));
          }
        }
      }
    });
  });

  group('where each note of a chord is drawn', () {
    final chord = songOf([
      note(0, 48, hand: Hand.left),
      note(0, 52, hand: Hand.left),
      note(0, 55, hand: Hand.left),
    ]);

    test('a touch knows a place for every note it carries', () {
      for (final difficulty in Difficulty.values) {
        for (final tap in Chart.build(chord, difficulty: difficulty).taps) {
          expect(
            tap.noteAcross,
            hasLength(tap.notes.length),
            reason: 'on ${difficulty.label}',
          );
        }
      }
    });

    test('a chord under one finger still spreads over three places', () {
      final chart = Chart.build(chord, difficulty: Difficulty.normal);
      final tap = chart.taps.single;
      expect(tap.notes, hasLength(3), reason: 'one touch');
      expect(
        tap.noteAcross.toSet(),
        hasLength(3),
        reason: 'but three notes to draw, at three pitches',
      );
      final sorted = [...tap.noteAcross]..sort();
      expect(
        sorted,
        tap.noteAcross,
        reason: 'in pitch order, like the notes themselves',
      );
    });

    test('the touch sits at the middle of the notes it carries', () {
      final tap = Chart.build(chord, difficulty: Difficulty.normal).taps.single;
      final average =
          tap.noteAcross.reduce((a, b) => a + b) / tap.noteAcross.length;
      expect(tap.across, closeTo(average, 0.0001));
    });

    test('a single note is drawn where it sounds', () {
      final tap = Chart.build(songOf([note(0, 60)])).taps.single;
      expect(tap.noteAcross, [tap.across]);
    });
  });

  group('how many notes are sounding', () {
    final chord = songOf([
      note(0, 60, hand: Hand.left),
      note(0, 64, hand: Hand.left),
      note(0, 67, hand: Hand.left),
      note(0, 84),
    ]);

    test('a hand counts only its own notes', () {
      final chart = Chart.build(chord, difficulty: Difficulty.hard);
      for (final tap in chart.taps) {
        expect(
          tap.voices,
          tap.hand == Hand.left ? 3 : 1,
          reason: 'the other hand should not inflate the count',
        );
      }
    });

    test('a chord is a chord however many fingers the level asks for', () {
      // The colour is read off this, so a three-note chord must count as
      // three whether it arrives under one finger or three.
      for (final difficulty in Difficulty.values) {
        final chart = Chart.build(chord, difficulty: difficulty);
        final left = chart.taps.where(
          (t) => t.notes.any((n) => n.hand == Hand.left),
        );
        expect(left.map((t) => t.voices).toSet(), {
          difficulty == Difficulty.easy ? 4 : 3,
        }, reason: 'on ${difficulty.label}');
      }
    });

    test('a single note is a single voice', () {
      expect(Chart.build(songOf([note(0, 60)])).taps.single.voices, 1);
    });
  });

  group('holds', () {
    test('a long note is held', () {
      final chart = Chart.build(songOf([note(0, 60, duration: 2)]));
      expect(chart.taps.single.isHold, isTrue);
    });

    test('a short one is struck', () {
      final chart = Chart.build(songOf([note(0, 60, duration: 0.5)]));
      expect(chart.taps.single.isHold, isFalse);
    });

    test('a held touch lasts as long as its longest note', () {
      final chart = Chart.build(
        songOf([note(0, 60, duration: 0.5), note(0, 64, duration: 2)]),
        difficulty: Difficulty.easy,
      );
      expect(chart.taps.single.endBeat, 2.0);
    });
  });

  group('easy thins what is too dense to answer', () {
    final run = songOf([for (var i = 0; i < 16; i++) note(i * 0.25, 60 + i)]);

    test('a wall of sixteenths becomes something playable', () {
      final easy = Chart.build(run, difficulty: Difficulty.easy);
      final normal = Chart.build(run, difficulty: Difficulty.normal);
      expect(easy.taps.length, lessThanOrEqualTo(normal.taps.length ~/ 2));
      for (var i = 1; i < easy.taps.length; i++) {
        expect(
          easy.taps[i].beat - easy.taps[i - 1].beat,
          greaterThanOrEqualTo(0.5 - 0.001),
        );
      }
    });

    test('and the rest is played, not dropped', () {
      final easy = Chart.build(run, difficulty: Difficulty.easy);
      expect(
        easy.taps.expand((t) => t.notes).length + easy.autoNotes.length,
        16,
      );
    });

    test('a sparse song is left alone', () {
      final sparse = songOf([note(0, 60), note(1, 62), note(2, 64)]);
      expect(
        Chart.build(sparse, difficulty: Difficulty.easy).taps,
        hasLength(3),
      );
    });
  });

  group('what is on screen', () {
    final chart = Chart.build(
      songOf([for (var i = 0; i < 20; i++) note(i.toDouble(), 60 + i)]),
    );

    test('only notes inside the look-ahead window are shown', () {
      expect(chart.visibleAt(0, 4).map((t) => t.beat), [0, 1, 2, 3, 4]);
    });

    test('a touch stays briefly after its moment, for a late hit', () {
      expect(chart.visibleAt(5.2, 4).first.beat, 5.0);
    });

    test('nothing is visible before the song starts or after it ends', () {
      expect(chart.visibleAt(-10, 4), isEmpty);
      expect(chart.visibleAt(500, 4), isEmpty);
    });

    test('taps stay in time order', () {
      for (final song in shippedSongs) {
        var previous = -1.0;
        for (final tap in Chart.build(song).taps) {
          expect(tap.beat, greaterThanOrEqualTo(previous));
          previous = tap.beat;
        }
      }
    });
  });

  group('runs, the passages too fast to tap', () {
    // A beat is half a second here, so a quarter of a beat is 125 ms — inside
    // the 150 ms that makes a run — and half a beat is 250 ms, outside it.
    List<Tap> runOf(Chart chart) =>
        chart.runs.isEmpty ? const [] : chart.runs.values.single;

    test('notes close together and going on long enough make one', () {
      final chart = Chart.build(
        songOf([for (var i = 0; i < 6; i++) note(i * 0.25, 60 + i)]),
        difficulty: Difficulty.normal,
      );
      expect(runOf(chart), hasLength(6));
      expect(chart.taps.map((t) => t.runIndex), [0, 1, 2, 3, 4, 5]);
    });

    test('a breath ends a run — there is no carrying over it', () {
      // A beat is half a second here, so 0.25 apart begins a run (125 ms) and
      // 0.5 apart does not (250 ms). Carrying a run across the wider gap was
      // tried and taken out again: the player, who can see the notes, said
      // the gap is real and the thread should not be drawn through it.
      final chart = Chart.build(
        songOf([
          for (var i = 0; i < 4; i++) note(i * 0.25, 60 + i),
          for (var i = 0; i < 4; i++) note(1.25 + i * 0.25, 64 + i),
        ]),
        difficulty: Difficulty.normal,
      );
      expect(chart.runs, hasLength(2), reason: 'two runs, not one');
    });

    test('a merely quick passage begins nothing', () {
      final chart = Chart.build(
        songOf([for (var i = 0; i < 12; i++) note(i * 0.5, 60 + i)]),
        difficulty: Difficulty.normal,
      );
      expect(chart.runs, isEmpty);
    });

    test('two are a flourish, not a run', () {
      final chart = Chart.build(
        songOf([note(0, 60), note(0.25, 62)]),
        difficulty: Difficulty.normal,
      );
      expect(chart.runs, isEmpty);
      expect(chart.taps.every((t) => t.runId == null), isTrue);
    });

    test('notes a hand can reach one at a time are left alone', () {
      final chart = Chart.build(
        songOf([for (var i = 0; i < 8; i++) note(i * 0.5, 60 + i)]),
        difficulty: Difficulty.normal,
      );
      expect(chart.runs, isEmpty);
    });

    test('it ends where the hurry ends', () {
      final chart = Chart.build(
        songOf([
          for (var i = 0; i < 6; i++) note(i * 0.25, 60 + i),
          note(6, 72), // well over a beat later: the hand has caught up
          note(7, 74),
        ]),
        difficulty: Difficulty.normal,
      );
      expect(runOf(chart).map((t) => t.beat), [0, 0.25, 0.5, 0.75, 1.0, 1.25]);
    });

    test('a chord is a moment, not a hurry', () {
      final chart = Chart.build(
        songOf([note(0, 60), note(0, 64), note(0, 67)]),
        difficulty: Difficulty.hard, // a touch per note, all at once
      );
      expect(chart.taps, hasLength(3));
      expect(chart.runs, isEmpty, reason: 'three fingers, one moment');
    });

    test('the other hand does not break it', () {
      final chart = Chart.build(
        songOf([
          for (var i = 0; i < 6; i++) note(i * 0.25, 72 + i),
          note(0.3, 48, hand: Hand.left),
          note(0.6, 50, hand: Hand.left),
        ]),
        difficulty: Difficulty.normal,
      );
      expect(
        runOf(chart),
        hasLength(6),
        reason:
            'a left-hand note landing inside a right-hand run is not '
            'part of it and does not interrupt it',
      );
    });

    test('the pieces that prompted this have them', () {
      // The rondo's coda and the nocturne's cadenza are what a hand cannot
      // do; if these ever come back empty the mechanic has quietly died.
      for (final song in [shipped('fur-elise'), shipped('nocturne-op9-no2')]) {
        final chart = Chart.build(song, difficulty: Difficulty.normal);
        expect(chart.runs, isNotEmpty, reason: song.title);
        final longest = chart.runs.values
            .map((r) => r.length)
            .reduce((a, b) => a > b ? a : b);
        expect(longest, greaterThanOrEqualTo(10), reason: song.title);
      }
    });

    test('a run takes in the note on each side of it', () {
      // The canon's semiquaver variations are built as one ordinary note,
      // three too fast to tap, one ordinary note, over and over. Read
      // strictly that asks the hand to tap, then slide, then tap again every
      // quarter of a second, and the player said it cannot be done at speed.
      final song = shipped('canon-in-d');
      final bps = song.bpm / 60;
      final chart = Chart.build(song);
      final run = chart.runs.values.firstWhere(
        (r) => r.first.beat / bps > 148 && r.first.beat / bps < 149,
      );
      expect(run, hasLength(5), reason: 'three, with a shoulder either side');

      // The shoulders are the neighbours, not notes invented for the run.
      final taps = chart.taps.where((t) => t.hand == run.first.hand).toList();
      final before = taps[taps.indexOf(run.first) - 1];
      expect(
        (run.first.beat - before.beat) / bps,
        greaterThan(0.15),
        reason: 'the note before the run is an ordinary one',
      );
    });

    test('and only one the hand can hold along with the run', () {
      // A shoulder is played by the finger that is on the run, so it has to
      // be within that finger's reach of it. The canon had a group whose
      // neighbour is an octave below: the player pressed it, heard it, held
      // still, and the rest of the run said nothing.
      //
      // A shoulder is the gap the run itself could not have made — anything
      // wider than [Chart.runGapSeconds], which only the two ends can be.
      for (final song in shippedSongs) {
        final secondsPerBeat = 60 / song.bpm;
        for (final run in Chart.build(song).runs.values) {
          double gapAfter(int i) =>
              (run[i + 1].beat - run[i].beat) * secondsPerBeat;

          if (gapAfter(0) > Chart.runGapSeconds) {
            expect(
              (run[1].across - run.first.across).abs(),
              lessThanOrEqualTo(Chart.dragReach + 1e-9),
              reason: '${song.title}: a shoulder out of reach of its own run',
            );
          }
          final last = run.length - 1;
          if (gapAfter(last - 1) > Chart.runGapSeconds) {
            expect(
              (run[last].across - run[last - 1].across).abs(),
              lessThanOrEqualTo(Chart.dragReach + 1e-9),
              reason: '${song.title}: a shoulder out of reach of its own run',
            );
          }
        }
      }
    });

    test('but it never reaches past the note beside it', () {
      // One on each side and no further: widening the run gap itself was
      // tried and sent back, because carrying the thread over every breath
      // turned ten bars of the canon into two runs of eighty and a hundred.
      final chart = Chart.build(shipped('canon-in-d'));
      final longest = chart.runs.values
          .map((r) => r.length)
          .reduce((a, b) => a > b ? a : b);
      expect(longest, lessThan(20), reason: 'not one run to a page');
    });

    test('every run is in time order and long enough to be one', () {
      for (final song in shippedSongs) {
        final secondsPerBeat = 60 / song.bpm;
        for (final run in Chart.build(song).runs.values) {
          expect(run.length, greaterThanOrEqualTo(Chart.runLength));
          final gaps = [
            for (var i = 1; i < run.length; i++)
              (run[i].beat - run[i - 1].beat) * secondsPerBeat,
          ];
          // Inside, a run is at a pace nobody can tap one at a time. A run
          // also takes in the note on each side of it, so the first and last
          // gaps — and only those — may be wider, and only as far as
          // [Chart.runShoulderSpacings] of the run's own closest spacing.
          final wide = [
            for (var i = 0; i < gaps.length; i++)
              if (gaps[i] > Chart.runGapSeconds + 1e-9) i,
          ];
          for (final i in wide) {
            expect(
              i == 0 || i == gaps.length - 1,
              isTrue,
              reason: '${song.title}: a run reaching over a real gap',
            );
          }
          final pace = [
            for (final gap in gaps)
              if (gap <= Chart.runGapSeconds + 1e-9) gap,
          ].reduce((a, b) => a < b ? a : b);
          for (final i in wide) {
            expect(
              gaps[i],
              lessThanOrEqualTo(pace * Chart.runShoulderSpacings + 1e-9),
              reason: '${song.title}: a shoulder reaching too far',
            );
          }
          for (var i = 1; i < run.length; i++) {
            expect(run[i].beat, greaterThan(run[i - 1].beat));
            expect(run[i].hand, run[i - 1].hand);
            expect(run[i].runIndex, i);
          }
        }
      }
    });
  });

  group('figures, the stretches too relentless to enjoy tapping', () {
    test('the rondo is built out of them', () {
      // "Arka arkaya gelen hızlı notalara sürekli basmaya çalışmak oyun
      // zevkini ciddi azaltıyor" — said of this piece and of the Entertainer,
      // whose notes are the same fifth of a second apart.
      final chart = Chart.build(shipped('fur-elise'));
      expect(chart.figures, hasLength(greaterThan(10)));
      final inFigures = chart.taps.where((t) => t.figureId != null).length;
      expect(inFigures, greaterThan(chart.taps.length ~/ 4));
    });

    test('but a short flurry is not one', () {
      // Four notes was the first line and it caught the rondo's four-note
      // groups, which are a breath apart and perfectly tappable: *"bizim
      // amacımız bir el çok defa arka arkaya tıklama yapıyorsa bu mekaniği
      // eklemekti."* What tires a hand is being kept at it, so the line is a
      // length of time.
      for (final song in shippedSongs) {
        final secondsPerBeat = 60 / song.bpm;
        for (final d in Difficulty.values) {
          final chart = Chart.build(song, difficulty: d);
          for (final entry in chart.figures.entries) {
            final steps = entry.value;
            final caught = chart.taps.singleWhere(
              (t) => t.figureId == entry.key && t.figureStep == -1,
            );
            final seconds =
                (steps.last.taps.last.beat - caught.beat) * secondsPerBeat;
            expect(
              seconds,
              greaterThanOrEqualTo(Chart.figureLeastSeconds),
              reason: '${song.title}/${d.name} at ${caught.beat}',
            );
          }
        }
      }
    });

    test('and the unhurried pieces have none', () {
      for (final id in ['ode-to-joy', 'gnossienne-1', 'prelude-in-c']) {
        expect(Chart.build(shipped(id)).figures, isEmpty, reason: id);
      }
    });

    test('a figure is entered by tapping its first note', () {
      for (final song in shippedSongs) {
        final chart = Chart.build(song);
        for (final entry in chart.figures.entries) {
          final caught = chart.taps.where(
            (t) => t.figureId == entry.key && t.figureStep == -1,
          );
          expect(caught, hasLength(1), reason: '${song.title}: one way in');
          expect(
            caught.single.beat,
            lessThan(entry.value.first.taps.first.beat),
            reason: '${song.title}: and it comes first',
          );
        }
      }
    });

    test('and answered a movement at a time, never one note', () {
      // A movement for a single note is a gesture that saves nothing.
      for (final song in shippedSongs) {
        for (final d in Difficulty.values) {
          for (final steps
              in Chart.build(song, difficulty: d).figures.values) {
            for (final step in steps) {
              expect(
                step.taps.length,
                greaterThanOrEqualTo(2),
                reason: '${song.title}/${d.name}',
              );
            }
          }
        }
      }
    });

    test('and never asked for the same direction twice running', () {
      // Asking a hand already travelling left to go left again is asking it
      // to keep going, and the player said exactly that: *"şu anda
      // sürüklemeye devam etmem gerekiyor gibi."* Every movement points
      // somewhere the hand is not already going.
      for (final song in shippedSongs) {
        for (final d in Difficulty.values) {
          for (final steps
              in Chart.build(song, difficulty: d).figures.values) {
            for (var i = 1; i < steps.length; i++) {
              expect(
                steps[i].direction,
                isNot(steps[i - 1].direction),
                reason: '${song.title}/${d.name}: movement $i',
              );
            }
          }
        }
      }
    });

    test('a movement is worth about a second of music', () {
      // Not a number of notes: three notes is a different length of time in
      // every passage, and in the Rondo it was a third of a second — three
      // movements, three directions, inside one second. Seconds, not notes.
      for (final song in shippedSongs) {
        final secondsPerBeat = 60 / song.bpm;
        for (final steps in Chart.build(song).figures.values) {
          for (var i = 0; i < steps.length; i++) {
            final taps = steps[i].taps;
            final from = i == 0 ? taps.first.beat : steps[i - 1].taps.last.beat;
            final seconds = (taps.last.beat - from) * secondsPerBeat;
            expect(
              seconds,
              greaterThan(0.3),
              reason: '${song.title}: movement $i comes too soon after the last',
            );
          }
        }
      }
    });

    test('the mark goes on the note the hand is on, not the one it plays', () {
      // *"Hangi nota hangi yön hepsi karışıyor."* A movement is made *from*
      // somewhere: the touch that catches the figure for the first one, the
      // last note of the movement before for the rest.
      for (final song in shippedSongs) {
        final chart = Chart.build(song);
        final marked = <Tap>{};
        for (final entry in chart.figures.entries) {
          final steps = entry.value;
          final caught = chart.taps.singleWhere(
            (t) => t.figureId == entry.key && t.figureStep == -1,
          );
          expect(steps.first.from, same(caught), reason: song.title);
          for (var i = 1; i < steps.length; i++) {
            expect(steps[i].from, same(steps[i - 1].taps.last));
          }
          for (final step in steps) {
            expect(step.from.figureTurn, step.direction, reason: song.title);
            marked.add(step.from);
          }
        }
        // And nothing else carries one.
        for (final tap in chart.taps) {
          if (marked.contains(tap)) continue;
          expect(tap.figureTurn, isNull, reason: '${song.title} at ${tap.beat}');
        }
      }
    });

    test('a note is never both a run and a figure', () {
      // Two mechanics on one note is one too many: a run cannot be tapped at
      // all and has its own answer.
      for (final song in shippedSongs) {
        for (final tap in Chart.build(song).taps) {
          expect(
            tap.runId != null && tap.figureId != null,
            isFalse,
            reason: '${song.title}: the note at ${tap.beat}',
          );
        }
      }
    });

    test('every step says which way the hand goes', () {
      final chart = Chart.build(shipped('fur-elise'));
      final opening = chart.figures.values.first;
      // The Rondo turns on two notes and then falls away: a first movement
      // to the left, and — because the music is still falling and the hand
      // is already going that way — a second one out of the other axis.
      expect(opening.map((s) => s.direction).toList(), [Swipe.left, Swipe.up]);
      expect(opening.map((s) => s.taps.length).toList(), [5, 3]);
    });

    test('and music that stays where it is asks for the other axis', () {
      // There is no way to point at a passage that turns on itself, so the
      // hand is asked up or down instead. Both still happen in the library.
      final directions = <Swipe>{};
      for (final song in shippedSongs) {
        for (final d in Difficulty.values) {
          for (final steps in Chart.build(song, difficulty: d).figures.values) {
            directions.addAll(steps.map((s) => s.direction));
          }
        }
      }
      expect(directions, containsAll([Swipe.up, Swipe.down]));
    });
  });

  group('what counts as a note to hold', () {
    test('it is a length of time, not a number of beats', () {
      // The same written note, in two pieces at different tempos. A hand
      // knows seconds; it does not know beats.
      Tap only(double bpm) => Chart.build(
        songOf([note(0, 60, duration: 1.2)], bpm: bpm),
        difficulty: Difficulty.normal,
      ).taps.single;

      expect(only(40).isHold, isTrue, reason: '1.2 beats at 40 is 1.8 s');
      expect(only(200).isHold, isFalse, reason: '1.2 beats at 200 is 0.36 s');
    });

    test("the canon's walking bass is held, because that is how it sounds", () {
      // Reported by the player: the opening notes sound held but were drawn
      // as taps. They are quarter notes at 55 — 1.09 seconds each — and the
      // threshold used to be 1.25 beats, which in this piece is 1.36
      // seconds. Nothing in the bass reached it.
      final chart = Chart.build(shipped('canon-in-d'));
      final opening = chart.taps.take(8);
      expect(
        opening.every((tap) => tap.isHold),
        isTrue,
        reason: 'the ground bass rings for a second a note',
      );
    });

    test('nothing quick is ever asked to be held', () {
      for (final song in shippedSongs) {
        final secondsPerBeat = 60 / song.bpm;
        for (final tap in Chart.build(song).taps.where((t) => t.isHold)) {
          expect(
            tap.duration * secondsPerBeat,
            greaterThanOrEqualTo(Tap.holdSeconds - 1e-9),
            reason:
                '${song.title}: a hold of '
                '${(tap.duration * secondsPerBeat * 1000).round()} ms',
          );
        }
      }
    });
  });

  group('notes a hand has to leave', () {
    test('the other hand does not force a hand to let go', () {
      final chart = Chart.build(
        songOf([
          note(0, 72, duration: 4),
          note(1, 48, duration: 0.5, hand: Hand.left),
        ]),
        difficulty: Difficulty.normal,
      );
      expect(
        chart.taps.first.sustains,
        isFalse,
        reason: 'the left hand has its own finger',
      );
    });

    test('notes struck together do not', () {
      final chart = Chart.build(
        songOf([note(0, 72, duration: 4), note(0, 76, duration: 4)]),
        difficulty: Difficulty.hard, // a touch per note, at the same moment
      );
      expect(chart.taps.every((t) => t.sustains), isFalse);
    });

    test('the pieces that prompted this are full of them', () {
      // Reported by the player: Bach's left hand and both of Satie's.
      for (final id in ['prelude-in-c', 'gnossienne-1']) {
        final chart = Chart.build(shipped(id));
        final holds = chart.taps.where((t) => t.isHold);
        final sustained = holds.where((t) => t.sustains);
        expect(
          sustained.length,
          greaterThan(holds.length ~/ 3),
          reason: '$id: ${sustained.length} of ${holds.length}',
        );
      }
    });
  });

  test('which hand a touch belongs to is read from where it landed', () {
    expect(Chart.handAt(0.1), Hand.left);
    expect(Chart.handAt(0.49), Hand.left);
    expect(Chart.handAt(0.51), Hand.right);
    expect(Chart.handAt(0.9), Hand.right);
  });

  test('the accompaniment can be read back for a stretch of the song', () {
    final chart = Chart.build(
      songOf([for (var i = 0; i < 8; i++) note(i * 0.25, 60 + i)]),
      difficulty: Difficulty.easy,
    );
    expect(chart.accompanimentBetween(0, 1), isNotEmpty);
    expect(chart.accompanimentBetween(100, 200), isEmpty);
  });
}
