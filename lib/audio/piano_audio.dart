import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'pcm_output.dart';
import 'sample_bank.dart';
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

  /// Where the recorded piano lives.
  static const String samplesAsset = 'assets/piano/salamander.bin';

  /// Load the recorded piano, so notes are played rather than synthesised.
  ///
  /// Safe to call more than once, and safe to not call at all: until it
  /// finishes — and for good if the asset cannot be read — the synthesiser
  /// plays instead, so the game is never silent waiting for it. Returns
  /// whether the recordings are in use.
  ///
  /// It is deliberately not awaited by anything on the way into a song. Two
  /// and a half megabytes is a moment on a phone and rather longer on a first
  /// web visit, and a piano that improves a second in is better than a song
  /// that will not start.
  Future<bool> loadSamples() async {
    if (engine.isSampled) return true;
    final bank = await _sharedBank();
    if (bank == null) return false;
    engine.samples = bank;
    return true;
  }

  /// The parsed bank, read once and shared by every session after.
  ///
  /// A new [PianoAudio] is built for each song, and re-reading two and a half
  /// megabytes on every press of a title would be a stutter for nothing.
  static SampleBank? _bank;
  static Future<SampleBank?>? _loading;

  static Future<SampleBank?> _sharedBank() {
    if (_bank != null) return Future.value(_bank);
    return _loading ??= () async {
      try {
        final data = await rootBundle.load(samplesAsset);
        return _bank = SampleBank.parse(data.buffer
            .asUint8List(data.offsetInBytes, data.lengthInBytes));
      } catch (error) {
        // A missing or unreadable bank is not worth failing over: it costs
        // tone, not the game.
        debugPrint('PianoAudio: recorded piano unavailable ($error)');
        _loading = null;
        return null;
      }
    }();
  }

  /// Give audio a chance to start from inside a user gesture — see
  /// [PcmOutput.nudge].
  void nudge() {
    if (!_running) {
      start();
      return;
    }
    _output.nudge();
  }

  /// How far behind the player's ear is, in milliseconds.
  double get latencyMs => _running ? _output.latencyMs : 0;

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
