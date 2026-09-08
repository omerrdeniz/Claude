import 'pcm_output.dart';

/// Used on platforms with neither a native audio plugin nor a browser.
PcmOutput createPcmOutput() => _SilentOutput();

class _SilentOutput implements PcmOutput {
  @override
  bool get isSupported => false;

  @override
  Future<bool> start({required int sampleRate, required RenderCallback render}) async =>
      false;

  @override
  Future<void> stop() async {}
}
