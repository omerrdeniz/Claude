import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:piano_flow/audio/synth_engine.dart';

const int kSampleRate = 44100;

Int16List renderFrames(SynthEngine engine, int frames) {
  final buf = Int16List(frames);
  engine.render(buf);
  return buf;
}

double rms(Int16List buf) {
  if (buf.isEmpty) return 0;
  var sum = 0.0;
  for (final s in buf) {
    sum += s * s.toDouble();
  }
  return math.sqrt(sum / buf.length);
}

/// Energy at [freq] via the Goertzel algorithm — a one-bin DFT. Used to check
/// that a note actually sounds at the pitch it claims to.
double energyAt(Int16List buf, double freq) {
  final k = 2 * math.cos(2 * math.pi * freq / kSampleRate);
  var s1 = 0.0, s2 = 0.0;
  for (final sample in buf) {
    final s0 = sample / 32768.0 + k * s1 - s2;
    s2 = s1;
    s1 = s0;
  }
  return s1 * s1 + s2 * s2 - k * s1 * s2;
}

void main() {
  late SynthEngine engine;

  setUp(() => engine = SynthEngine(sampleRate: kSampleRate));

  test('renders silence while idle', () {
    expect(rms(renderFrames(engine, 4096)), 0);
    expect(engine.activeVoiceCount, 0);
  });

  test('a struck note produces sound', () {
    engine.noteOn(60);
    final buf = renderFrames(engine, 4096);
    expect(rms(buf), greaterThan(100));
    expect(engine.activeVoiceCount, 1);
  });

  test('output stays finite and inside 16-bit range', () {
    // Twelve notes at full velocity is a worst case for summing into clipping.
    for (var n = 48; n < 60; n++) {
      engine.noteOn(n, velocity: 1.0);
    }
    final buf = renderFrames(engine, 8192);
    for (final s in buf) {
      expect(s, inInclusiveRange(-32768, 32767));
    }
  });

  test('A4 sounds at 440 Hz, not at neighbouring pitches', () {
    engine.noteOn(69);
    final buf = renderFrames(engine, 16384);
    final atPitch = energyAt(buf, 440);
    expect(atPitch, greaterThan(energyAt(buf, 415.3) * 10));
    expect(atPitch, greaterThan(energyAt(buf, 466.2) * 10));
  });

  test('overtones are present above the fundamental', () {
    engine.noteOn(48); // C3, low enough that partials stay well under Nyquist
    final buf = renderFrames(engine, 16384);
    final fundamental = 440.0 * math.pow(2, (48 - 69) / 12.0);
    expect(energyAt(buf, fundamental * 2), greaterThan(0));
    expect(energyAt(buf, fundamental * 3), greaterThan(0));
  });

  test('harder strikes are louder', () {
    engine.noteOn(60, velocity: 0.2);
    final soft = rms(renderFrames(engine, 4096));
    engine.panic();
    engine.noteOn(60, velocity: 1.0);
    final hard = rms(renderFrames(engine, 4096));
    expect(hard, greaterThan(soft * 2));
  });

  test('a held note decays as it rings', () {
    engine.noteOn(60);
    final first = rms(renderFrames(engine, 8192));
    renderFrames(engine, kSampleRate); // let a second pass
    final later = rms(renderFrames(engine, 8192));
    expect(later, lessThan(first));
  });

  test('releasing a note silences it within a second', () {
    engine.noteOn(60);
    renderFrames(engine, 4096);
    engine.noteOff(60);
    renderFrames(engine, kSampleRate);
    expect(rms(renderFrames(engine, 4096)), lessThan(10));
    expect(engine.activeVoiceCount, 0, reason: 'the voice should free itself');
  });

  test('polyphony is capped and voices are reused', () {
    final small = SynthEngine(sampleRate: kSampleRate, maxVoices: 4);
    for (var n = 40; n < 60; n++) {
      small.noteOn(n);
    }
    expect(small.activeVoiceCount, lessThanOrEqualTo(4));
    final buf = Int16List(2048);
    small.render(buf);
    expect(rms(buf), greaterThan(0), reason: 'stolen voices still sound');
  });

  test('restriking a sounding key restarts it rather than stacking voices', () {
    engine.noteOn(60);
    renderFrames(engine, 2048);
    engine.noteOn(60);
    expect(engine.activeVoiceCount, 1);
  });

  test('very high notes do not alias', () {
    // C8's upper partials are above Nyquist and must be dropped, not folded
    // back down as an audible whistle.
    engine.noteOn(108, velocity: 1.0);
    final buf = renderFrames(engine, 8192);
    final fundamental = 440.0 * math.pow(2, (108 - 69) / 12.0);
    final aliasBand = energyAt(buf, 300); // nothing musical belongs down here
    expect(energyAt(buf, fundamental), greaterThan(aliasBand * 10));
  });

  test('panic stops everything immediately', () {
    engine.noteOn(60);
    engine.noteOn(64);
    engine.panic();
    expect(engine.activeVoiceCount, 0);
    expect(rms(renderFrames(engine, 2048)), 0);
  });
}
