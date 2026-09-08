import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../game/chart.dart';
import '../music/song.dart';
import '../render/stage_painter.dart';
import '../theme/app_theme.dart';

/// The playfield.
///
/// At this stage it only shows the song flowing past: no tapping, no sound.
/// That is on purpose — the motion has to read correctly on its own before
/// anything is judged against it.
class PlayScreen extends StatefulWidget {
  const PlayScreen({
    super.key,
    required this.song,
    this.beamCount = Chart.defaultBeamCount,
    this.approachSeconds = 1.9,
  });

  final Song song;
  final int beamCount;

  /// How long a note takes to travel from the top of the screen to the line.
  ///
  /// Held in seconds rather than beats deliberately: the eye needs the same
  /// amount of warning whatever the tempo, so a fast song shows fewer notes at
  /// once rather than the same notes moving faster.
  final double approachSeconds;

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen>
    with SingleTickerProviderStateMixin {
  late final Chart _chart = Chart.build(widget.song, beamCount: widget.beamCount);
  late final Ticker _ticker = createTicker(_onTick);

  Duration _elapsed = Duration.zero;
  bool _running = true;

  /// Beats per second at the song's written tempo.
  double get _beatsPerSecond => widget.song.bpm / 60;

  double get _beat =>
      _elapsed.inMicroseconds / 1e6 * _beatsPerSecond - _leadInBeats;

  /// A moment of empty stage before the first note, so it arrives travelling
  /// rather than appearing on the line.
  double get _leadInBeats => widget.approachSeconds * _beatsPerSecond;

  double get _windowInBeats => widget.approachSeconds * _beatsPerSecond;

  @override
  void initState() {
    super.initState();
    _ticker.start();
  }

  void _onTick(Duration elapsed) {
    setState(() => _elapsed = elapsed);
    if (_beat > _chart.lengthInBeats + 2) {
      _ticker.stop();
      _running = false;
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _running = !_running;
      _running ? _ticker.start() : _ticker.stop();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: CustomPaint(
              painter: StagePainter(
                chart: _chart,
                beat: _beat,
                windowInBeats: _windowInBeats,
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.song.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        widget.song.composer,
                        style: const TextStyle(
                            fontSize: 13, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: _toggle,
                    icon: Icon(_running ? Icons.pause : Icons.play_arrow),
                    color: AppTheme.textMuted,
                    tooltip: _running ? 'Duraklat' : 'Devam',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
