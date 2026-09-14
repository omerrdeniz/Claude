import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piano_flow/game/chart.dart';
import 'package:piano_flow/music/song.dart';
import 'package:piano_flow/game/stage_geometry.dart';
import 'package:piano_flow/music/note.dart';
import 'package:piano_flow/game/play_session.dart' show RunBead;
import 'package:piano_flow/render/hit_sparks.dart';
import 'package:piano_flow/render/stage_painter.dart';
import 'package:piano_flow/theme/app_theme.dart';
import 'package:piano_flow/theme/song_ground.dart';

import 'support/library.dart';

const Size phone = Size(390, 844);
const Size phoneLandscape = Size(844, 390);

/// Paint one frame straight onto a canvas — no widget tree, no clock.
ui.Picture paintFrame(
  Song song,
  double beat, {
  double window = 4,
  Map<Hand, double> litHands = const {},
  Size size = phone,
  Set<(double, int)> heldNotes = const {},
  List<RunBead> runBeads = const [],
  List<Spark> sparks = const [],
  double heat = 0,
  Ground ground = AppTheme.defaultGround,
  Difficulty difficulty = Difficulty.normal,
}) {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Offset.zero & size);
  StagePainter(
    chart: Chart.build(song, difficulty: difficulty),
    beat: beat,
    windowInBeats: window,
    litHands: litHands,
    heldNotes: heldNotes,
    runBeads: runBeads,
    sparks: sparks,
    heat: heat,
    ground: ground,
  ).paint(canvas, size);
  return recorder.endRecording();
}

/// Save a frame as a PNG under build/screens, so the playfield can actually be
/// looked at. There is no device here to look at it on, so it is rendered to
/// file the same way the synthesiser is rendered to WAV.
Future<int> savePng(
  Song song,
  double beat,
  String name, {
  Map<Hand, double> litHands = const {},
  Size size = phone,
  Set<(double, int)> heldNotes = const {},
  List<RunBead> runBeads = const [],
  List<Spark> sparks = const [],
  double heat = 0,
  Ground ground = AppTheme.defaultGround,
  Difficulty difficulty = Difficulty.normal,
}) async {
  final picture = paintFrame(
    song,
    beat,
    litHands: litHands,
    size: size,
    heldNotes: heldNotes,
    runBeads: runBeads,
    sparks: sparks,
    heat: heat,
    ground: ground,
    difficulty: difficulty,
  );
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

/// The bead a run is on at [beat], as the session would report it.
RunBead beadOf(Song song, double beat, {required bool tracked}) {
  final chart = Chart.build(song);
  final entry = chart.runs.entries.firstWhere(
    (e) => beat >= e.value.first.beat && beat <= e.value.last.beat,
  );
  final run = entry.value;
  final at = run.lastWhere((tap) => tap.beat <= beat, orElse: () => run.first);
  return RunBead(
    runId: entry.key,
    hand: at.hand,
    across: at.across,
    tracked: tracked,
  );
}

/// A canvas that only remembers where things were drawn.
///
/// There is no way to look inside a finished [ui.Picture], and this test needs
/// to know one thing that cannot be seen from outside: whether a chord's
/// sparks come out at the same places as the chord's notes. Everything the
/// painter draws with is void, so recording it is a matter of catching the
/// calls — plus the translate the note heads are drawn through, since they are
/// baked around the origin and moved into place.
class _Recorder implements Canvas {
  final List<Offset> circles = [];
  final List<Rect> rects = [];
  Offset _shift = Offset.zero;
  final List<Offset> _saved = [];

  @override
  void save() => _saved.add(_shift);

  @override
  void restore() => _shift = _saved.isEmpty ? Offset.zero : _saved.removeLast();

  @override
  void translate(double dx, double dy) => _shift += Offset(dx, dy);

  @override
  void drawCircle(Offset c, double radius, Paint paint) =>
      circles.add(c + _shift);

  final List<double> lines = [];

  /// The colour each of [rects] was painted with, in the same order. Only
  /// plain paints say anything here — a shader's paint reports black — which
  /// is enough for the marks that are drawn in one flat colour.
  final List<Color> rectColours = [];

  /// And whether that was a fill or an outline: most shapes are drawn twice,
  /// a body and then a rim over it.
  final List<PaintingStyle> rectStyles = [];

  /// And whether it was painted with a gradient, which is what tells the
  /// notes and the light they throw from the flat marks drawn over them.
  final List<bool> rectShaded = [];

  @override
  void drawRRect(RRect rrect, Paint paint) {
    rects.add(rrect.outerRect.shift(_shift));
    rectColours.add(paint.color);
    rectStyles.add(paint.style);
    rectShaded.add(paint.shader != null);
  }

  @override
  void drawLine(Offset from, Offset to, Paint paint) {
    // The bar lines: level, and hairline. The divide between the hands is
    // upright; the hit line is level too but drawn twice as thick, and a bar
    // line is allowed to land exactly on it, so thickness is what tells them
    // apart rather than height.
    if ((from.dy - to.dy).abs() < 0.01 && paint.strokeWidth < 1.5) {
      lines.add(from.dy + _shift.dy);
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  test('a long note only waits at the line if it is being held', () {
    final song = shipped('ode-to-joy');
    // Well past the line, so a pinned head and a falling one differ.
    expect(
      () => paintFrame(song, 7.6, heldNotes: heldAt(song, 6.0)),
      returnsNormally,
    );
    expect(() => paintFrame(song, 7.6), returnsNormally);
  });

  test('notes stay clear of each other on a short screen', () {
    const landscape = StageGeometry(size: phoneLandscape);
    // A note must not be so large that consecutive ones overlap vertically.
    expect(landscape.noteRadius * 2, lessThan(phoneLandscape.height * 0.15));
  });

  test('the playfield paints in landscape too', () {
    expect(
      () => paintFrame(shipped('ode-to-joy'), 6, size: phoneLandscape),
      returnsNormally,
    );
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
    expect(
      chart.visibleAt(1.5, 4),
      isNotEmpty,
      reason: 'the note is still being held',
    );
    // Past its end, it should be gone.
    expect(chart.visibleAt(4.0, 4), isEmpty);
  });

  test('a chord band never crosses the divide between the hands', () {
    // Both hands playing chords at once: the two bands must stay on their own
    // sides, which is what grouping by hand as well as by moment guarantees.
    final chart = Chart.build(
      shipped('ode-to-joy'),
      difficulty: Difficulty.hard,
    );
    final moments = <double, List<Tap>>{};
    for (final tap in chart.taps) {
      (moments[tap.beat] ??= []).add(tap);
    }
    for (final group in moments.values) {
      for (final hand in Hand.values) {
        final ofHand = group.where((t) => t.hand == hand);
        if (ofHand.isEmpty) continue;
        final low = ofHand.map((t) => t.across).reduce((a, b) => a < b ? a : b);
        final high = ofHand
            .map((t) => t.across)
            .reduce((a, b) => a > b ? a : b);
        expect(
          hand == Hand.left ? high < 0.5 : low > 0.5,
          isTrue,
          reason: 'a band would cross the middle',
        );
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
            expect(
              x - radius,
              greaterThanOrEqualTo(0),
              reason: '${song.title} clipped on the left at $size',
            );
            expect(
              x + radius,
              lessThanOrEqualTo(size.width),
              reason: '${song.title} clipped on the right at $size',
            );
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
      returnsNormally,
    );
    expect(
      () => paintFrame(shipped('ode-to-joy'), 5, difficulty: Difficulty.hard),
      returnsNormally,
    );
  });

  test('a beam lit by a hit still paints', () {
    expect(
      () => paintFrame(
        shipped('ode-to-joy'),
        6.0,
        litHands: {Hand.left: 1.0, Hand.right: 0.2},
      ),
      returnsNormally,
    );
  });

  test('painting a frame does not throw', () {
    for (final song in shippedSongs) {
      for (final beat in [-2.0, 0.0, 3.5, 12.0, 1000.0]) {
        expect(
          () => paintFrame(song, beat),
          returnsNormally,
          reason: '${song.title} at beat $beat',
        );
      }
    }
  });

  test('a run is threaded, so the slide is something the player can see', () {
    // The ribbon is the only thing on screen that says these notes are not
    // to be tapped one at a time. Drawn with it and without it, the two
    // frames have to differ — otherwise the mechanic is invisible.
    final withRun = paintFrame(shipped('fur-elise'), 156.0);
    final withoutRun = paintFrame(shipped('prelude-in-c'), 5.0);
    expect(
      withRun.approximateBytesUsed,
      isNot(withoutRun.approximateBytesUsed),
    );
    final chart = Chart.build(shipped('fur-elise'));
    final onScreen = chart
        .visibleAt(156.0, 4)
        .where((t) => t.runId != null)
        .length;
    expect(onScreen, greaterThan(3), reason: 'nothing to thread');
  });

  test("a chord's sparks land on its notes, not beside them", () {
    // The bug the player saw: sparks were spawned at the positions the chart
    // gives a chord's notes, but the painter opens a chord out before drawing
    // it so its notes do not overlap. On a single note the two agree; on a
    // chord the light stood beside the notes it came from.
    //
    // A chord of its own rather than one found in the library: three notes a
    // semitone apart are certainly tight enough to be opened out, and with
    // nothing else in the piece nothing else is near the line to be mistaken
    // for a note or a spark.
    const g = StageGeometry(size: phone);
    final song = Song(
      id: 't',
      title: 'T',
      composer: '',
      bpm: 120,
      notes: [
        for (final midi in [72, 73, 74])
          Note(beat: 4, midi: midi, duration: 0.5, hand: Hand.right),
      ],
    );
    final chart = Chart.build(song);
    final tap = chart.taps.single;
    expect(tap.notes, hasLength(3));

    final recorder = _Recorder();
    StagePainter(
      chart: chart,
      // Half a beat early, so the notes are still above the line and the
      // spark is on it: the two are then told apart by height alone.
      beat: tap.beat - 0.5,
      windowInBeats: 4,
      sparks: [
        Spark(
          places: tap.noteAcross,
          midis: [for (final note in tap.notes) note.midi],
          hand: tap.hand,
          quality: 1,
        )..age = 0.2,
      ],
    ).paint(recorder, phone);

    final line = g.hitLineY;
    final plumes = {
      for (final rect in recorder.rects)
        if (rect.top >= line - 0.5) rect.center.dx,
    }.toList()..sort();
    expect(plumes, hasLength(tap.notes.length));

    // The notes of that chord: bars still on their way down.
    final heads = {
      for (final rect in recorder.rects)
        if (rect.bottom < line - 1) rect.center.dx,
    };
    expect(heads, hasLength(tap.notes.length));

    for (final plume in plumes) {
      expect(
        heads.any((head) => (head - plume).abs() < 0.5),
        isTrue,
        reason: 'a spark at $plume has no note above it',
      );
    }
  });

  test('a short stay is the same stay on every screen', () {
    // The player asked for the cut at three tenths of a second, was given it
    // on a 390x844 screen, and then could not find the notes: in a browser
    // the toolbars take a hundred points off the height, the hit line comes
    // up with them, and the rule — measured in pixels — quietly became a
    // third of a second instead. Gnossienne's fourteen sit at 0.300 exactly,
    // so they fell either side of it depending on the window.
    //
    // Satie's tempo, a note that rings well past the hold threshold, and the
    // right hand wanted again three tenths of a second later: a tail of
    // exactly the shortest length that still counts.
    final song = Song(
      id: 'short',
      title: 'Short',
      composer: '',
      bpm: 100,
      notes: [
        const Note(beat: 4, midi: 60, duration: 2),
        // Exactly the shortest tail that still counts, whatever that is.
        Note(
          beat: 4 + StageGeometry.holdLeastSeconds * 100 / 60,
          midi: 67,
          duration: 2,
        ),
      ],
    );
    final chart = Chart.build(song);
    final tap = chart.taps.firstWhere((t) => t.beat == 4);
    expect(tap.isHold, isTrue, reason: 'it rings long enough to be held');
    expect(
      (tap.drawnEndBeat - tap.beat) / (song.bpm / 60),
      closeTo(StageGeometry.holdLeastSeconds, 1e-9),
    );

    for (final size in const [
      Size(390, 844), // a phone, nothing in the way
      Size(390, 740), // the same phone in Safari, toolbars showing
      Size(375, 667), // an SE
      Size(844, 390), // sideways
    ]) {
      final g = StageGeometry(size: size);
      final recorder = _Recorder();
      StagePainter(
        chart: chart,
        beat: tap.beat,
        windowInBeats: 1.9 * song.bpm / 60,
        heldNotes: {(tap.beat, 60)},
        playedNotes: {(tap.beat, 60)},
      ).paint(recorder, size);

      final bars = [
        for (final rect in recorder.rects)
          if ((rect.width - g.noteWidth * 0.7).abs() < 0.5 &&
              rect.bottom > g.hitLineY - 2)
            rect,
      ];
      expect(bars, isNotEmpty, reason: 'no bar on a $size screen');
    }
  });

  test('a held note keeps its bar until the note itself runs out', () {
    // The player: "basılı tutmalı notalar basılı tutsan bile son kısma
    // gelmeden kuyruk kayboluyor." The bar was dropped once it was under two
    // of its own widths long, so on a note being held it vanished a third of
    // a second early — still sixty pixels of tail, gone in one frame, with
    // the finger still down.
    const g = StageGeometry(size: phone);
    const window = 4.0;
    final song = Song(
      id: 'hold',
      title: 'Hold',
      composer: '',
      bpm: 120,
      notes: const [Note(beat: 4, midi: 60, duration: 4)],
    );
    final chart = Chart.build(song);
    final tap = chart.taps.single;
    expect(tap.isHold, isTrue);

    /// How long the bar is with [left] beats of the note still to hold.
    double? barWith(double left) {
      final recorder = _Recorder();
      StagePainter(
        chart: chart,
        beat: tap.drawnEndBeat - left,
        windowInBeats: window,
        heldNotes: {(tap.beat, 60)},
        playedNotes: {(tap.beat, 60)},
      ).paint(recorder, phone);
      // The bar is narrower than the note it hangs from, and it reaches down
      // to the line the note is waiting on.
      final bars = [
        for (final rect in recorder.rects)
          if ((rect.width - g.noteWidth * 0.7).abs() < 0.5 &&
              rect.bottom > g.hitLineY - 2)
            rect.height,
      ];
      return bars.isEmpty ? null : bars.first;
    }

    // A third of a second left to hold is where it used to disappear.
    expect(barWith(0.6), isNotNull);
    expect(barWith(0.25), isNotNull);
    // And it shortens the whole way down rather than stopping short.
    var last = double.infinity;
    for (var left = 1.4; left > 0.02; left -= 0.02) {
      final drawn = barWith(left);
      expect(drawn, isNotNull, reason: 'no bar with $left beats still to hold');
      expect(drawn!, lessThan(last));
      last = drawn;
    }
    expect(last, lessThan(g.noteRadius));
  });

  test('an answered ornament stops at the line instead of sliding past', () {
    // The little note sounds when the finger lands, so its mark ends at the
    // line with everything else the touch answered. It used to carry on down
    // while the notes it belonged to stopped dead — the player read that as
    // the ornament never bursting.
    const g = StageGeometry(size: phone);
    final chart = Chart.build(shipped('gnossienne-1'));
    final tap = chart.taps.firstWhere((t) => t.hasGrace);

    /// The marks drawn a quarter of a beat after the touch was due.
    List<Rect> marksAfter({required bool played}) {
      final recorder = _Recorder();
      StagePainter(
        chart: chart,
        beat: tap.beat + 0.25,
        windowInBeats: 4,
        playedNotes: played
            ? {for (final note in tap.notes) (tap.beat, note.midi)}
            : const {},
        heldNotes: played
            ? {for (final note in tap.notes) (tap.beat, note.midi)}
            : const {},
      ).paint(recorder, phone);
      return [
        for (var i = 0; i < recorder.rects.length; i++)
          if (recorder.rectStyles[i] == PaintingStyle.fill &&
              (recorder.rects[i].height - g.noteRadius * 2 * 0.55).abs() <
                  0.5 &&
              (recorder.rects[i].width - g.noteWidth * 0.55).abs() < 0.5 &&
              recorder.rects[i].center.dy > g.hitLineY)
            recorder.rects[i],
      ];
    }

    // Nobody played it: it goes on falling past the line, like any note
    // nobody caught.
    expect(marksAfter(played: false), isNotEmpty);
    // Played: gone, and the burst of light is what is left of it.
    expect(marksAfter(played: true), isEmpty);
  });

  test('an answered ornament throws its own light at the line', () {
    // One plume more than the touch has notes, in the middle of them, where
    // the little note's mark was.
    const g = StageGeometry(size: phone);
    final chart = Chart.build(shipped('gnossienne-1'));
    final tap = chart.taps.firstWhere((t) => t.hasGrace);

    List<Rect> plumes({int? graceMidi}) {
      final recorder = _Recorder();
      StagePainter(
        chart: chart,
        beat: tap.beat,
        windowInBeats: 4,
        sparks: [
          Spark(
            places: tap.noteAcross,
            midis: [for (final note in tap.notes) note.midi],
            graceMidi: graceMidi,
            hand: tap.hand,
            quality: 1,
          )..age = 0.2,
        ],
      ).paint(recorder, phone);
      return [
        for (var i = 0; i < recorder.rects.length; i++)
          if (recorder.rectShaded[i] &&
              recorder.rects[i].top >= g.hitLineY - 0.5)
            recorder.rects[i],
      ];
    }

    final without = plumes();
    final with_ = plumes(graceMidi: tap.graceMidi);
    expect(with_, hasLength(without.length + 1));

    // The extra one is in the middle of the others, narrower than they are:
    // the little note's light, the size its mark was.
    final extra = with_.singleWhere(
      (rect) => without.every((other) => (other.left - rect.left).abs() > 0.5),
    );
    expect(extra.width, lessThan(without.first.width));
    expect(
      extra.center.dx,
      closeTo(
        without.map((r) => r.center.dx).reduce((a, b) => a + b) /
            without.length,
        1,
      ),
    );
  });

  test('a chord band runs between the colours of the notes it joins', () async {
    // The band used to be one flat colour standing for how many notes the
    // chord had. Every note on screen is coloured by its pitch now, so the
    // band is too: its left end the colour of the note on the left, its
    // right end the colour of the note on the right.
    //
    // Two notes far apart in one hand, so the chart puts them at the ends of
    // the zone and nothing is drawn between them but the band.
    const lower = 60, upper = 64;
    final song = Song(
      id: 'band',
      title: 'Band',
      composer: '',
      bpm: 120,
      notes: const [
        Note(beat: 0, midi: lower, duration: 0.5),
        Note(beat: 0, midi: upper, duration: 0.5),
      ],
    );

    const g = StageGeometry(size: phone);
    const window = 4.0;
    // Half way down, where the band is clear of the hit line's own glow.
    const progress = 0.5;
    final picture = paintFrame(song, -window * (1 - progress), window: window);
    final image = await picture.toImage(
      phone.width.toInt(),
      phone.height.toInt(),
    );
    final pixels = (await image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    ))!;

    final chart = Chart.build(song);
    final tap = chart.taps.single;
    final left = g.xAtPosition(tap.noteAcross.reduce((a, b) => a < b ? a : b));
    final right = g.xAtPosition(tap.noteAcross.reduce((a, b) => a > b ? a : b));
    final y = g.yAt(progress).round();

    /// The hue of the band a quarter and three quarters of the way along.
    double hueAt(double x) {
      final at = (y * phone.width.toInt() + x.round()) * 4;
      return HSVColor.fromColor(
        Color.fromARGB(
          255,
          pixels.getUint8(at),
          pixels.getUint8(at + 1),
          pixels.getUint8(at + 2),
        ),
      ).hue;
    }

    final (low, high) = chart.pitchRange;
    double wanted(int midi) =>
        HSVColor.fromColor(AppTheme.pitchColor(midi, low: low, high: high)).hue;

    // A hue is a circle, so nearness has to wrap: 350° and 10° are close.
    double apart(double a, double b) {
      final gap = (a - b).abs() % 360;
      return gap > 180 ? 360 - gap : gap;
    }

    final nearLower = hueAt(left + (right - left) * 0.25);
    final nearUpper = hueAt(left + (right - left) * 0.75);

    // Along the band it becomes less like one note and more like the other.
    // Read as a shift rather than as two absolute colours: the band is laid
    // over the ground at a third of full strength, so what a pixel is worth
    // is how it compares with the other end, not what it is on its own.
    expect(
      apart(nearLower, wanted(lower)),
      lessThan(apart(nearUpper, wanted(lower))),
      reason: 'the end by the low note should be the more like it',
    );
    expect(
      apart(nearUpper, wanted(upper)),
      lessThan(apart(nearLower, wanted(upper))),
      reason: 'and the far end the more like the other note',
    );
  });

  test('an ornament is marked in its own note\'s colour, under the chord', () {
    // Gnossienne's ornaments: the little note sounds before the chord it
    // leans into, so its mark sits below the chord and carries its own pitch
    // — not the chord's colour, which is what it used to be drawn in.
    const g = StageGeometry(size: phone);
    final chart = Chart.build(shipped('gnossienne-1'));
    final tap = chart.taps.firstWhere((t) => t.hasGrace);
    final (low, high) = chart.pitchRange;
    final wanted = AppTheme.pitchColor(tap.graceMidi!, low: low, high: high);

    const window = 4.0;
    final recorder = _Recorder();
    StagePainter(
      chart: chart,
      beat: tap.beat - 1,
      windowInBeats: window,
    ).paint(recorder, phone);

    // Where that chord's heads are this frame, so its own mark can be told
    // from any other ornament on screen.
    final head = g.positionAtPosition(
      tap.across,
      StageGeometry.progressFor(1, window),
    );

    // The mark is the smaller capsule: a note's shape, scaled down. Nothing
    // else the painter draws comes out that size.
    final marks = [
      for (var i = 0; i < recorder.rects.length; i++)
        if (recorder.rectStyles[i] == PaintingStyle.fill &&
            (recorder.rects[i].height - g.noteRadius * 2 * 0.55).abs() < 0.5 &&
            (recorder.rects[i].width - g.noteWidth * 0.55).abs() < 0.5 &&
            (recorder.rects[i].center.dy - head.dy).abs() < g.noteRadius * 4)
          i,
    ];
    expect(
      marks,
      hasLength(1),
      reason: 'one mark for the touch, not one a note',
    );

    final mark = recorder.rects[marks.single];
    final ink = recorder.rectColours[marks.single];
    expect(ink.r, closeTo(wanted.r, 0.01));
    expect(ink.g, closeTo(wanted.g, 0.01));
    expect(ink.b, closeTo(wanted.b, 0.01));

    // The little note sounds *before* the chord, and sooner is nearer the
    // line — so it is drawn below the heads it belongs to.
    expect(mark.center.dy, greaterThan(head.dy));
  });

  group('the bar lines', () {
    /// Every level line the painter drew, top to bottom.
    List<double> barsAt(Song song, double beat, double window) {
      final recorder = _Recorder();
      StagePainter(
        chart: Chart.build(song),
        beat: beat,
        windowInBeats: window,
      ).paint(recorder, phone);
      return recorder.lines..sort();
    }

    test('come one to a bar', () {
      const g = StageGeometry(size: phone);
      final song = shipped('gnossienne-1'); // four beats to a bar
      // A wide window, so several are on screen at once and the spacing can
      // be read from the picture rather than from one line.
      const window = 16.0;
      final lines = barsAt(song, 8.0, window);
      expect(lines.length, greaterThan(2));
      final step = g.hitLineY * song.beatsPerBar / window;
      for (var i = 1; i < lines.length; i++) {
        expect(
          lines[i] - lines[i - 1],
          closeTo(step, 0.01),
          reason: 'the lines are a bar apart, not something else',
        );
      }
    });

    test('and sit just over the notes of that bar, not through them', () {
      const g = StageGeometry(size: phone);
      final song = shipped('gnossienne-1');
      const window = 16.0;
      // Beat 8 starts a bar in a piece counted in four. Its notes are on the
      // hit line at that moment; the line belongs a note's radius above them,
      // so it reads as a boundary rather than cutting the heads in half.
      final lines = barsAt(song, 8.0, window);
      expect(
        lines.any((y) => (y - (g.hitLineY - g.noteRadius)).abs() < 0.01),
        isTrue,
      );
    });

    test('a piece counted in twelve gets fewer of them', () {
      // The nocturne is written in twelve-eight; a line every four beats
      // would be ruling the music into bars it does not have.
      final song = shipped('nocturne-op9-no2');
      expect(song.beatsPerBar, 12);
      final lines = barsAt(song, 24.0, 16.0);
      expect(lines, hasLength(lessThan(3)));
    });
  });

  test('an empty window still paints the stage', () {
    // Before the first note there is nothing to draw but beams and the line;
    // that must still be a picture, not a blank screen.
    expect(() => paintFrame(shipped('fur-elise'), -50), returnsNormally);
  });

  test('renders the playfield to PNG', () async {
    final sizes = <String, int>{
      'fur-elise-giris': await savePng(
        shipped('fur-elise'),
        0.5,
        'fur-elise-giris',
      ),
      'fur-elise-akis': await savePng(
        shipped('fur-elise'),
        7.0,
        'fur-elise-akis',
      ),
      'ode-to-joy': await savePng(shipped('ode-to-joy'), 6.0, 'ode-to-joy'),
      'prelude-in-c': await savePng(
        shipped('prelude-in-c'),
        5.0,
        'prelude-in-c',
      ),
      // A beam still glowing from a hit a moment ago.
      'vurus-ani': await savePng(
        shipped('ode-to-joy'),
        6.05,
        'vurus-ani',
        litHands: {Hand.right: 0.8},
      ),
      // Chords: colour by finger count, with a band tying each one together.
      'akorlar': await savePng(shipped('ode-to-joy'), 5.0, 'akorlar'),
      'eller-ayri': await savePng(shipped('prelude-in-c'), 5.0, 'eller-ayri'),
      // One finger, three notes: the pips have to say so.
      'kolay-akor': await savePng(
        shipped('ode-to-joy'),
        5.0,
        'kolay-akor',
        difficulty: Difficulty.easy,
      ),
      // The same held note, caught and not caught. Caught, it waits on the
      // line with its bar shortening above it; missed, it falls past and
      // goes, tail and all.
      'tutma-basili': await savePng(
        shipped('ode-to-joy'),
        6.6,
        'tutma-basili',
        heldNotes: heldAt(shipped('ode-to-joy'), 6.0),
      ),
      'tutma-basilmadi': await savePng(
        shipped('ode-to-joy'),
        6.6,
        'tutma-basilmadi',
      ),
      // Bach's left hand: bass notes that ring under the figure above them.
      // Their tails now stop where the hand is next needed, instead of
      // stacking into a ladder.
      'ust-uste-tutmalar': await savePng(
        shipped('prelude-in-c'),
        6.0,
        'ust-uste-tutmalar',
      ),
      // A hit, and a streak running hot: rings opening on the line, the
      // floor lit, the beam thickened.
      'vurus-patlamasi': await savePng(
        shipped('ode-to-joy'),
        6.05,
        'vurus-patlamasi',
        litHands: {Hand.right: 0.9},
        heat: 0.9,
        sparks: [
          Spark(
            places: [0.70, 0.74],
            midis: [67, 71],
            hand: Hand.right,
            quality: 1,
          )..age = 0.03,
          Spark(
            places: [0.28, 0.29, 0.30],
            midis: [48, 52, 55],
            hand: Hand.left,
            quality: 0.9,
          )..age = 0.20,
          Spark(
            places: [0.20, 0.26, 0.33],
            midis: [45, 50, 54],
            hand: Hand.left,
            quality: 0.8,
          )..age = 0.45,
          Spark(places: [0.86], midis: [76], hand: Hand.right, quality: 0.6)
            ..age = 0.75,
        ],
      ),
      'zor-parmaklama': await savePng(
        shipped('ode-to-joy'),
        5.0,
        'zor-parmaklama',
        difficulty: Difficulty.hard,
      ),
      'akorlar-yatay': await savePng(
        shipped('ode-to-joy'),
        5.0,
        'akorlar-yatay',
        size: phoneLandscape,
      ),
      // Sideways: more beams, so the hands can divide the keyboard.
      'yatay-ode-to-joy': await savePng(
        shipped('ode-to-joy'),
        6.0,
        'yatay-ode-to-joy',
        size: phoneLandscape,
      ),
      'yatay-prelude': await savePng(
        shipped('prelude-in-c'),
        5.0,
        'yatay-prelude',
        size: phoneLandscape,
      ),
      // A run: the rondo's chromatic descent, sixty-two notes no hand can
      // tap, with the ribbon threading them into one slide.
      'hizli-akis': await savePng(shipped('fur-elise'), 156.0, 'hizli-akis'),
      // The bead a run is followed by: hollow when nobody is on it, lit when
      // a finger is.
      'kosu-boncugu': await savePng(
        shipped('fur-elise'),
        156.0,
        'kosu-boncugu',
        runBeads: [beadOf(shipped('fur-elise'), 156.0, tracked: true)],
      ),
      'kosu-boncugu-bos': await savePng(
        shipped('fur-elise'),
        156.0,
        'kosu-boncugu-bos',
        runBeads: [beadOf(shipped('fur-elise'), 156.0, tracked: false)],
      ),
      // Inside one of the canon's two long runs, so the thread shows.
      'kanon': await savePng(
        shipped('canon-in-d'),
        80.0,
        'kanon',
        ground: groundOf(shipped('canon-in-d')),
        runBeads: [beadOf(shipped('canon-in-d'), 80.0, tracked: true)],
      ),
      // Each piece brings its own light, read off its key: Satie's F minor
      // against Joplin's C major.
      'zemin-satie': await savePng(
        shipped('gnossienne-1'),
        20.0,
        'zemin-satie',
        ground: groundOf(shipped('gnossienne-1')),
      ),
      'zemin-joplin': await savePng(
        shipped('entertainer'),
        20.0,
        'zemin-joplin',
        ground: groundOf(shipped('entertainer')),
      ),
    };
    for (final entry in sizes.entries) {
      // A stage drawn with nothing on it compresses to almost nothing.
      expect(
        entry.value,
        greaterThan(10000),
        reason: '${entry.key} looks blank',
      );
    }
  });
}
