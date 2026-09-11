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
}
