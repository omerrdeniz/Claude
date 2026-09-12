import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piano_flow/music/note.dart';
import 'package:piano_flow/music/song.dart';
import 'package:piano_flow/theme/app_theme.dart';
import 'package:piano_flow/theme/song_ground.dart';

import 'support/library.dart';

/// The ground each piece is played on is worked out from the piece, so the
/// thing to test is whether the working out is right — and for a key, right
/// is a matter of public record.
void main() {
  Song songOf(String id) => shippedSongs.firstWhere((s) => s.id == id);

  test('a piece reads as the key it is published in', () {
    // What the editions say. Where a key has two names, either spelling of
    // the same twelve-tone tonic counts — D-flat and C-sharp are one key.
    const published = {
      'ode-to-joy': 'C major',
      'canon-in-d': 'D major',
      'fur-elise': 'A minor',
      'prelude-in-c': 'C major',
      'entertainer': 'C major',
      'gnossienne-1': 'F minor',
      'nocturne-op9-no2': 'E♭ major',
      'waltz-in-a-minor': 'A minor',
    };

    for (final entry in published.entries) {
      expect(keyOf(songOf(entry.key)).toString(), entry.value,
          reason: entry.key);
    }
  });

  test('every ground weighs the same, whatever key it came from', () {
    // Held by luminance rather than by HSL lightness on purpose: a green and
    // a blue at one lightness are nothing like each other on screen, and a
    // ground chosen by key has to be safe for all twelve of them.
    for (final song in shippedSongs) {
      final ground = groundOf(song);
      expect(ground.top.computeLuminance(), closeTo(0.014, 0.004),
          reason: song.id);
      expect(ground.bottom.computeLuminance(), lessThan(0.006),
          reason: song.id);
      // The notes stay the brightest thing on screen; the pool of light at
      // the line is well below them and still plainly light.
      expect(ground.glow.computeLuminance(), closeTo(0.22, 0.06),
          reason: song.id);
      expect(ground.top.computeLuminance(),
          lessThan(ground.glow.computeLuminance()),
          reason: song.id);
    }
  });

  test('pieces in different keys are lit differently', () {
    expect(
        groundOf(songOf('fur-elise')), isNot(groundOf(songOf('prelude-in-c'))));
    expect(groundOf(songOf('gnossienne-1')),
        isNot(groundOf(songOf('nocturne-op9-no2'))));
    // Same key, same light: the ground is atmosphere, not a name badge.
    expect(keyOf(songOf('prelude-in-c')), keyOf(songOf('entertainer')));
  });

  test('reading a key twice gives the same answer', () {
    for (final song in shippedSongs) {
      expect(groundOf(song), groundOf(song), reason: song.id);
    }
  });

  test('a song with no notes falls back rather than failing', () {
    final empty = Song(
        id: 'empty', title: '', composer: '', bpm: 120, notes: const <Note>[]);
    expect(keyOf(empty), isNull);
    expect(groundOf(empty), AppTheme.defaultGround);
  });

  group('a note is coloured by which note it is', () {
    // A piece of a little over four octaves, as the Gnossienne is.
    HSLColor hsl(int midi) =>
        HSLColor.fromColor(AppTheme.pitchColor(midi, low: 34, high: 83));

    test('twelve notes, twelve hues', () {
      final hues = {for (var midi = 60; midi < 72; midi++) hsl(midi).hue};
      expect(hues, hasLength(12));
    });

    test('the same note is the same hue in every octave', () {
      // Within a degree: the colour goes out through eight-bit channels and
      // comes back, so the hue that returns is never exactly the one asked
      // for. A degree is far below anything an eye can pick out.
      for (var pitch = 0; pitch < 12; pitch++) {
        final low = hsl(36 + pitch).hue;
        for (final octave in [48, 60, 72, 84]) {
          expect(hsl(octave + pitch).hue, closeTo(low, 1.0));
        }
      }
    });

    test('and it is lighter the higher it is', () {
      var last = -1.0;
      for (var midi = 34; midi <= 83; midi += 12) {
        final light = hsl(midi).lightness;
        expect(light, greaterThan(last));
        last = light;
      }
    });

    test('one octave of it is a difference the eye can find', () {
      // What the player caught: the Gnossienne opens on C4-F4-C5 and the two
      // C's came out the same red, because an octave was six points of
      // lightness out of a range six octaves wide. Measured against the
      // piece's own range, and with the weight of the colour moving too, an
      // octave has to be plain.
      final low = hsl(60), high = hsl(72);
      expect(low.hue, closeTo(high.hue, 1.0), reason: 'the same note');
      expect(low.saturation, closeTo(high.saturation, 0.02),
          reason: 'and so the same colour — only the light may move');
      expect(high.lightness - low.lightness, greaterThan(0.1));
    });

    test('a key does not come out in one colour', () {
      // What sent the circle of fifths back: a key's notes are neighbours on
      // it, so every piece was one colour family. A minor's own notes have to
      // land right round the wheel, not in one corner of it.
      const aMinor = [69, 71, 72, 74, 76, 77, 79]; // A B C D E F G
      final hues = aMinor.map((m) => hsl(m).hue).toList()..sort();
      final spread = hues.last - hues.first;
      expect(spread, greaterThan(180),
          reason: 'a piece should not be one colour');
    });

    test('neighbouring steps of a scale are told apart', () {
      // The worry about going chromatic. A whole tone is sixty degrees.
      for (final pair in [(60, 62), (62, 64), (65, 67), (67, 69)]) {
        final apart = (hsl(pair.$1).hue - hsl(pair.$2).hue).abs();
        expect(apart, greaterThan(55.0));
      }
    });
  });
}
