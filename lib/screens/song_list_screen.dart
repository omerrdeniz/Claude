import 'package:flutter/material.dart';

import '../data/song_library.dart';
import '../game/chart.dart';
import '../music/song.dart';
import '../theme/app_theme.dart';
import 'play_screen.dart';

/// The song browser.
///
/// Every song is open from the first launch. Nothing is locked, nothing costs
/// anything — which is the deliberate opposite of the game this one takes
/// after, whose players' loudest complaint is that they replay the same few
/// free songs forever.
class SongListScreen extends StatefulWidget {
  const SongListScreen({super.key});

  @override
  State<SongListScreen> createState() => _SongListScreenState();
}

class _SongListScreenState extends State<SongListScreen> {
  Difficulty _difficulty = Difficulty.normal;

  /// Speeds offered, as a fraction of the written tempo.
  static const List<double> _speeds = [0.6, 0.8, 1.0];
  double _speed = 0.8;

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
            const SizedBox(height: 24),
            _DifficultyPicker(
              selected: _difficulty,
              onChanged: (value) => setState(() => _difficulty = value),
            ),
            const SizedBox(height: 20),
            _SpeedPicker(
              speeds: _speeds,
              selected: _speed,
              onChanged: (value) => setState(() => _speed = value),
            ),
            const SizedBox(height: 24),
            for (final song in SongLibrary.all)
              _SongTile(
                song: song,
                difficulty: _difficulty,
                speed: _speed,
              ),
          ],
        ),
      ),
    );
  }
}

/// Chooses how much of the song is the player's to play.
class _DifficultyPicker extends StatelessWidget {
  const _DifficultyPicker({required this.selected, required this.onChanged});

  final Difficulty selected;
  final ValueChanged<Difficulty> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (final difficulty in Difficulty.values)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _Chip(
                    label: difficulty.label,
                    selected: difficulty == selected,
                    onTap: () => onChanged(difficulty),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          selected.description,
          style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
        ),
      ],
    );
  }
}

/// Chooses how fast the song runs.
///
/// Slowing a piece down is how anyone learns one; the game should offer it
/// before a beginner concludes they simply cannot play.
class _SpeedPicker extends StatelessWidget {
  const _SpeedPicker({
    required this.speeds,
    required this.selected,
    required this.onChanged,
  });

  final List<double> speeds;
  final double selected;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (final speed in speeds)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _Chip(
                    label: speed == 1.0 ? 'Tam hız' : '%\${(speed * 100).round()}',
                    selected: speed == selected,
                    onTap: () => onChanged(speed),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          selected == 1.0
              ? 'Şarkının kendi temposu'
              : 'Yavaşlatılmış — notalar arasında daha çok zaman',
          style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppTheme.accent.withValues(alpha: 0.30)
          : AppTheme.surface.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? AppTheme.accentSoft : Colors.transparent,
              width: 1.2,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? AppTheme.textPrimary : AppTheme.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _SongTile extends StatelessWidget {
  const _SongTile({
    required this.song,
    required this.difficulty,
    required this.speed,
  });

  final Song song;
  final Difficulty difficulty;
  final double speed;

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
