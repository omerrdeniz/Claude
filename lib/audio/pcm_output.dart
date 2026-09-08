import 'dart:typed_data';

import 'pcm_output_stub.dart'
    if (dart.library.io) 'pcm_output_native.dart'
    if (dart.library.js_interop) 'pcm_output_web.dart';

/// Fills [buffer] with the next block of mono 16-bit samples.
typedef RenderCallback = void Function(Int16List buffer);

/// Somewhere to send audio.
///
/// The synthesiser is the same everywhere; only the way samples reach the
/// speaker differs. Keeping that difference behind this one interface is what
/// lets the game run on a phone and in a browser from the same code.
abstract class PcmOutput {
  /// The output for the platform this build is running on.
  factory PcmOutput() => createPcmOutput();

  /// Whether audio can work here at all.
  bool get isSupported;

  /// Open the device and begin pulling samples from [render].
  ///
  /// Returns false if audio is unavailable, so the caller can carry on
  /// silently instead of failing.
  Future<bool> start({required int sampleRate, required RenderCallback render});

  /// Called from inside a user gesture.
  ///
  /// Browsers — iOS Safari strictly — will only let audio begin from a real
  /// touch, and silently ignore any attempt made outside one. Since the game
  /// opens its playfield from a tap and starts audio a moment later, that
  /// attempt lands after the gesture has ended; this hook is how the first tap
  /// on the playfield gets a second chance.
  void nudge() {}

  /// Delay between a sample being rendered and being heard, in milliseconds.
  ///
  /// It is what the judging has to be shifted by, or every tap reads late.
  double get latencyMs => 0;

  Future<void> stop();
}
