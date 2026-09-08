import 'package:flutter/material.dart';

import '../game/judgement.dart';
import '../theme/app_theme.dart';

/// Shown when a song ends.
///
/// It reports how the performance went rather than just a number: the counts
/// say *what* went wrong, which is what a player needs in order to do better
/// next time.
class ResultPanel extends StatelessWidget {
  const ResultPanel({
    super.key,
    required this.scoreboard,
    required this.songTitle,
    required this.onReplay,
    required this.onBack,
  });

  final Scoreboard scoreboard;
  final String songTitle;
  final VoidCallback onReplay;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.background.withValues(alpha: 0.88),
      alignment: Alignment.center,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                songTitle,
                style: const TextStyle(
                    fontSize: 15, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 14),
              Text(
                scoreboard.grade,
                style: const TextStyle(
                  fontSize: 76,
                  height: 1,
                  fontWeight: FontWeight.w300,
                  color: AppTheme.accentSoft,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${scoreboard.score}',
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 24),
              _row('İsabet', '%${(scoreboard.accuracy * 100).round()}'),
              _row('En uzun seri', '${scoreboard.bestCombo}'),
              const SizedBox(height: 12),
              for (final verdict in Verdict.values)
                _row(verdict.label, '${scoreboard.counts[verdict]}',
                    muted: true),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: onBack,
                    child: const Text('Şarkılar',
                        style: TextStyle(color: AppTheme.textMuted)),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: onReplay,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 14),
                    ),
                    child: const Text('Tekrar çal'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool muted = false}) {
    final colour = muted ? AppTheme.textMuted : AppTheme.textPrimary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: SizedBox(
        width: 220,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(fontSize: 14, color: AppTheme.textMuted)),
            Text(value,
                style: TextStyle(
                  fontSize: 14,
                  color: colour,
                  fontFeatures: const [FontFeature.tabularFigures()],
                )),
          ],
        ),
      ),
    );
  }
}
