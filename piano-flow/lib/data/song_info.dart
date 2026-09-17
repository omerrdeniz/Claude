/// What the game knows about a song without opening it.
///
/// The notes live in an asset and are read only when a song is chosen; this
/// is everything the list screen needs before that, and everything
/// [ScoreImport] needs to shape the notes once it happens.
///
/// Generated into `catalog.g.dart` by `tool/build_library.dart`, mostly from
/// the score itself — the tempo, the metre, the length and the range are read
/// out of the rendered MIDI rather than typed in.
class SongInfo {
  const SongInfo({
    required this.id,
    required this.title,
    required this.composer,
    required this.source,
    required this.bpm,
    required this.beatsPerBar,
    required this.noteCount,
    required this.tapCount,
    required this.durationMs,
    required this.lowMidi,
    required this.highMidi,
    this.beatsPerQuarter = 1,
    this.rightVelocity = 0.75,
    this.leftVelocity = 0.55,
    this.startBeat = 0,
  });

  final String id;
  final String title;
  final String composer;

  /// Where the music came from and on what terms.
  final String source;

  /// Written tempo, in the beat the piece is counted in.
  final double bpm;

  final int beatsPerBar;

  /// How many beats the player counts to a quarter note — 2 for a piece felt
  /// in eighths.
  final double beatsPerQuarter;

  final double rightVelocity;
  final double leftVelocity;

  /// Where in the piece this song begins, in its own beats.
  ///
  /// Zero for everything the library ships as music. It is not zero for the
  /// excerpts cut to try something out: a mechanic that only appears eighty
  /// seconds into a four-minute piece cannot be tested by playing the piece.
  final double startBeat;

  final int noteCount;

  /// How many touches the piece asks for at Normal — measured, like
  /// everything else here, by laying the score out at build time.
  final int tapCount;

  /// Touches a second at the written tempo: how busy the piece is.
  ///
  /// The one number that says whether somebody who has never played can get
  /// through it. The library ran from Satie's 1.2 to Chopin's 14.9 with
  /// nothing on the screen to tell them apart, and the player — who had
  /// asked for well-known pieces and got the hardest ones — noticed.
  double get tapsPerSecond =>
      durationMs == 0 ? 0 : tapCount / (durationMs / 1000);

  /// How long the piece runs at its written tempo.
  final int durationMs;

  final int lowMidi;
  final int highMidi;

  Duration get duration => Duration(milliseconds: durationMs);

  /// Where the notes are.
  String get asset => 'assets/songs/$id.mid';

  @override
  String toString() => 'SongInfo($id, $noteCount notes @ $bpm bpm)';
}
