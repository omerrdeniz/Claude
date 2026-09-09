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
///
/// Moving to an AudioWorklet was looked at and turned down. A worklet runs on
/// its own thread, but the synthesiser is Dart and stays on the main one, so
/// the samples still have to be handed across — and the two ways of doing
/// that both fail here. A SharedArrayBuffer needs the page to be
/// cross-origin isolated, which needs COOP and COEP response headers, which
/// GitHub Pages will not serve. Posting buffers to the worklet instead just
/// moves the same queue behind a message port: it still drains if the main
/// thread stalls, so it buys the robustness the change was for only by
/// making the queue deeper, which is latency again. The real version of that
/// change is rewriting the engine in JavaScript inside the worklet, which is
/// a different project.
///
/// The measurement that settled it: rendering one block with ten voices
/// sounding costs 155 µs against the 46 ms of audio it produces — about a
/// third of one per cent of real time. There is no CPU to win here.
class WebPcmOutput implements PcmOutput {
  /// 1024 frames is about 23 ms at 44.1 kHz, and this node's own share of the
  /// delay between a finger and a sound.
  ///
  /// It was 2048, halved once the recorded piano replaced the synthesiser:
  /// filling a block went from 664 µs to 155 µs, so servicing the callback
  /// twice as often is affordable where it was not before. What a smaller
  /// block cannot survive is the main thread stopping for longer than the
  /// block lasts — so if the sound crackles on a phone, this number going
  /// back up is the fix, at the price of the latency it buys.
  static const int _blockFrames = 1024;

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

  @override
  void nudge() {
    final context = _context;
    if (context == null) return;
    // Safari hands back a suspended context unless it is resumed from inside a
    // touch handler, and says nothing about it. Trying again on every tap
    // costs nothing and is the only thing that reliably works.
    if (context.state != 'running') context.resume();
  }

  @override
  double get latencyMs {
    final context = _context;
    if (context == null) return 0;

    // `baseLatency` is only what the audio graph buffers internally — a few
    // milliseconds. It says nothing about the trip from there to the speaker,
    // which on a phone is the part that matters: iOS runs well over a tenth
    // of a second, and Bluetooth headphones a good deal more than that.
    // Reading the wrong one made the game think it was fifty milliseconds
    // behind when it was three hundred, so every tap was judged late.
    //
    // `outputLatency` is the whole path and is defined to include the base,
    // but it is not everywhere and reads zero when it is missing.
    var path = context.outputLatency;
    if (!path.isFinite || path <= 0) path = context.baseLatency;
    // Nor trust an absurd figure: a second of latency is a broken reading,
    // and acting on it would be worse than ignoring it.
    if (!path.isFinite || path < 0 || path > 1.0) path = 0;

    // Our own node buffers a block on top of whatever the browser reports.
    return path * 1000 + _blockFrames / context.sampleRate * 1000;
  }

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
