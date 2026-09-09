import 'package:flutter/material.dart';

import '../../game/chart.dart';
import '../../game/judgement.dart';
import '../../music/song.dart';
import '../../theme/app_theme.dart';
import '../play_screen.dart';

/// One song in the list, carrying every setting through to the game.
///
/// Every one of these has been forgotten on the way to [PlayScreen] at least
/// once, which is why `test/song_list_test.dart` checks each of them arrives.
class SongTile extends StatelessWidget {
  const SongTile({
    super.key,
    required this.song,
    required this.difficulty,
    required this.speed,
    required this.tolerance,
    required this.quantize,
    required this.fillMissed,
    required this.latencyOffsetMs,
  });

  final Song song;
  final Difficulty difficulty;
  final double speed;
  final TimingTolerance tolerance;
  final bool quantize;
  final bool fillMissed;
  final double latencyOffsetMs;

  @override
  Widget build(BuildContext context) {
    final length = song.duration.inSeconds ~/ speed;
    final minutes = length ~/ 60;
    final seconds = length % 60;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppTheme.surface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.of(context).push(
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
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        song.composer,
                        style: const TextStyle(
                            fontSize: 13, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
                Text(
                  '$minutes:${seconds.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                      fontSize: 13, color: AppTheme.textMuted),
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
