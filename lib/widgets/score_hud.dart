import 'package:flutter/material.dart';

import '../game/judgement.dart';
import '../game/play_session.dart';
import '../theme/app_theme.dart';

/// Score, streak and the verdict for the last tap.
///
/// The one rule here is that none of it may compete with the notes. The score
/// sits out of the way, and the verdict appears clear of the hit line and
/// fades quickly — the player's eyes belong on the music.
class ScoreHud extends StatelessWidget {
  const ScoreHud({
    super.key,
    required this.scoreboard,
    required this.outcome,
    required this.outcomeAge,
    required this.hitLineFraction,
  });

  final Scoreboard scoreboard;
  final TapOutcome? outcome;

  /// How far through its life the verdict is, 0 to 1.
  final double outcomeAge;

  final double hitLineFraction;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(top: 56, right: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${scoreboard.score}',
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w300,
                        color: AppTheme.textPrimary,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    if (scoreboard.combo > 1) _streak(),
                  ],
                ),
              ),
            ),
          ),
          if (outcome != null && outcomeAge < 1) _verdict(context),
        ],
      ),
    );
  }

  Widget _streak() {
    final multiplier = scoreboard.multiplier;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${scoreboard.combo}',
          style: const TextStyle(
            fontSize: 15,
            color: AppTheme.accentSoft,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        if (multiplier > 1) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '×$multiplier',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.accentSoft,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _verdict(BuildContext context) {
    final fade = (1 - outcomeAge).clamp(0.0, 1.0);
    final verdict = outcome!.verdict;
    final colour = switch (verdict) {
      Verdict.perfect => AppTheme.accentSoft,
      Verdict.great => const Color(0xFF2ED3C6),
      Verdict.good => AppTheme.textMuted,
      Verdict.miss => const Color(0xFFFF6B6B),
    };

    return Align(
      // Below the line, where the notes have already gone.
      alignment: Alignment(0, hitLineFraction * 2 - 1 + 0.28),
      child: Opacity(
        opacity: fade,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              verdict.label,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
                color: colour,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _timingHint(outcome!.errorMs),
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.textMuted.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Telling the player *which way* they were off is what turns a score into
  /// practice; a bare verdict teaches nothing.
  String _timingHint(double errorMs) {
    if (errorMs.abs() < 25) return 'tam vuruşta';
    return errorMs < 0 ? 'biraz erken' : 'biraz geç';
  }
}
