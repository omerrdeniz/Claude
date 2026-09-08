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

  Future<void> stop();
}
