import 'package:flutter/material.dart';

import '../audio/piano_audio.dart';
import '../data/song_library.dart';
import '../game/chart.dart';
import '../game/judgement.dart';
import '../theme/app_theme.dart';
import 'song_list/settings.dart';
import 'song_list/song_tile.dart';

/// Stamped in at build time, so a phone can say which version it is running.
const String buildId =
    String.fromEnvironment('BUILD_ID', defaultValue: 'geliştirme');

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
  @override
  void initState() {
    super.initState();
    // Start pulling the recorded piano in while the player is still reading
    // the list, so the first song is already played on it.
    PianoAudio().loadSamples();
  }

  Difficulty _difficulty = Difficulty.normal;

  /// Speeds offered, as a fraction of the written tempo.
  static const List<double> _speeds = [0.4, 0.6, 0.8, 1.0];

  /// Full speed by default: the songs are written at the tempo they are
  /// actually played at and should sound that way on the first press. Slowing
  /// down is a practice tool, one tap away, for the pieces that outrun a hand
  /// — which at their real tempo, Chopin's and Beethoven's both do.
  double _speed = 1.0;

  /// The player's own timing calibration, in milliseconds, on top of whatever
  /// the device reports about its own audio delay.
  ///
  /// It has to be adjustable because no device tells the truth about this.
  /// A browser reports what it knows about; it cannot know about Bluetooth
  /// headphones, and it says nothing about the player's own hand, which
  /// reliably arrives a little after the eye says to move.
  double _latencyOffsetMs = 0;

  /// Steps of the calibration, and how far it goes either way.
  static const double _latencyStep = 10;
  static const double _latencyLimit = 300;

  /// Forgiving by default, and the music kept in time by default: the game
  /// should flatter a beginner before it tests one.
  TimingTolerance _tolerance = TimingTolerance.wide;
  bool _quantize = true;

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
            Row(
              children: [
                // Flexible, not fixed: on a narrow phone the tagline has to
                // give way rather than push the build stamp off the screen.
                const Flexible(
                  child: Text(
                    'Işığa dokun, notayı çal',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                // Which build this is. Without it there is no way to tell a
                // fix that did not work from a fix that never arrived.
                Text(
                  buildId,
                  style: TextStyle(
                    color: AppTheme.textMuted.withValues(alpha: 0.5),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ChoiceRow<Difficulty>(
              options: Difficulty.values,
              selected: _difficulty,
              labelOf: (difficulty) => difficulty.label,
              caption: _difficulty.description,
              onChanged: (value) => setState(() => _difficulty = value),
            ),
            const SizedBox(height: 20),
            ChoiceRow<double>(
              options: _speeds,
              selected: _speed,
              labelOf: (speed) =>
                  speed == 1.0 ? 'Tam hız' : '%${(speed * 100).round()}',
              caption: _speed == 1.0
                  ? 'Şarkının kendi temposu'
                  : 'Yavaşlatılmış — notalar arasında daha çok zaman',
              onChanged: (value) => setState(() => _speed = value),
            ),
            const SizedBox(height: 20),
            ChoiceRow<TimingTolerance>(
              options: TimingTolerance.values,
              selected: _tolerance,
              labelOf: (tolerance) => tolerance.label,
              caption: 'Tolerans — ${_tolerance.description.toLowerCase()}',
              onChanged: (value) => setState(() => _tolerance = value),
            ),
            const SizedBox(height: 14),
            QuantizeSwitch(
              value: _quantize,
              onChanged: (value) => setState(() => _quantize = value),
            ),
            const SizedBox(height: 14),
            LatencyPicker(
              offsetMs: _latencyOffsetMs,
              onChanged: (value) => setState(() => _latencyOffsetMs =
                  value.clamp(-_latencyLimit, _latencyLimit)),
              step: _latencyStep,
            ),
            const SizedBox(height: 24),
            for (final song in SongLibrary.all)
              SongTile(
                song: song,
                difficulty: _difficulty,
                speed: _speed,
                tolerance: _tolerance,
                quantize: _quantize,
                latencyOffsetMs: _latencyOffsetMs,
              ),
            const SizedBox(height: 8),
            // The recorded piano is CC BY: the credit is a condition of using
            // it, not a courtesy, so it ships in the app and not only in the
            // repository.
            const Text(
              'Piyano sesleri: Salamander Grand Piano — Alexander Holm, '
              'CC BY 3.0',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
