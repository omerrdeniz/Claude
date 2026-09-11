// The songs the game ships, and where each one comes from.
//
// **Adding a song is adding one entry here** and running
//
//     dart run tool/build_library.dart
//
// which fetches it, renders it, writes `assets/songs/<id>.mid` and
// regenerates `lib/data/catalog.g.dart`. Everything that can be read off the
// score is read off the score: tempo, metre, length, range, how many notes.
// What is left is what a machine cannot know — what to call the piece, who
// to credit, and the two judgements below.
library;

/// One score to import.
class Score {
  const Score({
    required this.id,
    required this.title,
    required this.composer,
    required this.credit,
    this.url,
    this.midiUrl,
    this.local,
    this.arrangement,
    this.localMidi,
    this.patchUrl,
    this.entry,
    this.assemble,
    this.beatsPerQuarter = 1,
    this.rightVelocity = 0.75,
    this.leftVelocity = 0.55,
    this.bpm,
    this.beatsPerBar,
    this.fromBar,
  })  : assert(
            url != null ||
                local != null ||
                midiUrl != null ||
                arrangement != null ||
                localMidi != null,
            'a score has to come from somewhere');

  /// What the song is called in code, in the asset name, and in save data.
  final String id;

  final String title;
  final String composer;

  /// Shown in the app, under the song. Says where the notes came from and on
  /// what terms — which for a Creative Commons engraving is a condition of
  /// using it, not a courtesy.
  final String credit;

  /// A `.ly` to render, or a `.zip` of sources when [entry] or [assemble]
  /// says what to do with it.
  final String? url;

  /// A score of our own, under `tool/scores/`. Used where no edition exists
  /// to take — the theme from the Ninth is not written for a keyboard at all.
  final String? local;

  /// An arrangement of our own, under `tool/scores/`, written in the game's
  /// own notation rather than engraved.
  ///
  /// [local] is for music nobody publishes for a keyboard; this is for music
  /// nobody publishes at all. A folk tune has no edition to take — it has a
  /// melody people sang before anyone wrote it down, and whatever
  /// accompaniment the player in front of you felt like. So the arrangement
  /// is ours, written out where it can be read and corrected by eye. It
  /// carries its own tempo and metre, because there is no edition to read
  /// them off.
  final String? arrangement;

  /// A MIDI under `tool/scores/`, already the notes.
  ///
  /// For music that reached us as a sequence rather than as an engraving.
  /// Nothing is rendered: the file is the score.
  final String? localMidi;

  /// A score published as MIDI rather than as engraving source.
  ///
  /// LilyPond is how most of this library arrives, but it is not the only
  /// way a score is published free. A digital edition in a symbolic format —
  /// Humdrum, MEI — is an encoding of the notes themselves, so the MIDI it
  /// renders is exactly as exact as one LilyPond makes: on the grid, repeats
  /// written out, both hands on their own tracks. Taking it straight saves
  /// setting an entire engraving toolchain on a file that is already the
  /// notes.
  ///
  /// This is what opens the library beyond Mutopia, which has no Chopin
  /// waltzes at all.
  final String? midiUrl;

  /// A patch to apply over the unpacked archive, for an arrangement
  /// published as a diff against somebody else's edition.
  final String? patchUrl;

  /// Which file inside the archive to render.
  final String? entry;

  /// A score of ours, under `tool/scores/`, written into the unpacked archive
  /// and rendered there — so it can `\include` the edition's own part files.
  ///
  /// This is how a piano arrangement is made from parts written for other
  /// instruments without retyping a note of them.
  final String? assemble;

  /// How many beats the player counts to a quarter note.
  ///
  /// One of two judgements a score cannot make for itself. A piece in 3/8 or
  /// 12/8 is felt in eighths, so its beat is half a quarter and this is 2.
  /// Everything else is 1. The tempo follows from it: the edition's quarter
  /// mark times this.
  final double beatsPerQuarter;

  /// The other judgement: how loud each hand is.
  ///
  /// Editions carry no dynamics we can read, so every note arrives at the
  /// same velocity. A thick left hand — Chopin's rocking accompaniment is
  /// three notes deep on nearly every eighth — has to be set under the melody
  /// or it sits on top of the tune it is supposed to be beneath.
  final double rightVelocity;
  final double leftVelocity;

  /// Overrides, for the rare score whose MIDI does not say, or lies.
  final double? bpm;
  final int? beatsPerBar;

  /// Start the song at this bar, counting the first bar as 1.
  ///
  /// For excerpts cut to try something out. The slide only appears eighty
  /// seconds into the canon, and nobody is going to play eighty seconds of
  /// canon every time they want to see whether it feels right.
  final int? fromBar;
}

/// The library, in the order it is offered.
const List<Score> catalog = [
  Score(
    id: 'canon-run-test',
    title: 'Canon in D (run test)',
    composer: 'Johann Pachelbel',
    url: 'https://www.mutopiaproject.org/ftp/PachelbelJ/'
        'Canon_per_3_Violini_e_Basso/Canon_per_3_Violini_e_Basso-lys.zip',
    assemble: 'canon-in-d.ly',
    // The canon's first run is at bar 19, seventy-nine seconds in. This
    // starts a bar before it, so the mechanic arrives in seconds instead of
    // after a minute and a half of playing.
    fromBar: 18,
    credit: 'Deneme parçası — Kanon\'un 18. ölçüsünden başlar, sürükleme '
        'mekaniğini denemek için.',
  ),
  Score(
    id: 'ode-to-joy',
    title: 'Ode to Joy',
    composer: 'Ludwig van Beethoven',
    local: 'ode-to-joy.ly',
    credit: 'Kamu malı (1824). Düzenleme Piano Flow.',
  ),
  Score(
    id: 'canon-in-d',
    title: 'Canon in D',
    composer: 'Johann Pachelbel',
    url: 'https://www.mutopiaproject.org/ftp/PachelbelJ/'
        'Canon_per_3_Violini_e_Basso/Canon_per_3_Violini_e_Basso-lys.zip',
    assemble: 'canon-in-d.ly',
    credit: 'Kamu malı (P. 37, 1694). Mutopia Project baskısı (Michael '
        'Fischer v. Mollard), CC BY 4.0. Piyano düzenlemesi Piano Flow: '
        'sağ el birinci keman, sol el zemin bas.',
  ),
  Score(
    id: 'fur-elise',
    title: 'Für Elise',
    composer: 'Ludwig van Beethoven',
    url: 'https://www.ibiblio.org/mutopia/ftp/BeethovenLv/WoO59/'
        'fur_Elise_WoO59/fur_Elise_WoO59.ly',
    beatsPerQuarter: 2, // 3/8, counted in eighths
    leftVelocity: 0.5,
    credit: 'Kamu malı (WoO 59, 1810). Mutopia Project baskısı '
        '(Stelios Samelis), tam eser.',
  ),
  Score(
    id: 'prelude-in-c',
    title: 'Prelude in C, BWV 846',
    composer: 'Johann Sebastian Bach',
    url: 'https://www.mutopiaproject.org/ftp/BachJS/BWV846/'
        'wtk1-prelude1/wtk1-prelude1.ly',
    credit: 'Kamu malı (BWV 846, 1722). Mutopia Project baskısı '
        '(Tobias Erbsland), tam eser.',
  ),
  Score(
    id: 'entertainer',
    title: 'The Entertainer',
    composer: 'Scott Joplin',
    url: 'https://www.mutopiaproject.org/ftp/JoplinS/entertainer/'
        'entertainer.ly',
    // Two score blocks: one for the page, one for the MIDI. The unfolding
    // has to go round the second, which is the one carrying \midi.
    credit: 'Kamu malı (1902). Mutopia Project baskısı (Chris Sawer), '
        '1902 orijinal baskısının tıpkıbasımı, tam eser.',
  ),
  Score(
    id: 'gnossienne-1',
    title: 'Gnossienne No. 1',
    composer: 'Erik Satie',
    url: 'https://www.mutopiaproject.org/ftp/SatieE/Gnossienne/no_1/no_1.ly',
    // No voltas to open out — every repeat in the source is already an
    // \repeat unfold — and its two score blocks both open with
    // \new PianoStaff, so unfolding would land on the printed one.
    credit: 'Kamu malı (1890). Mutopia Project baskısı (Knute Snortum), '
        'Salabert 1913 baskısından, CC BY-SA 4.0, tam eser.',
  ),
  Score(
    id: 'waltz-in-a-minor',
    title: 'Waltz in A minor, B. 150',
    composer: 'Frédéric Chopin',
    midiUrl: 'https://kernscores.stanford.edu/cgi-bin/ksdata?'
        'file=waltz150.krn&l=users/craig/classical/chopin/waltz&format=midi',
    // The left hand is the waltz's rocking bass-and-chord, under a melody
    // that is mostly single notes: level velocities would put the
    // accompaniment on top of the tune.
    leftVelocity: 0.45,
    credit: 'Kamu malı (B. 150, 1847). Nota kaynağı: KernScores (CCARH, '
        'Stanford) — Humdrum **kern dizgisi: Craig Stuart Sapp, 2004.',
  ),
  Score(
    id: 'nocturne-op9-no2',
    title: 'Nocturne Op. 9 No. 2',
    composer: 'Frédéric Chopin',
    url: 'https://www.mutopiaproject.org/ftp/ChopinFF/O9/'
        'chopin_nocturne_op9_n2/chopin_nocturne_op9_n2.ly',
    beatsPerQuarter: 2, // 12/8, counted in eighths
    leftVelocity: 0.45,
    credit: 'Kamu malı (Op. 9 No. 2, 1832). Mutopia Project baskısı '
        '(Renato Biolcati Rinaldi), CC BY-SA 3.0, tam eser.',
  ),
  Score(
    id: 'passacaglia',
    title: 'Passacaglia',
    composer: 'George Frideric Handel',
    midiUrl: 'https://vmirror.imslp.org/files/imglnks/usimg/b/b5/'
        'IMSLP365892-PMLP29691-Handel_432_Suite_7_Passacaille.mid',
    // A ground bass is meant to be under everything, not on top of it.
    leftVelocity: 0.45,
    credit: 'Kamu malı (HWV 432/6, 1720). IMSLP baskısı (Pierre Gouin, '
        'Éditions Outremontaises), CC BY-SA 4.0, tam eser. Johan '
        'Halvorsen\'in 1893 düzenlemesiyle tanınır.',
  ),
  Score(
    id: 'passacaglia-halvorsen',
    title: 'Passacaglia (Halvorsen)',
    composer: 'Handel / Halvorsen',
    localMidi: 'passacaglia-halvorsen.mid',
    leftVelocity: 0.5,
    credit: 'Kamu malı: Handel (HWV 432/6, 1720), Johan Halvorsen\'in 1893 '
        'düzenlemesi (Halvorsen † 1935). Nota verisi bir Online Sequencer '
        'dizgisinden çevrildi (onlinesequencer.net/2617124) — dizginin '
        'kendisi künyesiz.',
  ),
  Score(
    id: 'passacaglia-easy',
    title: 'Passacaglia (kolay)',
    composer: 'George Frideric Handel',
    arrangement: 'passacaglia.notes',
    // Same reason as the full one: a ground bass sits under, not on top.
    leftVelocity: 0.45,
    credit: 'Kamu malı (HWV 432/6, 1720). Zemin bas ve inen üst çizgi '
        'Handel\'in; çeşitlemeler Piano Flow\'un, yetişilebilir olsun diye. '
        'Tam eser ayrıca kütüphanede.',
  ),
  Score(
    id: 'house-of-the-rising-sun',
    title: 'House of the Rising Sun',
    composer: 'Geleneksel',
    arrangement: 'house-of-the-rising-sun.notes',
    // The left hand is an arpeggio under a melody that is one note at a
    // time: at level velocities the accompaniment would be the loudest
    // thing in the piece.
    leftVelocity: 0.45,
    credit: 'Geleneksel Amerikan halk şarkısı, anonim — kamu malı. Ezgi '
        'Frank Nordberg\'in geleneksel transkripsiyonundan (Digital '
        'Tradition / abcnotation.com). Piyano düzenlemesi Piano Flow.',
  ),
];
