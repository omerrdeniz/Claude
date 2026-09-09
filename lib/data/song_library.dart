import '../music/notation.dart';
import '../music/note.dart';
import '../music/song.dart';

/// The songs that ship with the game.
///
/// Everything here is public domain — the composers died well over a century
/// ago — and the arrangements are our own. That is deliberate: it is what lets
/// the whole library be open from the first launch, with nothing locked behind
/// a paywall, which is the single loudest complaint against the game this one
/// takes after.
///
/// Tempos are the ones the pieces are actually played at. The game can slow a
/// song down, but the song itself is written at speed.
abstract final class SongLibrary {
  static List<Song> get all => [odeToJoy, furElise, preludeInC];

  static Song? byId(String id) {
    for (final song in all) {
      if (song.id == id) return song;
    }
    return null;
  }

  /// Beethoven, from the Ninth Symphony: the complete sixteen-bar theme, all
  /// four phrases. The gentlest thing to start on — stepwise, in C, and
  /// everybody already knows how it goes.
  static Song get odeToJoy {
    // The phrase that opens three of the four lines.
    const opening = 'E4:1 E4:1 F4:1 G4:1 | G4:1 F4:1 E4:1 D4:1 | '
        'C4:1 C4:1 D4:1 E4:1 |';
    // The chords under it: tonic, then a turn to the dominant.
    const openingChords = 'C3+E3+G3:2*2 | C3+E3+G3:2 G2+B2+D3:2 | '
        'C3+E3+G3:2 G2+B2+D3:2 |';

    return Song(
      id: 'ode-to-joy',
      title: 'Neşeye Övgü',
      composer: 'Ludwig van Beethoven',
      bpm: 120,
      source: 'Kamu malı (1824). Düzenleme Piano Flow.',
      notes: [
        // Line one, ending open on the dominant.
        ...seq('$opening E4:1.5 D4:0.5 D4:2'),
        ...seq('$openingChords G2+B2+D3:4', hand: Hand.left, velocity: 0.55),

        // Line two, the same until the last bar, which comes home.
        ...seq('$opening D4:1.5 C4:0.5 C4:2', start: 16),
        ...seq('$openingChords G2+B2+D3:2 C3+E3+G3:2',
            start: 16, hand: Hand.left, velocity: 0.55),

        // Line three: the middle phrase, which steps away and back.
        ...seq(
          'D4:1 D4:1 E4:1 C4:1 | D4:1 E4:0.5 F4:0.5 E4:1 C4:1 | '
          'D4:1 E4:0.5 F4:0.5 E4:1 D4:1 | C4:1 D4:1 G3:2',
          start: 32,
        ),
        ...seq(
          'G2+B2+D3:4 | C3+E3+G3:2 G2+B2+D3:2 | G2+B2+D3:4 | '
          'C3+E3+G3:2 G2+B2+D3:2',
          start: 32,
          hand: Hand.left,
          velocity: 0.55,
        ),

        // Line four: the opening again, closing on the tonic.
        ...seq('$opening D4:1.5 C4:0.5 C4:2', start: 48),
        ...seq('$openingChords G2+B2+D3:2 C3+E3+G3:2',
            start: 48, hand: Hand.left, velocity: 0.55),
      ],
    );
  }

  /// Beethoven's bagatelle: the main theme, complete, played through twice as
  /// the score asks.
  ///
  /// Written in 3/8, so a beat here is an eighth note and the famous opening
  /// run falls on half beats.
  static Song get furElise {
    // The theme, nine bars of three beats.
    const theme = 'E5:0.5 D#5:0.5 E5:0.5 D#5:0.5 E5:0.5 B4:0.5 | '
        'D5:0.5 C5:0.5 A4:1 R:1 | '
        'C4:0.5 E4:0.5 A4:0.5 B4:1 R:0.5 | '
        'E4:0.5 G#4:0.5 B4:0.5 C5:1 R:0.5 | '
        'E4:0.5 E5:0.5 D#5:0.5 E5:0.5 D#5:0.5 E5:0.5 | '
        'B4:0.5 D5:0.5 C5:0.5 A4:1 R:0.5 | '
        'C4:0.5 E4:0.5 A4:0.5 B4:1 R:0.5 | '
        'E4:0.5 C5:0.5 B4:0.5 A4:2';

    // The left hand rocks between the two chords the theme sits on, entering
    // under the third bar and staying with it.
    const accompaniment = 'R:6 | A2:1 E3:1 A3:1 | E2:1 E3:1 G#3:1 | '
        'A2:1 E3:1 A3:1 | R:3 | A2:1 E3:1 A3:1 | E2:1 E3:1 G#3:1 | '
        'A2:1 E3:1 A3:1';

    const barsInTheme = 27.0; // nine bars of three beats

    return Song(
      id: 'fur-elise',
      title: 'Für Elise',
      composer: 'Ludwig van Beethoven',
      bpm: 132,
      beatsPerBar: 3,
      source: 'Kamu malı (1810). Ana tema, düzenleme Piano Flow.',
      notes: [
        ...seq(theme),
        ...seq(accompaniment, hand: Hand.left, velocity: 0.5),
        ...seq(theme, start: barsInTheme),
        ...seq(accompaniment,
            start: barsInTheme, hand: Hand.left, velocity: 0.5),
      ],
    );
  }

  /// Bach, the first prelude of the Well-Tempered Clavier.
  ///
  /// One figure repeated under a changing harmony, which makes it ideal here:
  /// the shape of the touch stays put while the notes move under the player's
  /// fingers.
  static Song get preludeInC {
    // Each bar is one harmony, spelled bottom to top: two bass notes and the
    // three-note figure above them. Bach writes each bar as two identical
    // halves, so this is all the piece is.
    const bars = [
      ['C3', 'E3', 'G3', 'C4', 'E4'],
      ['C3', 'D3', 'A3', 'D4', 'F4'],
      ['B2', 'D3', 'G3', 'D4', 'F4'],
      ['C3', 'E3', 'G3', 'C4', 'E4'],
      ['C3', 'E3', 'A3', 'E4', 'A4'],
      ['C3', 'D3', 'F#3', 'A3', 'D4'],
      ['B2', 'D3', 'G3', 'D4', 'G4'],
      ['B2', 'C3', 'E3', 'G3', 'C4'],
      ['A2', 'C3', 'E3', 'G3', 'C4'],
      ['D2', 'A2', 'D3', 'F#3', 'C4'],
      ['G2', 'B2', 'D3', 'G3', 'B3'],
      ['G2', 'Bb2', 'E3', 'G3', 'C#4'],
      ['F2', 'A2', 'D3', 'A3', 'D4'],
      ['F2', 'Ab2', 'D3', 'F3', 'B3'],
      ['E2', 'G2', 'C3', 'G3', 'C4'],
      ['E2', 'F2', 'A2', 'C3', 'F3'],
      ['D2', 'F2', 'A2', 'C3', 'F3'],
      ['G2', 'D3', 'G3', 'B3', 'F4'],
      ['C3', 'E3', 'G3', 'C4', 'E4'],
    ];

    final notes = <Note>[];
    for (var bar = 0; bar < bars.length; bar++) {
      final pitches = bars[bar].map(noteToMidi).toList();
      for (var half = 0; half < 2; half++) {
        final start = (bar * 4 + half * 2).toDouble();

        // The bass is struck once and held under the whole half bar.
        notes.add(Note(
            beat: start,
            midi: pitches[0],
            duration: 2,
            velocity: 0.55,
            hand: Hand.left));
        notes.add(Note(
            beat: start + 0.25,
            midi: pitches[1],
            duration: 1.75,
            velocity: 0.5,
            hand: Hand.left));

        // The figure above it, twice, in sixteenths.
        for (var repeat = 0; repeat < 2; repeat++) {
          for (var step = 0; step < 3; step++) {
            notes.add(Note(
              beat: start + 0.5 + repeat * 0.75 + step * 0.25,
              midi: pitches[2 + step],
              duration: 0.24,
              velocity: 0.65,
            ));
          }
        }
      }
    }

    return Song(
      id: 'prelude-in-c',
      title: 'Prelüd, Do Majör',
      composer: 'Johann Sebastian Bach',
      bpm: 66,
      source: 'Kamu malı (BWV 846, 1722). İlk on dokuz ölçü, '
          'düzenleme Piano Flow.',
      notes: notes,
    );
  }
}
