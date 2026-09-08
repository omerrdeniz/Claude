import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piano_flow/data/song_library.dart';
import 'package:piano_flow/game/chart.dart';
import 'package:piano_flow/music/song.dart';
import 'package:piano_flow/render/stage_painter.dart';

const Size phone = Size(390, 844);

/// Paint one frame straight onto a canvas — no widget tree, no clock.
ui.Picture paintFrame(Song song, double beat, {double window = 4}) {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Offset.zero & phone);
  StagePainter(
    chart: Chart.build(song),
    beat: beat,
    windowInBeats: window,
  ).paint(canvas, phone);
  return recorder.endRecording();
}

/// Save a frame as a PNG under build/screens, so the playfield can actually be
/// looked at. There is no device here to look at it on, so it is rendered to
/// file the same way the synthesiser is rendered to WAV.
Future<int> savePng(Song song, double beat, String name) async {
  final picture = paintFrame(song, beat);
  final image = await picture.toImage(phone.width.toInt(), phone.height.toInt());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File('build/screens/$name.png');
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(bytes!.buffer.asUint8List());
  return file.lengthSync();
}

void main() {
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
    };
    for (final entry in sizes.entries) {
      // A stage drawn with nothing on it compresses to almost nothing.
      expect(entry.value, greaterThan(10000), reason: '${entry.key} looks blank');
    }
  });
}
