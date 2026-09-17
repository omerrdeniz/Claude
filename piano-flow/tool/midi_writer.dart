// Writes a hand-written arrangement out as MIDI.
//
// The library's songs arrive as MIDI, whether they were engraved by somebody
// else or written here — so an arrangement of our own becomes a song by
// taking the same road as the rest, not a shortcut past it. Everything
// downstream (hand assignment, tempo, metre, the chart) then reads it the way
// it reads a Chopin edition.
library;

import 'dart:typed_data';

import 'package:piano_flow/music/note.dart';

const _ticksPerBeat = 480;

/// One MIDI file: a tempo track, then a track per hand.
///
/// Two note tracks rather than one, because that is how the reader tells the
/// hands apart — it takes the lower-sounding track as the left.
Uint8List writeMidi({
  required List<Note> right,
  required List<Note> left,
  required double bpm,
  required int beatsPerBar,
}) {
  final out = BytesBuilder();
  out.add(_chunk('MThd', [0, 1, 0, 3, _ticksPerBeat >> 8, _ticksPerBeat & 0xff]));
  out.add(_chunk('MTrk', _tempoTrack(bpm, beatsPerBar)));
  out.add(_chunk('MTrk', _noteTrack(right)));
  out.add(_chunk('MTrk', _noteTrack(left)));
  return out.toBytes();
}

List<int> _chunk(String tag, List<int> body) => [
      ...tag.codeUnits,
      body.length >> 24 & 0xff,
      body.length >> 16 & 0xff,
      body.length >> 8 & 0xff,
      body.length & 0xff,
      ...body,
    ];

List<int> _tempoTrack(double bpm, int beatsPerBar) {
  final usPerBeat = (60000000 / bpm).round();
  return [
    0, 0xff, 0x51, 0x03,
    usPerBeat >> 16 & 0xff, usPerBeat >> 8 & 0xff, usPerBeat & 0xff,
    // Denominator as a power of two: 2 is a quarter, which is what a beat is
    // here. A piece felt in eighths says so with beatsPerQuarter, not here.
    0, 0xff, 0x58, 0x04, beatsPerBar, 2, 24, 8,
    0, 0xff, 0x2f, 0x00,
  ];
}

List<int> _noteTrack(List<Note> notes) {
  // One list of (tick, on/off) events, sorted, then written as deltas. Note
  // offs go before note ons at the same tick so a repeated pitch is released
  // before it is struck again.
  final events = <({int tick, bool on, int midi, int velocity})>[];
  for (final note in notes) {
    final start = (note.beat * _ticksPerBeat).round();
    final end = (note.endBeat * _ticksPerBeat).round();
    final velocity = (note.velocity * 127).round().clamp(1, 127);
    events.add((tick: start, on: true, midi: note.midi, velocity: velocity));
    events.add((tick: end, on: false, midi: note.midi, velocity: 0));
  }
  events.sort((a, b) {
    final byTick = a.tick.compareTo(b.tick);
    if (byTick != 0) return byTick;
    if (a.on != b.on) return a.on ? 1 : -1;
    return a.midi.compareTo(b.midi);
  });

  final body = <int>[];
  var previous = 0;
  for (final event in events) {
    body.addAll(_vlq(event.tick - previous));
    body.addAll([event.on ? 0x90 : 0x80, event.midi, event.velocity]);
    previous = event.tick;
  }
  body.addAll([0, 0xff, 0x2f, 0x00]);
  return body;
}

/// MIDI's variable-length quantity: seven bits a byte, high bit says more.
List<int> _vlq(int value) {
  if (value < 0) throw ArgumentError('Negative delta: $value');
  final bytes = [value & 0x7f];
  var rest = value >> 7;
  while (rest > 0) {
    bytes.insert(0, (rest & 0x7f) | 0x80);
    rest >>= 7;
  }
  return bytes;
}
