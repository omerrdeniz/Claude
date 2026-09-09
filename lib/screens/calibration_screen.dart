import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../audio/piano_audio.dart';
import '../game/calibration.dart';
import '../theme/app_theme.dart';

/// Measures how far behind the player's ear is, so the game can stop guessing.
///
/// The manual setting on the song list is a number nobody can find by eye:
/// a perfect hit is a window fifty-five milliseconds wide, and being forty
/// out turns every one of them into a merely good one. So this asks the
/// player to tap along to a steady click and reads the answer off their
/// hands, the way rhythm games have always done it.
///
/// Deliberately nothing to look at while it runs. If there were something
/// flashing, a player would answer the flash, and what came back would be the
/// delay of the screen rather than of the sound.
///
/// Pops with the value to store as [PlaySession.latencyOffsetMs], or null if
/// the player backed out.
class CalibrationScreen extends StatefulWidget {
  const CalibrationScreen({super.key, this.periodMs = 600, this.nowMs});

  /// Gap between clicks. Slow enough to tap without hurrying, quick enough
  /// that sixteen of them do not take a minute.
  final double periodMs;

  /// Where the time is read from, in milliseconds.
  ///
  /// A [Stopwatch] when this is left out, read at the exact moment a click
  /// goes out and the exact moment a finger lands — the frame is sixteen
  /// milliseconds wide and what is being measured is smaller than that, so
  /// taking the frame's timestamp for both would put a whole frame of bias
  /// into the answer.
  ///
  /// Injectable because a widget test has no stopwatch to advance: `pump`
  /// moves a clock of its own, and without this seam none of the screen
  /// could be tested.
  final double Function()? nowMs;

  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<CalibrationScreen>
    with SingleTickerProviderStateMixin {
  final PianoAudio _audio = PianoAudio();

  final Stopwatch _clock = Stopwatch();
  late final double Function() _now =
      widget.nowMs ?? () => _clock.elapsedMicroseconds / 1000;

  late final Ticker _ticker = createTicker(_onTick);
  late final LatencyTally _tally =
      LatencyTally(windowMs: widget.periodMs / 2 - 20);

  /// Quiet at the start, so the first click is not the one being tapped at.
  static const double _leadInMs = 1200;

  /// The note the click is. High and short, so it cuts through and its
  /// beginning is unmistakable — which is the only part being timed.
  static const int _clickMidi = 84;

  int _clicksSoFar = 0;
  bool _finished = false;

  /// Where the run began, so starting over does not have to rewind a clock
  /// this screen may not own.
  double _restartedAt = 0;

  @override
  void initState() {
    super.initState();
    _audio.start();
    _audio.loadSamples();
    _clock.start();
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _audio.dispose();
    super.dispose();
  }

  void _onTick(Duration _) {
    if (_finished) return;
    final due =
        ((_now() - _restartedAt - _leadInMs) / widget.periodMs).floor() + 1;
    if (due > _clicksSoFar) {
      _clicksSoFar = due;
      _audio.noteOn(_clickMidi, velocity: 0.85);
      // The moment it actually went out, not the moment it was due.
      _tally.addClick(_now());
      setState(() {});
    }
  }

  void _onTap() {
    if (_finished) return;
    _audio.nudge(); // iOS wakes its audio only inside a gesture
    if (_tally.addTap(_now())) {
      setState(() {
        if (_tally.isDone) _finished = true;
      });
    }
  }

  void _restart() {
    setState(() {
      _tally.reset();
      _clicksSoFar = 0;
      _finished = false;
      _clock.reset();
      _restartedAt = _now();
    });
  }

  @override
  Widget build(BuildContext context) {
    final measured = _tally.measuredMs;
    final spread = _tally.spreadMs;
    final offset = _tally.offsetAgainst(_audio.latencyMs)?.round();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _onTap(),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Vazgeç',
                        style: TextStyle(color: AppTheme.textMuted)),
                  ),
                ),
                const Spacer(),
                const Text(
                  'Zamanlama ölçümü',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _finished
                      ? 'Bitti.'
                      : 'Duyduğun her sesle birlikte ekrana dokun.\n'
                          'Ekrana değil, sese uy — ölçülen şey ses.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 15, color: AppTheme.textMuted, height: 1.5),
                ),
                const SizedBox(height: 36),
                Text(
                  '${_tally.taps} / ${_tally.wantedTaps}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.w300,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 20),
                if (measured != null)
                  Text(
                    'Ölçülen gecikme: ${measured.round()} ms\n'
                    'Dağılım: ±${spread!.round()} ms'
                    '${spread > 45 ? '  — biraz dağınık, tekrar deneyebilirsin' : ''}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 14, color: AppTheme.textMuted, height: 1.6),
                  )
                else
                  const Text(
                    'En az sekiz dokunuş gerekiyor',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: AppTheme.textMuted),
                  ),
                const Spacer(),
                if (offset != null)
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      // Named, not left to the theme: the theme's own
                      // foreground for this colour came out dark on purple.
                      foregroundColor: AppTheme.textPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    onPressed: () => Navigator.of(context).pop(offset.toDouble()),
                    child: Text('Kullan  (${offset > 0 ? '+' : ''}$offset ms)'),
                  ),
                if (_tally.taps > 0) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _restart,
                    child: const Text('Baştan',
                        style: TextStyle(color: AppTheme.textMuted)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
