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
    this.local,
    this.patchUrl,
    this.entry,
    this.assemble,
    this.beatsPerQuarter = 1,
    this.rightVelocity = 0.75,
    this.leftVelocity = 0.55,
    this.bpm,
    this.beatsPerBar,
    this.fromBar,
  }) : assert(url != null || local != null, 'a score has to come from somewhere');

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
    id: 'moonlight-1',
    title: 'Moonlight Sonata (1st movement)',
    composer: 'Ludwig van Beethoven',
    url: 'https://www.mutopiaproject.org/ftp/BeethovenLv/O27/moonlight/'
        'moonlight-lys.zip',
    entry: 'moonlight1-a4.ly',
    credit: 'Kamu malı (Op. 27 No. 2, 1801). Mutopia Project baskısı '
        '(Stewart Holmes), Berners 1908 nüshasından.',
  ),
  Score(
    id: 'pathetique-2',
    title: 'Pathétique Sonata (2nd movement)',
    composer: 'Ludwig van Beethoven',
    url: 'https://www.mutopiaproject.org/ftp/BeethovenLv/O13/pathetique-2/'
        'pathetique-2.ly',
    credit: 'Kamu malı (Op. 13, 1798). Mutopia Project baskısı '
        '(Chris Sawer), Berners 1908 nüshasından.',
  ),
  Score(
    id: 'rondo-alla-turca',
    title: 'Rondo alla Turca',
    composer: 'Wolfgang Amadeus Mozart',
    url: 'https://www.mutopiaproject.org/ftp/MozartWA/KV331/KV331_3_RondoAllaTurca/'
        'KV331_3_RondoAllaTurca-lys.zip',
    entry: 'KV331_3_RondoAllaTurca.ly',
    // Nüshada metronom işareti yok ve LilyPond'un varsayılanı parçayı
    // yedi dakikaya çıkarıyor. Allegretto, ♩ = 126.
    bpm: 126,
    credit: 'Kamu malı (KV 331, 1783). Mutopia Project baskısı '
        '(Rune Zedeler ve Chris Sawer).',
  ),
  Score(
    id: 'k545-1',
    title: 'Sonata facile, K. 545 (1st movement)',
    composer: 'Wolfgang Amadeus Mozart',
    url: 'https://www.mutopiaproject.org/ftp/MozartWA/KV545/K545-1/'
        'K545-1.ly',
    credit: 'Kamu malı (KV 545, 1788). Mutopia Project baskısı '
        '(Alejandro Sierra), CC BY-SA 3.0.',
  ),
  Score(
    id: 'clair-de-lune',
    title: 'Clair de Lune',
    composer: 'Claude Debussy',
    url: 'https://www.mutopiaproject.org/ftp/DebussyC/L75/debussy_Ste_Bergamesq_Clair/'
        'debussy_Ste_Bergamesq_Clair.ly',
    // 9/8, sekizliklerle sayılıyor. Nüshada sayısal tempo yok;
    // Andante très expressif için ♪ = 100.
    bpm: 120,
    beatsPerQuarter: 2,
    credit: 'Kamu malı (L. 75, 1905). Mutopia Project baskısı '
        '(Keith OHara), Fromont 1905 nüshasından.',
  ),
  Score(
    id: 'arabesque-1',
    title: 'Première Arabesque',
    composer: 'Claude Debussy',
    url: 'https://www.mutopiaproject.org/ftp/DebussyC/L66/debussy_Arabesque_1/'
        'debussy_Arabesque_1.ly',
    bpm: 100, // nüshada yalnız "Andantino con moto" yazıyor
    credit: 'Kamu malı (L. 66, 1891). Mutopia Project baskısı '
        '(Keith OHara), Durand 1904 nüshasından.',
  ),
  Score(
    id: 'gymnopedie-1',
    title: 'Gymnopédie No. 1',
    composer: 'Erik Satie',
    url: 'https://www.mutopiaproject.org/ftp/SatieE/gymnopedie_1/'
        'gymnopedie_1.ly',
    bpm: 66, // nüshada yalnız "Lent et douloureux" yazıyor
    credit: 'Kamu malı (1888). Mutopia Project baskısı (Evin Robertson), '
        'Dover baskısından.',
  ),
  Score(
    id: 'gymnopedie-3',
    title: 'Gymnopédie No. 3',
    composer: 'Erik Satie',
    url: 'https://www.mutopiaproject.org/ftp/SatieE/gymnopedie_3/'
        'gymnopedie_3.ly',
    bpm: 66, // nüshada yalnız "Lent et grave" yazıyor
    credit: 'Kamu malı (1888). Mutopia Project baskısı (Evin Robertson), '
        'Dover baskısından.',
  ),
  Score(
    id: 'fantaisie-impromptu',
    title: 'Fantaisie-Impromptu',
    composer: 'Frédéric Chopin',
    url: 'https://www.mutopiaproject.org/ftp/ChopinFF/O66/chopin_fantaisie-impromptu/'
        'chopin_fantaisie-impromptu.ly',
    credit: 'Kamu malı (Op. 66, 1834). Mutopia Project baskısı '
        '(Guy D. Lederfein), Scholtz nüshasından.',
  ),
  Score(
    id: 'prelude-op28-4',
    title: 'Prelude Op. 28 No. 4',
    composer: 'Frédéric Chopin',
    url: 'https://www.mutopiaproject.org/ftp/ChopinFF/O28/Chop-28-4/'
        'Chop-28-4.ly',
    credit: 'Kamu malı (Op. 28, 1839). Mutopia Project baskısı '
        '(Magnus Lewis-Smith), Peters 1879 nüshasından.',
  ),
  Score(
    id: 'prelude-op28-7',
    title: 'Prelude Op. 28 No. 7',
    composer: 'Frédéric Chopin',
    url: 'https://www.mutopiaproject.org/ftp/ChopinFF/O28/Chop-28-7/'
        'Chop-28-7-lys.zip',
    entry: 'chopin_prelude_op28_no7.ly',
    // Dizgicinin MIDI bloğundaki ♩ = 120, on altı ölçülük parçayı yirmi
    // dört saniyeye indiriyor; Andantino bu değil.
    bpm: 66,
    credit: 'Kamu malı (Op. 28, 1839). Mutopia Project baskısı '
        '(Magnus Lewis-Smith), Peters nüshasından.',
  ),
  Score(
    id: 'prelude-op28-15',
    title: 'Prelude Op. 28 No. 15 (Raindrop)',
    composer: 'Frédéric Chopin',
    url: 'https://www.mutopiaproject.org/ftp/ChopinFF/O28/Chop-28-15/'
        'Chop-28-15-lys.zip',
    entry: 'chopin_prelude_op28_no15.ly',
    credit: 'Kamu malı (Op. 28, 1839). Mutopia Project baskısı '
        '(Magnus Lewis-Smith), Peters nüshasından.',
  ),
  Score(
    id: 'nocturne-op9-no1',
    title: 'Nocturne Op. 9 No. 1',
    composer: 'Frédéric Chopin',
    url: 'https://www.mutopiaproject.org/ftp/ChopinFF/O9/nocturne_in_b-flat_minor/'
        'nocturne_in_b-flat_minor.ly',
    leftVelocity: 0.45, // nokturn eşliği kalın; ezginin altında kalmalı
    credit: 'Kamu malı (Op. 9 No. 1, 1832). Mutopia Project baskısı '
        '(Benjamin D. Esham), CC BY-SA 2.5, Schirmer 1915 '
        'nüshasından.',
  ),
  Score(
    id: 'waltz-op64-no1',
    title: 'Minute Waltz, Op. 64 No. 1',
    composer: 'Frédéric Chopin',
    url: 'https://www.mutopiaproject.org/ftp/ChopinFF/O64/chopin_valse_op64_no1/'
        'chopin_valse_op64_no1-lys.zip',
    entry: 'chopin_valse_op64_no1.ly',
    credit: 'Kamu malı (Op. 64 No. 1, 1847). Mutopia Project baskısı '
        '(Magnus Lewis-Smith), Peters nüshasından.',
  ),
  Score(
    id: 'mountain-king',
    title: 'In the Hall of the Mountain King',
    composer: 'Edvard Grieg',
    url: 'https://www.mutopiaproject.org/ftp/GriegE/O46/Dans_l_antre_du_roi_de_la_montagne/'
        'Dans_l_antre_du_roi_de_la_montagne.ly',
    credit: 'Kamu malı (Op. 46 No. 4, 1875). Mutopia Project baskısı '
        '(Coyau), The University Society 1918 nüshasından.',
  ),
  Score(
    id: 'traumerei',
    title: 'Träumerei',
    composer: 'Robert Schumann',
    url: 'https://www.mutopiaproject.org/ftp/SchumannR/O15/SchumannOp15No07/'
        'SchumannOp15No07.ly',
    credit: 'Kamu malı (Op. 15 No. 7, 1838). Mutopia Project baskısı '
        '(Ying-Chun Liu).',
    bpm: 56, // nüshanın ilk gerçek işareti; öncesindeki 100 görünmez bir işaret
  ),
  Score(
    id: 'invention-1',
    title: 'Invention No. 1, BWV 772',
    composer: 'Johann Sebastian Bach',
    url: 'https://www.mutopiaproject.org/ftp/BachJS/BWV772/bach-invention-01/'
        'bach-invention-01.ly',
    bpm: 84, // nüshada tempo işareti yok
    credit: 'Kamu malı (BWV 772, 1723). Mutopia Project baskısı '
        '(Jeff Covey), CC BY-SA 3.0, Bach-Gesellschaft '
        'nüshasından.',
  ),
  Score(
    id: 'impromptu-op90-4',
    title: 'Impromptu Op. 90 No. 4',
    composer: 'Franz Schubert',
    url: 'https://www.mutopiaproject.org/ftp/SchubertF/D899/SchubertF-D899-4-Impromptu/'
        'SchubertF-D899-4-Impromptu.ly',
    credit: 'Kamu malı (D. 899, 1827). Mutopia Project baskısı '
        '(Ph. Raynaud), Breitkopf & Härtel 1888 nüshasından.',
    bpm: 130, // nüshanın kendi TEMPOBASE'i; MIDI'ye ilk giren o değil
  ),
  Score(
    id: 'consolation-3',
    title: 'Consolation No. 3',
    composer: 'Franz Liszt',
    url: 'https://www.mutopiaproject.org/ftp/LisztF/S.172/liszt-consolation-no3/'
        'liszt-consolation-no3.ly',
    bpm: 52, // nüshada yalnız "Lento placido" yazıyor
    credit: 'Kamu malı (S. 172 No. 3, 1850). Mutopia Project baskısı '
        '(Ryan Prince), CC BY 3.0.',
  ),
  Score(
    id: 'waltz-op39-15',
    title: 'Waltz Op. 39 No. 15',
    composer: 'Johannes Brahms',
    url: 'https://www.mutopiaproject.org/ftp/BrahmsJ/O39/waltz-op39-15/'
        'waltz-op39-15.ly',
    credit: 'Kamu malı (Op. 39 No. 15, 1865). Mutopia Project baskısı '
        '(Brian D. Rude), Joseffy nüshasından.',
  ),
  Score(
    id: 'minuet-g',
    title: 'Minuet in G, BWV Anh. 114',
    composer: 'Christian Petzold',
    url: 'https://www.mutopiaproject.org/ftp/BachJS/BWVAnh114/anna-magdalena-04/'
        'anna-magdalena-04.ly',
    credit: 'Kamu malı (1725). Anna Magdalena Bach defterinden; uzun süre '
        'Bach\'a atfedildi. Mutopia Project baskısı (Allen Garvin).',
  ),
  Score(
    id: 'minuet-g-minor',
    title: 'Minuet in G minor, BWV Anh. 115',
    composer: 'Christian Petzold',
    url: 'https://www.mutopiaproject.org/ftp/BachJS/BWVAnh115/anna-magdalena-05/'
        'anna-magdalena-05.ly',
    credit: 'Kamu malı (1725). Anna Magdalena Bach defterinden. Mutopia '
        'Project baskısı (Allen Garvin).',
  ),
  Score(
    id: 'menuett-woo82',
    title: 'Menuett, WoO 82',
    composer: 'Ludwig van Beethoven',
    url: 'https://www.mutopiaproject.org/ftp/BeethovenLv/WoO82/menuett_WoO82/'
        'menuett_WoO82.ly',
    credit: 'Kamu malı (WoO 82, 1796). Mutopia Project baskısı '
        '(Stelios Samelis).',
  ),
  Score(
    id: 'burgmuller-candeur',
    title: 'La Candeur, Op. 100 No. 1',
    composer: 'Friedrich Burgmüller',
    url: 'https://www.mutopiaproject.org/ftp/BurgmullerJFF/O100/25EF-01/'
        '25EF-01.ly',
    credit: 'Kamu malı (Op. 100, 1852). Mutopia Project baskısı '
        '(Bas Wassink).',
  ),
  Score(
    id: 'burgmuller-arabesque',
    title: 'L\'Arabesque, Op. 100 No. 2',
    composer: 'Friedrich Burgmüller',
    url: 'https://www.mutopiaproject.org/ftp/BurgmullerJFF/O100/25EF-02/'
        '25EF-02.ly',
    credit: 'Kamu malı (Op. 100, 1852). Mutopia Project baskısı '
        '(Bas Wassink).',
  ),
  Score(
    id: 'schumann-melodie',
    title: 'Melodie, Op. 68 No. 1',
    composer: 'Robert Schumann',
    url: 'https://www.mutopiaproject.org/ftp/SchumannR/O68/schumann-op68-01-melodie/'
        'schumann-op68-01-melodie.ly',
    bpm: 92, // nüshada yalnız "Nicht schnell" yazıyor
    credit: 'Kamu malı (Op. 68, 1848). Mutopia Project baskısı '
        '(Philippe Hézaine), CC BY-SA.',
  ),
  Score(
    id: 'kv331-tema',
    title: 'Sonata K. 331 (theme)',
    composer: 'Wolfgang Amadeus Mozart',
    url: 'https://www.mutopiaproject.org/ftp/MozartWA/KV331/KV331_1_1_tema/'
        'KV331_1_1_tema.ly',
    beatsPerQuarter: 2, // 6/8, sekizliklerle sayılıyor
    credit: 'Kamu malı (KV 331, 1783). Mutopia Project baskısı '
        '(Stelios Samelis).',
  ),
  Score(
    id: 'prelude-op28-20',
    title: 'Prelude Op. 28 No. 20',
    composer: 'Frédéric Chopin',
    url: 'https://www.mutopiaproject.org/ftp/ChopinFF/O28/Chop-28-20/'
        'Chop-28-20.ly',
    credit: 'Kamu malı (Op. 28, 1839). Mutopia Project baskısı '
        '(Magnus Lewis-Smith), Peters 1879 nüshasından.',
  ),
  Score(
    id: 'gymnopedie-2',
    title: 'Gymnopédie No. 2',
    composer: 'Erik Satie',
    url: 'https://www.mutopiaproject.org/ftp/SatieE/gymnopedie_2/'
        'gymnopedie_2.ly',
    bpm: 66, // nüshada yalnız "Lent et triste" yazıyor
    credit: 'Kamu malı (1888). Mutopia Project baskısı (Evin Robertson), '
        'Dover baskısından.',
  ),
  Score(
    id: 'grieg-albumblatt',
    title: 'Albumblatt, Op. 12 No. 3',
    composer: 'Edvard Grieg',
    url: 'https://www.mutopiaproject.org/ftp/GriegE/O12/No03_Albumblatt/'
        'No03_Albumblatt.ly',
    credit: 'Kamu malı (Op. 12, 1867). Mutopia Project baskısı '
        '(Knute Snortum), CC BY-SA.',
  ),
];
