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
abstract final class SongLibrary {
  static List<Song> get all => [odeToJoy, furElise, preludeInC];

  static Song? byId(String id) {
    for (final song in all) {
      if (song.id == id) return song;
    }
    return null;
  }

  /// Beethoven, from the Ninth Symphony. The gentlest thing to start on:
  /// stepwise, in C, and everybody already knows how it goes.
  static Song get odeToJoy {
    const phrase = 'E4:1 E4:1 F4:1 G4:1 | G4:1 F4:1 E4:1 D4:1 | '
        'C4:1 C4:1 D4:1 E4:1 |';
    const chords = 'C3+E3+G3:2*2 | C3+E3+G3:2 G2+B2+D3:2 | '
        'C3+E3+G3:2 G2+B2+D3:2 |';

    return Song(
      id: 'ode-to-joy',
      title: 'Neşeye Övgü',
      composer: 'Ludwig van Beethoven',
      bpm: 108,
      source: 'Kamu malı (1824). Düzenleme Piano Flow.',
      notes: [
        // First half, ending on a half cadence.
        ...seq('$phrase E4:1.5 D4:0.5 D4:2'),
        ...seq('$chords G2+B2+D3:4', hand: Hand.left, velocity: 0.55),
        // Second half, the same until the last bar, which comes home to C.
        ...seq('$phrase D4:1.5 C4:0.5 C4:2', start: 16),
        ...seq('$chords G2+B2+D3:2 C3+E3+G3:2',
            start: 16, hand: Hand.left, velocity: 0.55),
      ],
    );
  }

  /// Beethoven's bagatelle. Written in 3/8, so a beat here is an eighth note
  /// and the famous opening run falls on half beats.
  static Song get furElise {
    return Song(
      id: 'fur-elise',
      title: 'Für Elise',
      composer: 'Ludwig van Beethoven',
      bpm: 132,
      beatsPerBar: 3,
      source: 'Kamu malı (1810). Düzenleme Piano Flow.',
      notes: [
        ...seq(
          'E5:0.5 D#5:0.5 E5:0.5 D#5:0.5 E5:0.5 B4:0.5 | '
          'D5:0.5 C5:0.5 A4:1 R:1 | '
          'C4:0.5 E4:0.5 A4:0.5 B4:1 R:0.5 | '
          'E4:0.5 G#4:0.5 B4:0.5 C5:1 R:0.5 | '
          'E4:0.5 E5:0.5 D#5:0.5 E5:0.5 D#5:0.5 E5:0.5 | '
          'B4:0.5 D5:0.5 C5:0.5 A4:1.5',
        ),
        // The left hand enters under the third bar, rocking arpeggios.
        ...seq(
          'A2:1 E3:1 A3:1 | E2:1 E3:1 G#3:1 | A2:1 E3:1 A3:1 | A2:1.5 E3:1.5',
          start: 6,
          hand: Hand.left,
          velocity: 0.5,
        ),
      ],
    );
  }

  /// Bach, the first prelude of the Well-Tempered Clavier. A single figure
  /// repeated under a changing harmony, which makes it ideal here: the shape
  /// of the tap stays put while the notes move under the player's fingers.
  static Song get preludeInC {
    // Each bar is one harmony, spelled bottom to top: two bass notes and the
    // three-note figure above them.
    const bars = [
      ['C3', 'E3', 'G3', 'C4', 'E4'],
      ['C3', 'D3', 'A3', 'D4', 'F4'],
      ['B2', 'D3', 'G3', 'D4', 'F4'],
      ['C3', 'E3', 'G3', 'C4', 'E4'],
    ];

    final notes = <Note>[];
    for (var bar = 0; bar < bars.length; bar++) {
      final pitches = bars[bar].map(noteToMidi).toList();
      // Bach writes each bar as two identical halves.
      for (var half = 0; half < 2; half++) {
        final start = bar * 4 + half * 2;

        // The bass is struck once and held under the whole half bar.
        notes.add(Note(
            beat: start.toDouble(), midi: pitches[0], duration: 2, velocity: 0.55,
            hand: Hand.left));
        notes.add(Note(
            beat: start + 0.25, midi: pitches[1], duration: 1.75,
            velocity: 0.5, hand: Hand.left));

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
      bpm: 72,
      source: 'Kamu malı (BWV 846, 1722). Düzenleme Piano Flow.',
      notes: notes,
    );
  }
}
