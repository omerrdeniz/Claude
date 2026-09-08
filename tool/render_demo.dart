// Renders a demo of the synthesiser to a WAV file, so the sound can be
// auditioned without building the app onto a phone.
//
//   dart run tool/render_demo.dart [output.wav]

import 'dart:io';
import 'dart:typed_data';

import 'package:piano_flow/audio/synth_engine.dart';

import 'wav.dart';

const int sampleRate = 44100;

void main(List<String> args) {
  final path = args.isNotEmpty ? args.first : 'piano_flow_demo.wav';
  final engine = SynthEngine(sampleRate: sampleRate);
  final out = <int>[];

  /// Render [seconds] of audio, appending to the output.
  void run(double seconds) {
    final buf = Int16List((sampleRate * seconds).round());
    engine.render(buf);
    out.addAll(buf);
  }

  // 1. The same key struck softly, then harder, then hard: velocity should
  //    read as a change of colour, not only of volume.
  for (final v in [0.15, 0.45, 1.0]) {
    engine.noteOn(60, velocity: v);
    run(1.3);
  }
  run(0.4);

  // 2. Register: the bottom of the piano should ring far longer than the top.
  engine.noteOn(28, velocity: 0.85);
  run(2.2);
  engine.noteOn(96, velocity: 0.85);
  run(1.4);

  // 3. A chord, held and then released — the damper should cut it short.
  for (final n in [48, 55, 64, 67, 72]) {
    engine.noteOn(n, velocity: 0.7);
  }
  run(2.4);
  for (final n in [48, 55, 64, 67, 72]) {
    engine.noteOff(n);
  }
  run(0.8);

  // 4. A melody, to hear it play rather than demonstrate. Beethoven's
  //    Für Elise, opening bars — public domain.
  const melody = <(int, double)>[
    (76, 0.18), (75, 0.18), (76, 0.18), (75, 0.18), (76, 0.18),
    (71, 0.18), (74, 0.18), (72, 0.18), (69, 0.55),
    (45, 0.18), (52, 0.18), (57, 0.18), (60, 0.55),
    (52, 0.18), (56, 0.18), (64, 0.18), (65, 0.55),
    (52, 0.18), (76, 0.18), (75, 0.18), (76, 0.18), (75, 0.18),
    (76, 0.18), (71, 0.18), (74, 0.18), (72, 0.18), (69, 0.9),
  ];
  for (final (note, dur) in melody) {
    engine.noteOn(note, velocity: note < 62 ? 0.55 : 0.75);
    run(dur);
  }
  run(2.5);

  writeWav(path, out, sampleRate: sampleRate);
  final seconds = (out.length / sampleRate).toStringAsFixed(1);
  stdout.writeln('wrote $path — ${seconds}s, ${out.length} samples');
}
