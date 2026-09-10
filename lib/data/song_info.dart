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
    required this.durationMs,
    required this.lowMidi,
    required this.highMidi,
    this.beatsPerQuarter = 1,
    this.rightVelocity = 0.75,
    this.leftVelocity = 0.55,
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

  final int noteCount;

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
