import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piano_flow/data/song_library.dart';
import 'package:piano_flow/game/chart.dart';
import 'package:piano_flow/music/song.dart';
import 'package:piano_flow/game/stage_geometry.dart';
import 'package:piano_flow/render/stage_painter.dart';
import 'package:piano_flow/theme/app_theme.dart';

const Size phone = Size(390, 844);
const Size phoneLandscape = Size(844, 390);

/// Paint one frame straight onto a canvas — no widget tree, no clock.
ui.Picture paintFrame(Song song, double beat,
    {double window = 4,
    Map<int, double> litBeams = const {},
    Size size = phone,
    Difficulty difficulty = Difficulty.normal}) {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Offset.zero & size);
  StagePainter(
    chart: Chart.build(song,
        beamCount: Chart.beamsForWidth(size.width), difficulty: difficulty),
    beat: beat,
    windowInBeats: window,
    litBeams: litBeams,
  ).paint(canvas, size);
  return recorder.endRecording();
}

/// Save a frame as a PNG under build/screens, so the playfield can actually be
/// looked at. There is no device here to look at it on, so it is rendered to
/// file the same way the synthesiser is rendered to WAV.
Future<int> savePng(Song song, double beat, String name,
    {Map<int, double> litBeams = const {},
    Size size = phone,
    Difficulty difficulty = Difficulty.normal}) async {
  final picture = paintFrame(song, beat,
      litBeams: litBeams, size: size, difficulty: difficulty);
  final image = await picture.toImage(size.width.toInt(), size.height.toInt());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File('build/screens/$name.png');
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(bytes!.buffer.asUint8List());
  return file.lengthSync();
}

void main() {
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
    const landscape =
        StageGeometry(size: phoneLandscape, beamCount: 6);
    // A note must not be so large that consecutive ones overlap vertically.
    expect(landscape.noteRadiusAt(1.0) * 2,
        lessThan(phoneLandscape.height * 0.15));
  });

  test('turning sideways makes room for more beams', () {
    expect(Chart.beamsForWidth(phone.width), 4);
    expect(Chart.beamsForWidth(phoneLandscape.width), 6);
    expect(Chart.beamsForWidth(320), 3,
        reason: 'the smallest phones give up a beam to keep them reachable');
    expect(Chart.beamsForWidth(2000), lessThanOrEqualTo(6),
        reason: 'a tablet must not sprout unreachable beams');
  });

  test('the playfield paints in landscape too', () {
    expect(
        () => paintFrame(SongLibrary.odeToJoy, 6, size: phoneLandscape),
        returnsNormally);
  });

  test('a beam lit by a hit still paints', () {
    expect(() => paintFrame(SongLibrary.odeToJoy, 6.0, litBeams: {0: 1.0, 3: 0.2}),
        returnsNormally);
  });

  test('painting a frame does not throw', () {
    for (final song in SongLibrary.all) {
      for (final beat in [-2.0, 0.0, 3.5, 12.0, 1000.0]) {
        expect(() => paintFrame(song, beat), returnsNormally,
            reason: '${song.title} at beat $beat');
      }
    }
  });

  test('an empty window still paints the stage', () {
    // Before the first note there is nothing to draw but beams and the line;
    // that must still be a picture, not a blank screen.
    expect(() => paintFrame(SongLibrary.furElise, -50), returnsNormally);
  });

  test('renders the playfield to PNG', () async {
    final sizes = <String, int>{
      'fur-elise-giris': await savePng(SongLibrary.furElise, 0.5, 'fur-elise-giris'),
      'fur-elise-akis': await savePng(SongLibrary.furElise, 7.0, 'fur-elise-akis'),
      'ode-to-joy': await savePng(SongLibrary.odeToJoy, 6.0, 'ode-to-joy'),
      'prelude-in-c': await savePng(SongLibrary.preludeInC, 5.0, 'prelude-in-c'),
      // A beam still glowing from a hit a moment ago.
      'vurus-ani': await savePng(SongLibrary.odeToJoy, 6.05, 'vurus-ani',
          litBeams: {2: 0.8}),
      // Chords: colour by finger count, with a band tying each one together.
      'akorlar': await savePng(SongLibrary.odeToJoy, 5.0, 'akorlar'),
      'akorlar-yatay': await savePng(
          SongLibrary.odeToJoy, 5.0, 'akorlar-yatay',
          size: phoneLandscape),
      // Sideways: more beams, so the hands can divide the keyboard.
      'yatay-ode-to-joy': await savePng(
          SongLibrary.odeToJoy, 6.0, 'yatay-ode-to-joy',
          size: phoneLandscape),
      'yatay-prelude': await savePng(
          SongLibrary.preludeInC, 5.0, 'yatay-prelude',
          size: phoneLandscape),
    };
    for (final entry in sizes.entries) {
      // A stage drawn with nothing on it compresses to almost nothing.
      expect(entry.value, greaterThan(10000), reason: '${entry.key} looks blank');
    }
  });
}
