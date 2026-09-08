import 'package:flutter/foundation.dart';

import 'pcm_output.dart';
import 'synth_engine.dart';

/// Connects [SynthEngine] to whatever the platform uses for a speaker.
///
/// The synthesiser and the game know nothing about how sound leaves the
/// device; that lives behind [PcmOutput], so the same game runs on a phone and
/// in a browser.
class PianoAudio {
  PianoAudio({SynthEngine? engine, this.sampleRate = 44100, PcmOutput? output})
      : engine = engine ?? SynthEngine(sampleRate: 44100),
        _output = output ?? PcmOutput();

  final SynthEngine engine;
  final int sampleRate;
  final PcmOutput _output;

  bool _running = false;
  bool get isRunning => _running;

  /// Whether sound can work on this platform at all.
  bool get isSupported => _output.isSupported;

  /// Open the audio device and begin streaming.
  ///
  /// Returns false when audio is unavailable, so callers can degrade instead
  /// of crashing. The game stays playable without sound; it just isn't much
  /// fun.
  Future<bool> start() async {
    if (_running) return true;
    _running = await _output.start(sampleRate: sampleRate, render: engine.render);
    if (!_running) debugPrint('PianoAudio: no audio on this platform');
    return _running;
  }

  void noteOn(int midi, {double velocity = 0.8}) =>
      engine.noteOn(midi, velocity: velocity);

  void noteOff(int midi) => engine.noteOff(midi);

  Future<void> dispose() async {
    if (!_running) return;
    _running = false;
    engine.panic();
    await _output.stop();
  }
}
