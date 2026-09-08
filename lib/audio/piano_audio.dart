import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';

import 'synth_engine.dart';

/// Connects [SynthEngine] to the device speaker.
///
/// The plugin asks for samples through a callback whenever its queue runs low,
/// so all this class does is render the next block on demand. Keeping the
/// buffer small is what keeps the game feeling responsive: a note has to sound
/// on the same beat the player taps, not a queue length later.
class PianoAudio {
  PianoAudio({SynthEngine? engine, this.sampleRate = 44100})
      : engine = engine ?? SynthEngine(sampleRate: 44100);

  final SynthEngine engine;
  final int sampleRate;

  /// Samples rendered per callback. ~46 ms at 44.1 kHz.
  static const int _blockFrames = 2048;

  /// Refill once the queue drops below ~23 ms. Low enough to stay responsive,
  /// high enough to survive a slow frame without an audible gap.
  static const int _feedThreshold = 1024;

  final Int16List _block = Int16List(_blockFrames);

  bool _running = false;
  bool get isRunning => _running;

  /// True on the platforms flutter_pcm_sound supports.
  static bool get isSupported {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  /// Open the audio device and begin streaming.
  ///
  /// Returns false when audio is unavailable — on an unsupported platform, or
  /// if the device refuses the session — so callers can degrade instead of
  /// crashing. The game stays playable without sound; it just isn't much fun.
  Future<bool> start() async {
    if (_running) return true;
    if (!isSupported) return false;
    try {
      await FlutterPcmSound.setup(sampleRate: sampleRate, channelCount: 1);
      await FlutterPcmSound.setFeedThreshold(_feedThreshold);
      FlutterPcmSound.setFeedCallback(_onFeed);
      _running = true;
      FlutterPcmSound.start();
      return true;
    } catch (e) {
      debugPrint('PianoAudio: could not start audio: $e');
      _running = false;
      return false;
    }
  }

  void _onFeed(int remainingFrames) {
    if (!_running) return;
    engine.render(_block);
    FlutterPcmSound.feed(PcmArrayInt16(bytes: _block.buffer.asByteData()));
  }

  void noteOn(int midi, {double velocity = 0.8}) =>
      engine.noteOn(midi, velocity: velocity);

  void noteOff(int midi) => engine.noteOff(midi);

  Future<void> dispose() async {
    if (!_running) return;
    _running = false;
    engine.panic();
    FlutterPcmSound.setFeedCallback(null);
    try {
      await FlutterPcmSound.release();
    } catch (e) {
      debugPrint('PianoAudio: release failed: $e');
    }
  }
}
