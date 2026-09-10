import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piano_flow/game/chart.dart';
import 'package:piano_flow/music/song.dart';
import 'package:piano_flow/game/stage_geometry.dart';
import 'package:piano_flow/music/note.dart';
import 'package:piano_flow/render/stage_painter.dart';
import 'package:piano_flow/theme/app_theme.dart';

import 'support/library.dart';

const Size phone = Size(390, 844);
const Size phoneLandscape = Size(844, 390);

/// Paint one frame straight onto a canvas — no widget tree, no clock.
ui.Picture paintFrame(Song song, double beat,
    {double window = 4,
    Map<Hand, double> litHands = const {},
    Size size = phone,
    Set<(double, int)> heldNotes = const {},
    Difficulty difficulty = Difficulty.normal}) {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Offset.zero & size);
  StagePainter(
    chart: Chart.build(song, difficulty: difficulty),
    beat: beat,
    windowInBeats: window,
    litHands: litHands,
    heldNotes: heldNotes,
  ).paint(canvas, size);
  return recorder.endRecording();
}

/// Save a frame as a PNG under build/screens, so the playfield can actually be
/// looked at. There is no device here to look at it on, so it is rendered to
/// file the same way the synthesiser is rendered to WAV.
Future<int> savePng(Song song, double beat, String name,
    {Map<Hand, double> litHands = const {},
    Size size = phone,
    Set<(double, int)> heldNotes = const {},
    Difficulty difficulty = Difficulty.normal}) async {
  final picture = paintFrame(song, beat,
      litHands: litHands,
      size: size,
      heldNotes: heldNotes,
      difficulty: difficulty);
  final image = await picture.toImage(size.width.toInt(), size.height.toInt());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File('build/screens/$name.png');
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(bytes!.buffer.asUint8List());
  return file.lengthSync();
}

/// Every note of the moment at [beat], as the session would report it while
/// a finger was on them.
Set<(double, int)> heldAt(Song song, double beat) => {
      for (final note in song.notes)
        if ((note.beat - beat).abs() < 0.01) (note.beat, note.midi),
    };

void main() {
  test('a long note only waits at the line if it is being held', () {
    final song = shipped('ode-to-joy');
    // Well past the line, so a pinned head and a falling one differ.
    expect(
        () => paintFrame(song, 7.6, heldNotes: heldAt(song, 6.0)),
        returnsNormally);
    expect(() => paintFrame(song, 7.6), returnsNormally);
  });

  test('each chord size has its own colour', () {
    // Colour says how many fingers a moment needs; two sizes sharing one
    // colour would make that unreadable.
    final colours = [for (var n = 1; n <= 4; n++) AppTheme.chordColor(n).toARGB32()];
    expect(colours.toSet(), hasLength(4));
  });

  test('bigger chords than the palette still get a colour', () {
    expect(AppTheme.chordColor(9), AppTheme.chordColor(4));
    expect(AppTheme.chordColor(0), AppTheme.chordColor(1),
        reason: 'never off the end of the palette');
  });

  test('notes stay clear of each other on a short screen', () {
    const landscape = StageGeometry(size: phoneLandscape);
    // A note must not be so large that consecutive ones overlap vertically.
    expect(landscape.noteRadius * 2, lessThan(phoneLandscape.height * 0.15));
  });

  test('the playfield paints in landscape too', () {
    expect(
        () => paintFrame(shipped('ode-to-joy'), 6, size: phoneLandscape),
        returnsNormally);
  });

  test('a held note stays on screen until its end reaches the line', () {
    // Its head crosses the line the moment it starts; the finger is meant to
    // stay down until the end does, so it must not vanish in between.
    final chart = Chart.build(
      Song(
        id: 'held',
        title: 'Held',
        composer: '',
        bpm: 120,
        notes: [Note(beat: 0, midi: 60, duration: 3)],
      ),
      difficulty: Difficulty.normal,
    );
    expect(chart.taps.single.isHold, isTrue);

    // A beat and a half in: the head is well past the line, the tail is not.
    expect(chart.visibleAt(1.5, 4), isNotEmpty,
        reason: 'the note is still being held');
    // Past its end, it should be gone.
    expect(chart.visibleAt(4.0, 4), isEmpty);
  });

  test('a chord band never crosses the divide between the hands', () {
    // Both hands playing chords at once: the two bands must stay on their own
    // sides, which is what grouping by hand as well as by moment guarantees.
    final chart = Chart.build(shipped('ode-to-joy'), difficulty: Difficulty.hard);
    final moments = <double, List<Tap>>{};
    for (final tap in chart.taps) {
      (moments[tap.beat] ??= []).add(tap);
    }
    for (final group in moments.values) {
      for (final hand in Hand.values) {
        final ofHand = group.where((t) => t.hand == hand);
        if (ofHand.isEmpty) continue;
        final low = ofHand.map((t) => t.across).reduce((a, b) => a < b ? a : b);
        final high = ofHand.map((t) => t.across).reduce((a, b) => a > b ? a : b);
        expect(hand == Hand.left ? high < 0.5 : low > 0.5, isTrue,
            reason: 'a band would cross the middle');
      }
    }
  });

  test('no note is drawn off the edge of the screen', () {
    for (final size in [phone, phoneLandscape, const Size(320, 568)]) {
      final g = StageGeometry(size: size);
      final radius = g.noteRadius;
      for (final difficulty in Difficulty.values) {
        for (final song in shippedSongs) {
          for (final tap in Chart.build(song, difficulty: difficulty).taps) {
            final x = g.xAtPosition(tap.across);
            expect(x - radius, greaterThanOrEqualTo(0),
                reason: '${song.title} clipped on the left at $size');
            expect(x + radius, lessThanOrEqualTo(size.width),
                reason: '${song.title} clipped on the right at $size');
          }
        }
      }
    }
  });

  test('the hand divide is drawn only when the hands are separated', () {
    // Not an appearance test so much as a promise: the line must never be
    // there on easy, where a touch on either side counts for anything.
    expect(
        () => paintFrame(shipped('ode-to-joy'), 5, difficulty: Difficulty.easy),
        returnsNormally);
    expect(
        () => paintFrame(shipped('ode-to-joy'), 5, difficulty: Difficulty.hard),
        returnsNormally);
  });

  test('a beam lit by a hit still paints', () {
    expect(() => paintFrame(shipped('ode-to-joy'), 6.0, litHands: {Hand.left: 1.0, Hand.right: 0.2}),
        returnsNormally);
  });

  test('painting a frame does not throw', () {
    for (final song in shippedSongs) {
      for (final beat in [-2.0, 0.0, 3.5, 12.0, 1000.0]) {
        expect(() => paintFrame(song, beat), returnsNormally,
            reason: '${song.title} at beat $beat');
      }
    }
  });

  test('a run is threaded, so the slide is something the player can see', () {
    // The ribbon is the only thing on screen that says these notes are not
    // to be tapped one at a time. Drawn with it and without it, the two
    // frames have to differ — otherwise the mechanic is invisible.
    final withRun = paintFrame(shipped('fur-elise'), 156.0);
    final withoutRun = paintFrame(shipped('prelude-in-c'), 5.0);
    expect(withRun.approximateBytesUsed,
        isNot(withoutRun.approximateBytesUsed));
    final chart = Chart.build(shipped('fur-elise'));
    final onScreen = chart
        .visibleAt(156.0, 4)
        .where((t) => t.runId != null)
        .length;
    expect(onScreen, greaterThan(3), reason: 'nothing to thread');
  });

  test('an empty window still paints the stage', () {
    // Before the first note there is nothing to draw but beams and the line;
    // that must still be a picture, not a blank screen.
    expect(() => paintFrame(shipped('fur-elise'), -50), returnsNormally);
  });

  test('renders the playfield to PNG', () async {
    final sizes = <String, int>{
      'fur-elise-giris': await savePng(shipped('fur-elise'), 0.5, 'fur-elise-giris'),
      'fur-elise-akis': await savePng(shipped('fur-elise'), 7.0, 'fur-elise-akis'),
      'ode-to-joy': await savePng(shipped('ode-to-joy'), 6.0, 'ode-to-joy'),
      'prelude-in-c': await savePng(shipped('prelude-in-c'), 5.0, 'prelude-in-c'),
      // A beam still glowing from a hit a moment ago.
      'vurus-ani': await savePng(shipped('ode-to-joy'), 6.05, 'vurus-ani',
          litHands: {Hand.right: 0.8}),
      // Chords: colour by finger count, with a band tying each one together.
      'akorlar': await savePng(shipped('ode-to-joy'), 5.0, 'akorlar'),
      'eller-ayri': await savePng(shipped('prelude-in-c'), 5.0, 'eller-ayri'),
      // One finger, three notes: the pips have to say so.
      'kolay-akor': await savePng(shipped('ode-to-joy'), 5.0, 'kolay-akor',
          difficulty: Difficulty.easy),
      // The same held note, caught and not caught. Caught, it waits on the
      // line with its bar shortening above it; missed, it falls past and
      // goes, tail and all.
      'tutma-basili': await savePng(shipped('ode-to-joy'), 6.6, 'tutma-basili',
          heldNotes: heldAt(shipped('ode-to-joy'), 6.0)),
      'tutma-basilmadi': await savePng(
          shipped('ode-to-joy'), 6.6, 'tutma-basilmadi'),
      'zor-parmaklama': await savePng(
          shipped('ode-to-joy'), 5.0, 'zor-parmaklama',
          difficulty: Difficulty.hard),
      'akorlar-yatay': await savePng(
          shipped('ode-to-joy'), 5.0, 'akorlar-yatay',
          size: phoneLandscape),
      // Sideways: more beams, so the hands can divide the keyboard.
      'yatay-ode-to-joy': await savePng(
          shipped('ode-to-joy'), 6.0, 'yatay-ode-to-joy',
          size: phoneLandscape),
      'yatay-prelude': await savePng(
          shipped('prelude-in-c'), 5.0, 'yatay-prelude',
          size: phoneLandscape),
      // A run: the rondo's chromatic descent, sixty-two notes no hand can
      // tap, with the ribbon threading them into one slide.
      'hizli-akis': await savePng(shipped('fur-elise'), 156.0, 'hizli-akis'),
      'kanon': await savePng(shipped('canon-in-d'), 103.0, 'kanon'),
    };
    for (final entry in sizes.entries) {
      // A stage drawn with nothing on it compresses to almost nothing.
      expect(entry.value, greaterThan(10000), reason: '${entry.key} looks blank');
    }
  });
}
