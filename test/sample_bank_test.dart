import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:piano_flow/audio/piano_audio.dart';
import 'package:piano_flow/audio/sample_bank.dart';
import 'package:piano_flow/audio/synth_engine.dart';

/// Build a bank in the packed format, so the parser can be tested without the
/// two and a half megabyte asset.
Uint8List packed(Map<int, Int16List> notes, {int rate = 22050}) {
  final midis = notes.keys.toList()..sort();
  final out = BytesBuilder()
    ..add('PFPB'.codeUnits)
    ..addByte(1)
    ..add(Uint8List(4)..buffer.asByteData().setUint32(0, rate, Endian.little))
    ..add(Uint8List(2)
      ..buffer.asByteData().setUint16(0, midis.length, Endian.little));
  for (final midi in midis) {
    out.addByte(midi);
    out.add(Uint8List(4)
      ..buffer.asByteData().setUint32(0, notes[midi]!.length, Endian.little));
  }
  for (final midi in midis) {
    final data = notes[midi]!;
    out.add(Uint8List.view(data.buffer, data.offsetInBytes, data.lengthInBytes));
  }
  return out.toBytes();
}

/// A short buzz, loud enough to measure.
Int16List tone(int samples) =>
    Int16List.fromList([for (var i = 0; i < samples; i++) (i.isEven ? 8000 : -8000)]);

double rms(Int16List buffer) {
  var sum = 0.0;
  for (final s in buffer) {
    final v = s / 32768.0;
    sum += v * v;
  }
  return math.sqrt(sum / buffer.length);
}

double rmsOf(SynthEngine engine, int midi, {int frames = 44100}) {
  engine.panic();
  engine.noteOn(midi, velocity: 0.75);
  final out = Int16List(frames);
  engine.render(out);
  return rms(out);
}

void main() {
  group('parsing', () {
    test('reads back what the packer wrote', () {
      final bank = SampleBank.parse(packed({
        60: tone(100),
        72: tone(50),
      }));
      expect(bank.sampleRate, 22050);
      expect(bank.midis, [60, 72]);
      expect(bank.samples[0], hasLength(100));
      expect(bank.samples[1], hasLength(50));
    });

    test('refuses something that is not a bank', () {
      expect(() => SampleBank.parse(Uint8List.fromList('not a bank!!'.codeUnits)),
          throwsFormatException);
    });

    test('refuses a truncated bank rather than reading past the end', () {
      final full = packed({60: tone(100)});
      expect(() => SampleBank.parse(full.sublist(0, full.length - 40)),
          throwsFormatException);
    });

    test('picks the nearest recording to a pitch', () {
      final bank = SampleBank.parse(packed({
        60: tone(10),
        63: tone(10),
        66: tone(10),
      }));
      expect(bank.midis[bank.nearestTo(60)], 60);
      expect(bank.midis[bank.nearestTo(61)], 60);
      expect(bank.midis[bank.nearestTo(62)], 63);
      expect(bank.midis[bank.nearestTo(200)], 66, reason: 'clamps to the top');
      expect(bank.midis[bank.nearestTo(0)], 60, reason: 'clamps to the bottom');
    });
  });

  group('the engine plays recordings when it has them', () {
    test('and synthesises when it does not', () {
      final engine = SynthEngine();
      expect(engine.isSampled, isFalse);
      engine.samples = SampleBank.parse(packed({60: tone(4000)}));
      expect(engine.isSampled, isTrue);
    });

    test('an empty bank is not treated as one', () {
      final engine = SynthEngine()..samples = SampleBank.parse(packed({}));
      expect(engine.isSampled, isFalse,
          reason: 'an empty bank would leave every note silent');
    });

    test('a recorded note actually sounds', () {
      final engine = SynthEngine()
        ..samples = SampleBank.parse(packed({60: tone(22050)}));
      expect(rmsOf(engine, 60), greaterThan(0.01));
    });

    test('a note stops when its recording runs out', () {
      final engine = SynthEngine()
        // A tenth of a second at the bank rate.
        ..samples = SampleBank.parse(packed({60: tone(2205)}));
      engine.noteOn(60);
      engine.render(Int16List(44100)); // a whole second
      expect(engine.activeVoiceCount, 0);
    });

    test('panic silences a recorded note too', () {
      final engine = SynthEngine()
        ..samples = SampleBank.parse(packed({60: tone(44100)}));
      engine.noteOn(60);
      engine.panic();
      expect(engine.activeVoiceCount, 0);
      final out = Int16List(2048);
      engine.render(out);
      expect(rms(out), 0);
    });
  });

  group('the shipped piano', () {
    // Loaded from the repository rather than the asset bundle: this is the
    // same file the bundle carries, and reading it here catches a bank that
    // was never built or was built wrong.
    late SampleBank bank;

    setUpAll(() {
      final file = File(PianoAudio.samplesAsset);
      expect(file.existsSync(), isTrue,
          reason: 'run: dart run tool/fetch_samples.dart');
      bank = SampleBank.parse(file.readAsBytesSync());
    });

    test('covers the keyboard, one note every minor third', () {
      expect(bank.midis.first, lessThanOrEqualTo(21), reason: 'down to A0');
      expect(bank.midis.last, greaterThanOrEqualTo(105), reason: 'up to A7');
      for (var i = 1; i < bank.midis.length; i++) {
        expect(bank.midis[i] - bank.midis[i - 1], lessThanOrEqualTo(3),
            reason: 'nothing should be stretched more than a tone and a half');
      }
    });

    test('every note reaches every pitch the library asks for', () {
      // The widest song runs A1 to E7.
      for (var midi = 33; midi <= 100; midi++) {
        final index = bank.nearestTo(midi);
        expect((bank.midis[index] - midi).abs(), lessThanOrEqualTo(2));
      }
    });

    // This is the whole reason the recordings are here. A synthesised piano
    // gave the treble the same level as the middle of the keyboard, and a
    // piece that lives high came out piercing rather than bright.
    test('keeps a real piano falling away towards the treble', () {
      final engine = SynthEngine()..samples = bank;
      final middleC = rmsOf(engine, 60);

      double relative(int midi) =>
          20 * math.log(rmsOf(engine, midi) / middleC) / math.ln10;

      /// Averaged over a register, because the takes are uneven note to note
      /// — a real recording of a real instrument, struck by a real hand — and
      /// no single note carries the claim being made here.
      double over(int from, int to) {
        var sum = 0.0;
        var n = 0;
        for (var midi = from; midi <= to; midi++) {
          sum += relative(midi);
          n++;
        }
        return sum / n;
      }

      // Where Chopin's melody spends its time: C5 to B6.
      expect(over(72, 95), lessThan(-6));
      // And the top of its cadenza.
      expect(relative(99), lessThan(-14), reason: 'D sharp 7 against middle C');
      // The bass is not held back at all.
      expect(over(36, 55), greaterThan(-3));
    });

    test('is quieter up there than the synthesiser it replaces', () {
      final sampled = SynthEngine()..samples = bank;
      final synth = SynthEngine();
      double tilt(SynthEngine e) =>
          20 * math.log(rmsOf(e, 94) / rmsOf(e, 60)) / math.ln10;
      expect(tilt(sampled), lessThan(tilt(synth) - 3),
          reason: 'the recordings must lean further away from the treble');
    });
  });
}
