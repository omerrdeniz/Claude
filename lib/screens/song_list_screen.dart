import 'package:flutter/material.dart';

import '../data/song_library.dart';
import '../music/song.dart';
import '../theme/app_theme.dart';
import 'play_screen.dart';

/// The song browser.
///
/// Every song is open from the first launch. Nothing is locked, nothing costs
/// anything — which is the deliberate opposite of the game this one takes
/// after, whose players' loudest complaint is that they replay the same few
/// free songs forever.
class SongListScreen extends StatelessWidget {
  const SongListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
          children: [
            Text(
              'Piano Flow',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Işığa dokun, notayı çal',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
            ),
            const SizedBox(height: 28),
            for (final song in SongLibrary.all) _SongTile(song: song),
          ],
        ),
      ),
    );
  }
}

class _SongTile extends StatelessWidget {
  const _SongTile({required this.song});

  final Song song;

  @override
  Widget build(BuildContext context) {
    final minutes = song.duration.inSeconds ~/ 60;
    final seconds = song.duration.inSeconds % 60;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppTheme.surface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => PlayScreen(song: song)),
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
