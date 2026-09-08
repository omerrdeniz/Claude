import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../audio/piano_audio.dart';
import '../game/chart.dart';
import '../game/play_session.dart';
import '../music/song.dart';
import '../render/stage_painter.dart';
import '../theme/app_theme.dart';
import '../widgets/result_panel.dart';
import '../widgets/score_hud.dart';

/// The playfield: notes flow toward the line, the player taps, the song plays.
class PlayScreen extends StatefulWidget {
  const PlayScreen({
    super.key,
    required this.song,
    this.beamCount,
    this.approachSeconds = 1.9,
  });

  final Song song;

  /// Fixed number of beams, or null to let the screen decide from its width.
  final int? beamCount;

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
  late final PianoAudio _audio = PianoAudio();
  late final PlaySession _session;
  late final Ticker _ticker = createTicker(_onTick);

  /// Beams still glowing from a recent hit, and how fresh each one is.
  final Map<int, double> _litBeams = {};

  /// How many beams the current layout uses. Set before the first build from
  /// the widget's own setting, then kept in step with the screen width.
  int _beamCount = Chart.defaultBeamCount;

  TapOutcome? _lastOutcome;
  Duration _lastOutcomeAt = Duration.zero;
  Duration _now = Duration.zero;

  @override
  void initState() {
    super.initState();
    _beamCount = widget.beamCount ?? Chart.defaultBeamCount;
    _session = PlaySession(
      chart: Chart.build(widget.song, beamCount: _beamCount),
      audio: _audio,
      approachSeconds: widget.approachSeconds,
    )..onMiss = (_) => setState(() {});
    _audio.start();
    _session.start();
    _ticker.start();
  }

  void _onTick(Duration elapsed) {
    setState(() {
      _now = elapsed;
      _session.update(elapsed);
      _fadeBeamGlow();
    });
    if (_session.isFinished) {
      _ticker.stop();
      _session.pause();
    }
  }

  /// A hit lights its beam, which then dies away over a moment.
  void _fadeBeamGlow() {
    _litBeams.updateAll((_, value) => value - 0.06);
    _litBeams.removeWhere((_, value) => value <= 0);
  }

  /// Follow the screen: turning the device sideways makes room for more
  /// beams, which is the whole point of playing in landscape.
  void _matchLayout(Size size) {
    if (widget.beamCount != null) return;
    final wanted = Chart.beamsForWidth(size.width);
    if (wanted == _beamCount) return;
    _beamCount = wanted;
    _session.rebindChart(Chart.build(widget.song, beamCount: wanted));
    _litBeams.clear();
  }

  void _onTapDown(Offset position, Size size) {
    // At the hit line the beams are evenly spaced across the full width, so
    // the whole column belongs to its beam — the player aims at a lane, not at
    // the note itself.
    final beam = (position.dx / (size.width / _beamCount))
        .floor()
        .clamp(0, _beamCount - 1);

    final outcome = _session.tap(beam);
    if (outcome == null) return;
    setState(() {
      _litBeams[beam] = 1.0;
      _lastOutcome = outcome;
      _lastOutcomeAt = _now;
    });
  }

  void _togglePause() {
    setState(() {
      if (_session.isRunning) {
        _session.pause();
        _audio.engine.allNotesOff();
      } else {
        _session.start();
      }
    });
  }

  void _restart() {
    setState(() {
      _session.restart();
      _lastOutcome = null;
      _litBeams.clear();
    });
    if (!_ticker.isActive) _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _session.stop();
    _audio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          _matchLayout(size);
          return Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (event) => _onTapDown(event.localPosition, size),
            child: Stack(
              fit: StackFit.expand,
              children: [
                RepaintBoundary(
                  child: CustomPaint(
                    painter: StagePainter(
                      chart: _session.chart,
                      beat: _session.beat,
                      windowInBeats: _session.windowInBeats,
                      litBeams: Map.of(_litBeams),
                    ),
                  ),
                ),
                ScoreHud(
                  scoreboard: _session.scoreboard,
                  outcome: _lastOutcome,
                  // The verdict fades on its own so it never covers the next
                  // note the player has to read.
                  outcomeAge: (_now - _lastOutcomeAt).inMilliseconds / 700,
                  hitLineFraction: 0.68,
                ),
                _controls(),
                if (_session.isFinished)
                  ResultPanel(
                    scoreboard: _session.scoreboard,
                    songTitle: widget.song.title,
                    onReplay: _restart,
                    onBack: () => Navigator.of(context).maybePop(),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _controls() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.song.title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    widget.song.composer,
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: _restart,
              icon: const Icon(Icons.refresh),
              color: AppTheme.textMuted,
              tooltip: 'Baştan',
            ),
            IconButton(
              onPressed: _togglePause,
              icon: Icon(_session.isRunning ? Icons.pause : Icons.play_arrow),
              color: AppTheme.textMuted,
              tooltip: _session.isRunning ? 'Duraklat' : 'Devam',
            ),
          ],
        ),
      ),
    );
  }
}
