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
/// All but [odeToJoy] are read from published LilyPond sources rather than
/// written out here, rendered to MIDI with every repeat played out and
/// embedded by `tool/fetch_scores.dart`. They are therefore the complete
/// pieces, note for note, instead of the fragments that stood here before —
/// and the octave the Bach was written in from memory turned out to be wrong.
///
/// The engravings are not all on the same terms; each one says which.
///
/// Tempos are the ones the pieces are written at. The game can play a song
/// slower, but the data is always at speed.
abstract final class SongLibrary {
  /// Built once, on first use, and shared from then on.
  ///
  /// Fields rather than getters, for a reason. As getters every read rebuilt
  /// every song — base64 decoded, MIDI parsed, some two and a half
  /// thousand notes allocated — and the song list reads them inside `build`,
  /// so a tap on any setting paid for the whole library again.
  static final List<Song> all = List.unmodifiable(
      [odeToJoy, canonInD, furElise, preludeInC, nocturneOp9No2]);

  static final Map<String, Song> _byId = {
    for (final song in all) song.id: song,
  };

  static Song? byId(String id) => _byId[id];

  /// Beethoven, from the Ninth Symphony: the complete sixteen-bar theme, all
  /// four phrases. The gentlest thing to start on — stepwise, and everybody
  /// already knows how it goes.
  ///
  /// This one is still our own arrangement. The theme is a melody for cellos
  /// and basses before it is anything else, so there is no piano edition to
  /// copy; it is set in C rather than Beethoven's D because that keeps the
  /// tune on white keys. The tempo is his own: Allegro assai, half note = 80.
  static final Song odeToJoy = _odeToJoy();

  static Song _odeToJoy() {
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
  static final Song furElise = ScoreImport.read(
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
  static final Song preludeInC = ScoreImport.read(
      scores.preludeInC,
      id: 'prelude-in-c',
      title: 'Prelüd, Do Majör',
      composer: 'Johann Sebastian Bach',
      bpm: 60,
      beatsPerBar: 4,
      source: 'Kamu malı (BWV 846, 1722). Mutopia Project baskısı '
          '(Tobias Erbsland), tam eser.',
  );

  /// Pachelbel's canon, whole: the ground bass round twenty-eight times with
  /// the three voices chasing each other over it.
  ///
  /// Not originally a keyboard piece — it is written for three violins and a
  /// bass — so unlike the others this is somebody's arrangement rather than
  /// an edition. The left hand is the ground, the right hand the three
  /// voices folded onto one staff.
  static final Song canonInD = ScoreImport.read(
    scores.canonInD,
    id: 'canon-in-d',
    title: 'Kanon, Re Majör',
    composer: 'Johann Pachelbel',
    bpm: 55,
    beatsPerBar: 4,
    source: 'Kamu malı (P. 37, 1694). Mutopia Project baskısı (Michael '
        'Fischer v. Mollard), piyano düzenlemesi Isaac David, CC BY 4.0.',
  );

  /// Chopin's first well-known nocturne, whole, cadenza and all.
  ///
  /// In 12/8 and counted in eighths, which is what the edition marks the
  /// tempo against: Andante, eighth = 132. The left hand is a wide rocking
  /// accompaniment three notes thick on nearly every eighth, so it is set
  /// quieter than the other pieces — otherwise it sits on top of the melody
  /// it is supposed to be under.
  ///
  /// The music is Chopin's and long out of copyright, but unlike the other
  /// two this engraving is not in the public domain: it is CC BY-SA 3.0, so
  /// the typesetter has to be credited and anything derived from it — this
  /// note data included — carries the same licence.
  static final Song nocturneOp9No2 = ScoreImport.read(
      scores.nocturneOp9No2,
      id: 'nocturne-op9-no2',
      title: 'Nokturn, Mi Bemol Majör',
      composer: 'Frédéric Chopin',
      bpm: 132,
      beatsPerBar: 12,
      beatsPerQuarter: 2,
      leftVelocity: 0.45,
      source: 'Kamu malı (Op. 9 No. 2, 1832). Mutopia Project baskısı '
          '(Renato Biolcati Rinaldi), CC BY-SA 3.0, tam eser.',
  );
}
