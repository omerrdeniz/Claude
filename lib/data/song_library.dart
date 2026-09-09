import '../music/notation.dart';
import '../music/note.dart';
import '../music/song.dart';
import 'score_import.dart';
import 'scores.g.dart' as scores;

/// The songs that ship with the game.
///
/// Everything here is public domain — the composers died well over a century
/// ago — and the editions are freely licensed. That is deliberate: it is what
/// lets the whole library be open from the first launch, with nothing locked
/// behind a paywall, which is the single loudest complaint against the game
/// this one takes after.
///
/// Two of the three are read from engraved editions rather than written out
/// here: [furElise] and [preludeInC] come from the Mutopia Project's LilyPond
/// sources, rendered to MIDI with every repeat played out and embedded by
/// `tool/fetch_scores.dart`. They are therefore the complete pieces, note for
/// note, instead of the fragments that stood here before — and the octave the
/// Bach was written in from memory turned out to be wrong.
///
/// Tempos are the ones the pieces are actually played at. The game plays a
/// song at the speed it is written at; there is no speed control.
abstract final class SongLibrary {
  static List<Song> get all => [odeToJoy, furElise, preludeInC];

  static Song? byId(String id) {
    for (final song in all) {
      if (song.id == id) return song;
    }
    return null;
  }

  /// Beethoven, from the Ninth Symphony: the complete sixteen-bar theme, all
  /// four phrases. The gentlest thing to start on — stepwise, and everybody
  /// already knows how it goes.
  ///
  /// This one is still our own arrangement. The theme is a melody for cellos
  /// and basses before it is anything else, so there is no piano edition to
  /// copy; it is set in C rather than Beethoven's D because that keeps the
  /// tune on white keys. The tempo is his own: Allegro assai, half note = 80.
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
      bpm: 160,
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

  /// Beethoven's bagatelle, whole: the rondo all the way through, A B A C A,
  /// with the repeats played out.
  ///
  /// Written in 3/8, and counted here in eighths, which is how it is felt —
  /// so a beat is an eighth and the bar is three of them. The edition marks
  /// the quarter at 72, which puts the eighth at 144.
  static Song get furElise => ScoreImport.read(
        scores.furElise,
        id: 'fur-elise',
        title: 'Für Elise',
        composer: 'Ludwig van Beethoven',
        bpm: 144,
        beatsPerBar: 3,
        beatsPerQuarter: 2,
        leftVelocity: 0.5,
        source: 'Kamu malı (WoO 59, 1810). Mutopia Project baskısı '
            '(Stelios Samelis), tam eser.',
      );

  /// Bach, the first prelude of the Well-Tempered Clavier: all thirty-five
  /// bars.
  ///
  /// One figure repeated under a changing harmony, which makes it ideal here:
  /// the shape of the touch stays put while the notes move under the player's
  /// fingers. The edition marks the quarter at 60.
  static Song get preludeInC => ScoreImport.read(
        scores.preludeInC,
        id: 'prelude-in-c',
        title: 'Prelüd, Do Majör',
        composer: 'Johann Sebastian Bach',
        bpm: 60,
        beatsPerBar: 4,
        source: 'Kamu malı (BWV 846, 1722). Mutopia Project baskısı '
            '(Tobias Erbsland), tam eser.',
      );
}
