import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:piano_flow/music/midi_reader.dart';
import 'package:piano_flow/music/note.dart';

/// Assembles MIDI files byte by byte, so the reader is tested against real
/// encoded files rather than a mock.
class MidiFileBuilder {
  MidiFileBuilder({this.format = 0, this.ticksPerBeat = 480});

  final int format;
  final int ticksPerBeat;
  final List<List<int>> _tracks = [];

  /// MIDI's variable-length quantity encoding.
  static List<int> varInt(int value) {
    final out = [value & 0x7F];
    value >>= 7;
    while (value > 0) {
      out.insert(0, (value & 0x7F) | 0x80);
      value >>= 7;
    }
    return out;
  }

  void track(List<int> events) => _tracks.add(events);

  Uint8List build() {
    final out = <int>[
      ...'MThd'.codeUnits,
      0, 0, 0, 6,
      0, format,
      0, _tracks.length,
      ticksPerBeat >> 8, ticksPerBeat & 0xFF,
    ];
    for (final events in _tracks) {
      final body = [...events, 0x00, 0xFF, 0x2F, 0x00]; // end of track
      out.addAll('MTrk'.codeUnits);
      out.addAll([
        (body.length >> 24) & 0xFF,
        (body.length >> 16) & 0xFF,
        (body.length >> 8) & 0xFF,
        body.length & 0xFF,
      ]);
      out.addAll(body);
    }
    return Uint8List.fromList(out);
  }
}

List<int> noteOn(int delta, int pitch, {int velocity = 100, int channel = 0}) =>
    [...MidiFileBuilder.varInt(delta), 0x90 | channel, pitch, velocity];

List<int> noteOff(int delta, int pitch, {int channel = 0}) =>
    [...MidiFileBuilder.varInt(delta), 0x80 | channel, pitch, 0];

List<int> tempo(int bpm) {
  final micros = (60000000 / bpm).round();
  return [
    0x00, 0xFF, 0x51, 0x03,
    (micros >> 16) & 0xFF, (micros >> 8) & 0xFF, micros & 0xFF,
  ];
}

List<int> trackName(String name) =>
    [0x00, 0xFF, 0x03, name.length, ...name.codeUnits];

/// A single note, one beat long, starting at beat 0.
Uint8List oneNote({int pitch = 60, int ticksPerBeat = 480}) {
  final b = MidiFileBuilder(ticksPerBeat: ticksPerBeat);
  b.track([...noteOn(0, pitch), ...noteOff(ticksPerBeat, pitch)]);
  return b.build();
}

void main() {
  group('reading notes', () {
    test('reads a single note with the right pitch, onset and length', () {
      final song = MidiReader.read(oneNote(pitch: 64));
      expect(song.notes, hasLength(1));
      expect(song.notes.single.midi, 64);
      expect(song.notes.single.beat, 0);
      expect(song.notes.single.duration, 1.0);
    });

    test('ticks convert to beats regardless of the file resolution', () {
      for (final ticks in [96, 192, 480, 960]) {
        final song = MidiReader.read(oneNote(ticksPerBeat: ticks));
        expect(song.notes.single.duration, 1.0,
            reason: 'at $ticks ticks per beat');
      }
    });

    test('velocity is scaled to 0..1', () {
      final b = MidiFileBuilder();
      b.track([...noteOn(0, 60, velocity: 127), ...noteOff(480, 60)]);
      expect(MidiReader.read(b.build()).notes.single.velocity, 1.0);
    });

    test('notes struck together share an onset', () {
      final b = MidiFileBuilder();
      b.track([
        ...noteOn(0, 60), ...noteOn(0, 64), ...noteOn(0, 67),
        ...noteOff(480, 60), ...noteOff(0, 64), ...noteOff(0, 67),
      ]);
      final song = MidiReader.read(b.build());
      expect(song.notes, hasLength(3));
      expect(song.notes.every((n) => n.beat == 0), isTrue);
    });

    test('a note-on with zero velocity ends the note', () {
      final b = MidiFileBuilder();
      // The common encoding: note-on velocity 0 instead of a note-off.
      b.track([...noteOn(0, 60), ...noteOn(480, 60, velocity: 0)]);
      final song = MidiReader.read(b.build());
      expect(song.notes, hasLength(1));
      expect(song.notes.single.duration, 1.0);
    });

    test('running status is followed', () {
      final b = MidiFileBuilder();
      // Status byte given once, then two bare events reuse it.
      b.track([
        ...MidiFileBuilder.varInt(0), 0x90, 60, 100,
        ...MidiFileBuilder.varInt(480), 60, 0, // note off, running status
        ...MidiFileBuilder.varInt(0), 64, 100, // note on, running status
        ...MidiFileBuilder.varInt(480), 64, 0,
      ]);
      final song = MidiReader.read(b.build());
      expect(song.notes.map((n) => n.midi), [60, 64]);
      expect(song.notes.last.beat, 1.0);
    });

    test('long delta times are decoded', () {
      final b = MidiFileBuilder();
      // 1920 ticks needs a multi-byte variable-length quantity.
      b.track([...noteOn(1920, 60), ...noteOff(480, 60)]);
      expect(MidiReader.read(b.build()).notes.single.beat, 4.0);
    });

    test('a note left sounding at the end still gets a length', () {
      final b = MidiFileBuilder();
      b.track(noteOn(0, 60)); // never released
      final song = MidiReader.read(b.build());
      expect(song.notes, hasLength(1));
      expect(song.notes.single.duration, greaterThan(0));
    });

    test('repeated pitches pair with the right note-off', () {
      final b = MidiFileBuilder();
      b.track([
        ...noteOn(0, 60),
        ...noteOn(240, 60), // struck again while the first still sounds
        ...noteOff(240, 60),
        ...noteOff(240, 60),
      ]);
      final song = MidiReader.read(b.build());
      expect(song.notes, hasLength(2));
      expect(song.notes.map((n) => n.beat), [0.0, 0.5]);
    });

    test('control, pitch bend and program changes are stepped over', () {
      final b = MidiFileBuilder();
      b.track([
        0x00, 0xB0, 0x07, 0x64, // controller: volume
        0x00, 0xC0, 0x00, // program change
        0x00, 0xE0, 0x00, 0x40, // pitch bend
        ...noteOn(0, 60), ...noteOff(480, 60),
      ]);
      expect(MidiReader.read(b.build()).notes, hasLength(1));
    });
  });

  group('metadata', () {
    test('tempo is read from the file', () {
      final b = MidiFileBuilder();
      b.track([...tempo(90), ...noteOn(0, 60), ...noteOff(480, 60)]);
      expect(MidiReader.read(b.build()).bpm, closeTo(90, 0.01));
    });

    test('a file without a tempo defaults to 120', () {
      expect(MidiReader.read(oneNote()).bpm, 120);
    });

    test('the track name becomes the title', () {
      final b = MidiFileBuilder();
      b.track([...trackName('Gymnopédie'), ...noteOn(0, 60), ...noteOff(480, 60)]);
      expect(MidiReader.read(b.build()).title, 'Gymnopédie');
    });

    test('an unnamed file falls back to the given title', () {
      expect(MidiReader.read(oneNote(), fallbackTitle: 'Adsız').title, 'Adsız');
    });

    test('the time signature sets the bar length', () {
      final b = MidiFileBuilder();
      b.track([
        0x00, 0xFF, 0x58, 0x04, 3, 2, 24, 8, // 3/4
        ...noteOn(0, 60), ...noteOff(480, 60),
      ]);
      expect(MidiReader.read(b.build()).beatsPerBar, 3);
    });
  });

  group('assigning hands', () {
    test('two tracks split into two hands, the lower one left', () {
      final b = MidiFileBuilder(format: 1);
      b.track([...noteOn(0, 72), ...noteOff(480, 72)]); // treble
      b.track([...noteOn(0, 40), ...noteOff(480, 40)]); // bass
      final song = MidiReader.read(b.build());
      expect(song.melody.single.midi, 72);
      expect(song.accompaniment.single.midi, 40);
    });

    test('track order does not decide the hand, pitch does', () {
      final b = MidiFileBuilder(format: 1);
      b.track([...noteOn(0, 40), ...noteOff(480, 40)]); // bass written first
      b.track([...noteOn(0, 72), ...noteOff(480, 72)]);
      final song = MidiReader.read(b.build());
      expect(song.accompaniment.single.midi, 40);
    });

    test('a single track is split by pitch', () {
      final b = MidiFileBuilder();
      b.track([
        ...noteOn(0, 36), ...noteOn(0, 43), ...noteOn(0, 72), ...noteOn(0, 79),
        ...noteOff(480, 36), ...noteOff(0, 43),
        ...noteOff(0, 72), ...noteOff(0, 79),
      ]);
      final song = MidiReader.read(b.build());
      expect(song.accompaniment.map((n) => n.midi), [36, 43]);
      expect(song.melody.map((n) => n.midi), [72, 79]);
    });
  });

  group('rejecting bad input', () {
    test('a file that is not MIDI', () {
      expect(
        () => MidiReader.read(Uint8List.fromList('not a midi file'.codeUnits)),
        throwsA(isA<FormatException>()),
      );
    });

    test('format 2, whose tracks are separate sequences', () {
      final b = MidiFileBuilder(format: 2);
      b.track([...noteOn(0, 60), ...noteOff(480, 60)]);
      expect(() => MidiReader.read(b.build()),
          throwsA(isA<FormatException>()));
    });

    test('SMPTE timing, which has no beats to follow', () {
      final bytes = Uint8List.fromList([
        ...'MThd'.codeUnits, 0, 0, 0, 6, 0, 0, 0, 1,
        0xE7, 0x28, // negative division: SMPTE
      ]);
      expect(() => MidiReader.read(bytes), throwsA(isA<FormatException>()));
    });

    test('a file with no notes', () {
      final b = MidiFileBuilder();
      b.track(tempo(120));
      expect(() => MidiReader.read(b.build()),
          throwsA(isA<FormatException>()));
    });

    test('a file that ends mid-event', () {
      final full = oneNote();
      expect(
        () => MidiReader.read(full.sublist(0, full.length - 6)),
        throwsA(isA<FormatException>()),
      );
    });
  });

  test('notes come back sorted by time', () {
    final b = MidiFileBuilder();
    b.track([
      ...noteOn(0, 60), ...noteOff(240, 60),
      ...noteOn(0, 64), ...noteOff(240, 64),
      ...noteOn(0, 67), ...noteOff(240, 67),
    ]);
    final song = MidiReader.read(b.build());
    final beats = song.notes.map((n) => n.beat).toList();
    expect(beats, [...beats]..sort());
    expect(song.notes.every((n) => n.hand == Hand.right || n.hand == Hand.left),
        isTrue);
  });
}
