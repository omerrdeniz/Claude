import 'package:flutter/material.dart';

import '../../data/song_info.dart';
import '../../data/song_library.dart';
import '../../game/chart.dart';
import '../../game/judgement.dart';
import '../../theme/app_theme.dart';
import '../play_screen.dart';

/// One song in the list, carrying every setting through to the game.
///
/// Every one of these has been forgotten on the way to [PlayScreen] at least
/// once, which is why `test/song_list_test.dart` checks each of them arrives.
class SongTile extends StatelessWidget {
  const SongTile({
    super.key,
    required this.info,
    required this.difficulty,
    required this.speed,
    required this.tolerance,
    required this.quantize,
    required this.fillMissed,
    required this.latencyOffsetMs,
  });

  final SongInfo info;
  final Difficulty difficulty;
  final double speed;
  final TimingTolerance tolerance;
  final bool quantize;
  final bool fillMissed;
  final double latencyOffsetMs;

  /// Read the score, then play it.
  ///
  /// The notes are an asset now rather than something compiled into the app,
  /// so opening a song is a read — a few tens of kilobytes, and only the once
  /// per song per session. Doing it here rather than up front is what lets
  /// the library grow without the app growing with it.
  Future<void> _open(BuildContext context) async {
    final song = await SongLibrary.load(info.id);
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlayScreen(
          song: song,
          difficulty: difficulty,
          speed: speed,
          tolerance: tolerance,
          quantize: quantize,
          fillMissed: fillMissed,
          latencyOffsetMs: latencyOffsetMs,
        ),
      ),
    );
  }

  /// How busy the piece is, in words, at the speed the player has chosen.
  ///
  /// Not "Kolay/Normal/Zor" — those already name the difficulty setting, and
  /// this is a fact about the music rather than about the level. It says how
  /// many touches a second are coming, which is the thing that decides
  /// whether somebody who has never played can get through a piece.
  static String paceOf(double tapsPerSecond) => tapsPerSecond < 2.5
      ? 'Sakin'
      : tapsPerSecond < 4
          ? 'Akıcı'
          : tapsPerSecond < 6
              ? 'Hızlı'
              : 'Çok hızlı';

  @override
  Widget build(BuildContext context) {
    final length = info.duration.inSeconds ~/ speed;
    final minutes = length ~/ 60;
    final seconds = length % 60;
    // Slowing a piece down really does make it a gentler one, so the word
    // follows the speed the player has set.
    final pace = paceOf(info.tapsPerSecond * speed);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppTheme.surface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _open(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        info.title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        info.composer,
                        style: const TextStyle(
                            fontSize: 13, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$minutes:${seconds.toString().padLeft(2, '0')}',
                      style: const TextStyle(
                          fontSize: 13, color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      pace,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textMuted.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 10),
                const Icon(Icons.play_arrow_rounded,
                    color: AppTheme.accentSoft, size: 26),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
