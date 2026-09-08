import 'dart:js_interop';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import 'pcm_output.dart';

PcmOutput createPcmOutput() => WebPcmOutput();

/// Audio in the browser, through the Web Audio API.
///
/// This exists so the game can be tried from a link, with no installation —
/// which on iPhone is the only way to get it onto a device without a Mac and
/// an Apple developer account.
///
/// It uses a ScriptProcessorNode. That node is deprecated in favour of
/// AudioWorklet, but it is the only one that works in every mobile browser
/// today without shipping a separate worklet module, and it runs on the main
/// thread where Dart code can reach it. The cost is latency — roughly a block
/// of it — which is why the block is kept as small as the browser will bear.
class WebPcmOutput implements PcmOutput {
  /// 2048 frames is about 46 ms at 44.1 kHz. Smaller starts to crackle on
  /// phones, since this node shares the main thread with rendering.
  static const int _blockFrames = 2048;

  web.AudioContext? _context;
  web.ScriptProcessorNode? _node;
  RenderCallback? _render;

  final Int16List _block = Int16List(_blockFrames);
  final Float32List _floats = Float32List(_blockFrames);

  @override
  bool get isSupported => true;

  @override
  Future<bool> start({
    required int sampleRate,
    required RenderCallback render,
  }) async {
    if (_context != null) return true;
    _render = render;
    try {
      // The browser picks its own rate; the synthesiser is told to match it
      // rather than resampling, so pitches stay true.
      final context = web.AudioContext();
      final node = context.createScriptProcessor(_blockFrames, 0, 1);
      node.onaudioprocess = _onAudioProcess.toJS;
      node.connect(context.destination);

      _context = context;
      _node = node;

      // Browsers start an audio context suspended until the page has been
      // interacted with; on iOS this is enforced strictly.
      await context.resume().toDart;
      return true;
    } catch (e) {
      debugPrint('PcmOutput: could not start web audio: $e');
      return false;
    }
  }

  /// The context's own sample rate, which the synthesiser must be built at.
  int? get sampleRate => _context?.sampleRate.round();

  void _onAudioProcess(web.AudioProcessingEvent event) {
    final render = _render;
    if (render == null) return;

    render(_block);
    for (var i = 0; i < _blockFrames; i++) {
      _floats[i] = _block[i] / 32768.0;
    }
    event.outputBuffer.copyToChannel(_floats.toJS, 0);
  }

  @override
  Future<void> stop() async {
    _node?.disconnect();
    _node = null;
    final context = _context;
    _context = null;
    if (context != null) await context.close().toDart;
  }
}
