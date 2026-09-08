import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';

import 'pcm_output.dart';

PcmOutput createPcmOutput() => NativePcmOutput();

/// Audio on iOS, Android and macOS, through flutter_pcm_sound.
///
/// The plugin asks for samples whenever its queue runs low, so all this does
/// is render the next block on demand. The queue is kept short deliberately: a
/// note has to sound on the beat the player tapped, not a buffer later.
class NativePcmOutput implements PcmOutput {
  /// Samples per block — about 46 ms at 44.1 kHz.
  static const int _blockFrames = 2048;

  /// Refill once the queue drops below ~23 ms: low enough to stay responsive,
  /// high enough to survive a slow frame without an audible gap.
  static const int _feedThreshold = 1024;

  final Int16List _block = Int16List(_blockFrames);
  RenderCallback? _render;
  bool _running = false;

  @override
  bool get isSupported {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  @override
  Future<bool> start({
    required int sampleRate,
    required RenderCallback render,
  }) async {
    if (_running) return true;
    if (!isSupported) return false;
    _render = render;
    try {
      await FlutterPcmSound.setup(sampleRate: sampleRate, channelCount: 1);
      await FlutterPcmSound.setFeedThreshold(_feedThreshold);
      FlutterPcmSound.setFeedCallback(_onFeed);
      _running = true;
      FlutterPcmSound.start();
      return true;
    } catch (e) {
      debugPrint('PcmOutput: could not start audio: $e');
      _running = false;
      return false;
    }
  }

  void _onFeed(int remainingFrames) {
    if (!_running) return;
    _render!(_block);
    FlutterPcmSound.feed(PcmArrayInt16(bytes: _block.buffer.asByteData()));
  }

  @override
  Future<void> stop() async {
    if (!_running) return;
    _running = false;
    FlutterPcmSound.setFeedCallback(null);
    try {
      await FlutterPcmSound.release();
    } catch (e) {
      debugPrint('PcmOutput: release failed: $e');
    }
  }
}
