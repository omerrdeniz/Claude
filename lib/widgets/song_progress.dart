import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A hairline across the top of the playfield, filling as the piece goes by.
///
/// Where the player is in a song was otherwise only knowable by listening,
/// and "the thing I want to look at happens around two and a half minutes in"
/// was not a question the game could answer. Thin and at the very edge: a
/// thing to glance at between notes rather than to watch.
///
/// It measures the whole song, not the part being played. A run begun half
/// way through opens with the bar half full, because that is where in the
/// music the player is.
class SongProgressBar extends StatelessWidget {
  const SongProgressBar({super.key, required this.through});

  /// How far through the song, 0 at the first note and 1 at the last.
  final double through;

  /// Thin enough to ignore while playing, thick enough to see at arm's
  /// length.
  static const double thickness = 2.5;

  @override
  Widget build(BuildContext context) {
    // Flex rather than a fraction of a measured width: the bar is the full
    // width of whatever it is given, and two flexible children divide it
    // without the widget needing to know what that width is.
    final filled = (through.clamp(0.0, 1.0) * 1000).round();
    return SafeArea(
      bottom: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          height: thickness,
          child: Row(
            children: [
              Expanded(
                flex: filled,
                child: const ColoredBox(color: AppTheme.accentSoft),
              ),
              Expanded(
                flex: 1000 - filled,
                child: ColoredBox(
                  color: AppTheme.surface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Song time as a clock, for the player to quote back.
///
/// Minutes and whole seconds. Tenths were tried and are unreadable on a
/// number that changes sixty times a second, and the thing this is for —
/// "the passage at 1:03" — has no use for them.
String clockOf(double seconds) {
  if (!seconds.isFinite) return '0:00';
  final whole = seconds.clamp(0.0, 24 * 3600).floor();
  return '${whole ~/ 60}:${(whole % 60).toString().padLeft(2, '0')}';
}
