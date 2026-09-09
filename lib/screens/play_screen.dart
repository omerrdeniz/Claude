import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../audio/piano_audio.dart';
import '../game/chart.dart';
import '../music/note.dart';
import '../game/judgement.dart';
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
    this.difficulty = Difficulty.normal,
    this.speed = 1.0,
    this.tolerance = TimingTolerance.wide,
    this.quantize = true,
    this.fillMissed = true,
    this.approachSeconds = 1.9,
    this.latencyOffsetMs = 0,
  });

  final Song song;
  final Difficulty difficulty;

  /// Fraction of the written tempo to play at.
  final double speed;

  /// How forgiving the judging is.
  final TimingTolerance tolerance;

  /// Whether notes sound on their beat rather than under the finger.
  final bool quantize;

  /// Whether a note nobody plays sounds anyway, quietly.
  final bool fillMissed;

  /// The player's own calibration, on top of what the device reports.
  ///
  /// Positive means their taps are treated as that much earlier — which is
  /// what to reach for when everything registers as late.
  final double latencyOffsetMs;

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

  /// Hands still glowing from a recent hit, and how fresh each one is.
  final Map<Hand, double> _litHands = {};

  /// Which note each finger currently on the screen is holding down.
  final Map<int, int> _heldByPointer = {};

  TapOutcome? _lastOutcome;
  Duration _lastOutcomeAt = Duration.zero;
  Duration _now = Duration.zero;

  @override
  void initState() {
    super.initState();
    _session = PlaySession(
      chart: Chart.build(widget.song, difficulty: widget.difficulty),
      audio: _audio,
      // The hard level is the same notes judged more tightly; everything else
      // about it is identical, so this is the only place it differs.
      // Hard tightens whatever tolerance the player chose, rather than
      // replacing it.
      judge: Judge.forTolerance(widget.tolerance)
          .tightened(widget.difficulty == Difficulty.hard ? 0.6 : 1.0),
      quantize: widget.quantize,
      fillMissed: widget.fillMissed,
      approachSeconds: widget.approachSeconds,
      latencyOffsetMs: widget.latencyOffsetMs,
      speed: widget.speed,
    )..onMiss = (_) => setState(() {});
    _audio.start();
    // Not awaited: the synthesiser covers the first moments, and a song that
    // waits on a download to begin is worse than one that improves as it
    // goes. Usually the bank is already in memory from the song list.
    _audio.loadSamples();
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

  /// A hit lights its side of the screen, which then dies away.
  void _fadeBeamGlow() {
    _litHands.updateAll((_, value) => value - 0.06);
    _litHands.removeWhere((_, value) => value <= 0);
  }

  void _onTapDown(int pointer, Offset position, Size size) {
    // The first touch on the playfield is the game's real chance to start
    // audio: a browser will only allow it from inside a gesture.
    _audio.nudge();

    final across = (position.dx / size.width).clamp(0.0, 1.0);
    final outcome = _session.tap(across);
    if (outcome == null) return;

    if (outcome.holdId != null) _heldByPointer[pointer] = outcome.holdId!;

    setState(() {
      // A near miss reports itself but does not light anything: nothing
      // sounded, so nothing should look as though it did.
      if (outcome.scored) _litHands[outcome.hand] = 1.0;
      _lastOutcome = outcome;
      _lastOutcomeAt = _now;
    });
  }

  /// A finger came off the screen. If it was holding a long note, that note
  /// stops here.
  void _onTapUp(int pointer) {
    final holdId = _heldByPointer.remove(pointer);
    if (holdId == null) return;
    if (_session.releaseHold(holdId)) setState(() {});
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
      _litHands.clear();
      _heldByPointer.clear();
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
          return Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (event) =>
                _onTapDown(event.pointer, event.localPosition, size),
            onPointerUp: (event) => _onTapUp(event.pointer),
            onPointerCancel: (event) => _onTapUp(event.pointer),
            child: Stack(
              fit: StackFit.expand,
              children: [
                RepaintBoundary(
                  child: CustomPaint(
                    painter: StagePainter(
                      chart: _session.chart,
                      beat: _session.beat,
                      windowInBeats: _session.windowInBeats,
                      litHands: Map.of(_litHands),
                      holding: _session.isHolding,
                      heldNotes: _session.heldNotes,
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
                    '${widget.song.composer} · ${widget.difficulty.label}',
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
