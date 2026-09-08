import 'dart:typed_data';

import 'note.dart';
import 'song.dart';

/// Reads a Standard MIDI File into a [Song].
///
/// This is what makes the song catalogue open-ended: any MIDI file the player
/// has becomes something they can play, with no licensing to negotiate.
///
/// Formats 0 (one track) and 1 (parallel tracks) are supported, which is
/// everything in practice. Format 2 — independent sequences that are not meant
/// to play together — is rejected rather than silently mangled.
class MidiReader {
  /// Parse [bytes] into a song.
  ///
  /// [fallbackTitle] is used when the file carries no track name.
  static Song read(
    Uint8List bytes, {
    String id = 'imported',
    String fallbackTitle = 'İsimsiz',
    String composer = '',
    String source = '',
  }) {
    final r = _Cursor(bytes);

    if (r.string(4) != 'MThd') {
      throw const FormatException('Not a MIDI file: missing MThd header');
    }
    final headerLength = r.uint32();
    if (headerLength < 6) {
      throw const FormatException('Corrupt MIDI header');
    }
    final format = r.uint16();
    final trackCount = r.uint16();
    final division = r.uint16();
    r.skip(headerLength - 6); // forward-compatible: ignore any extra header

    if (format == 2) {
      throw const FormatException(
          'MIDI format 2 is not supported: its tracks are separate sequences');
    }
    if (division & 0x8000 != 0) {
      // SMPTE timing measures absolute time, not beats, so there is no tempo
      // to follow — which is the whole point of this game.
      throw const FormatException('SMPTE-timed MIDI files are not supported');
    }
    if (division == 0) {
      throw const FormatException('Corrupt MIDI header: zero division');
    }

    final ticksPerBeat = division.toDouble();
    final notes = <Note>[];
    var bpm = 120.0;
    var sawTempo = false;
    String? title;
    var beatsPerBar = 4;
    // Tracks that actually carry notes, in file order — used to tell the hands
    // apart in the common two-staff arrangement.
    final noteTracks = <int>[];

    for (var track = 0; track < trackCount && !r.atEnd; track++) {
      if (r.string(4) != 'MTrk') {
        throw FormatException('Corrupt MIDI: track ${track + 1} has no MTrk');
      }
      final trackLength = r.uint32();
      final trackEnd = r.offset + trackLength;

      var tick = 0;
      var runningStatus = 0;
      // Sounding notes, keyed by channel and pitch, awaiting their note-off.
      final open = <int, List<_OpenNote>>{};

      while (r.offset < trackEnd && !r.atEnd) {
        tick += r.varInt();
        var status = r.uint8();

        if (status < 0x80) {
          // Running status: the event reuses the previous status byte, and
          // what we just read is really the first data byte.
          if (runningStatus == 0) {
            throw const FormatException('Corrupt MIDI: data before any status');
          }
          r.rewind(1);
          status = runningStatus;
        } else if (status < 0xF0) {
          runningStatus = status;
        }

        if (status == 0xFF) {
          final type = r.uint8();
          final length = r.varInt();
          switch (type) {
            case 0x03: // track name
              final name = r.string(length).trim();
              title ??= name.isEmpty ? null : name;
            case 0x51: // tempo, in microseconds per quarter note
              final micros = (r.uint8() << 16) | (r.uint8() << 8) | r.uint8();
              if (!sawTempo && micros > 0) {
                // Later tempo changes are ignored: beats are tempo-independent
                // and the game drives tempo itself.
                bpm = 60000000 / micros;
                sawTempo = true;
              }
            case 0x58: // time signature
              final numerator = r.uint8();
              r.skip(length - 1);
              if (numerator > 0) beatsPerBar = numerator;
            default:
              r.skip(length);
          }
          continue;
        }

        if (status == 0xF0 || status == 0xF7) {
          r.skip(r.varInt()); // sysex: nothing musical for us
          continue;
        }

        final command = status & 0xF0;
        final channel = status & 0x0F;

        switch (command) {
          case 0x90: // note on
            final pitch = r.uint8();
            final velocity = r.uint8();
            if (velocity > 0) {
              (open[channel] ??= []).add(
                  _OpenNote(pitch: pitch, tick: tick, velocity: velocity));
              if (!noteTracks.contains(track)) noteTracks.add(track);
            } else {
              // A note-on with zero velocity is a note-off; most files use it.
              _close(open[channel], pitch, tick, ticksPerBeat, track, notes);
            }
          case 0x80: // note off
            final pitch = r.uint8();
            r.uint8(); // release velocity, unused
            _close(open[channel], pitch, tick, ticksPerBeat, track, notes);
          case 0xA0: // aftertouch
          case 0xB0: // controller
          case 0xE0: // pitch bend
            r.skip(2);
          case 0xC0: // program change
          case 0xD0: // channel pressure
            r.skip(1);
          default:
            throw FormatException(
                'Corrupt MIDI: unknown status 0x${status.toRadixString(16)}');
        }
      }

      // A note still sounding at the end of the track was never released;
      // give it a beat rather than dropping it.
      for (final pending in open.values) {
        for (final note in pending) {
          notes.add(_build(note, tick + ticksPerBeat.round(), ticksPerBeat, track));
        }
      }

      r.seek(trackEnd);
    }

    if (notes.isEmpty) {
      throw const FormatException('This MIDI file contains no notes');
    }

    return Song(
      id: id,
      title: title ?? fallbackTitle,
      composer: composer,
      bpm: bpm,
      beatsPerBar: beatsPerBar,
      source: source,
      notes: _assignHands(notes, noteTracks),
    );
  }

  static void _close(List<_OpenNote>? pending, int pitch, int tick,
      double ticksPerBeat, int track, List<Note> out) {
    if (pending == null) return;
    // Close the oldest sounding copy, so a repeated pitch pairs up correctly.
    final index = pending.indexWhere((n) => n.pitch == pitch);
    if (index == -1) return;
    final note = pending.removeAt(index);
    out.add(_build(note, tick, ticksPerBeat, track));
  }

  static Note _build(
      _OpenNote note, int endTick, double ticksPerBeat, int track) {
    // A zero-length note would be inaudible; give it something to sound over.
    final ticks = (endTick - note.tick).clamp(1, 1 << 30);
    return _TrackedNote(
      track: track,
      note: Note(
        beat: note.tick / ticksPerBeat,
        midi: note.pitch,
        duration: ticks / ticksPerBeat,
        velocity: (note.velocity / 127).clamp(0.05, 1.0),
      ),
    );
  }

  /// Decide which hand plays what.
  ///
  /// A two-staff arrangement puts the hands on separate tracks, and that is by
  /// far the most reliable signal. Failing that — a format 0 file, or one
  /// track carrying everything — split by pitch, which is what a pianist
  /// reading from a single staff would do anyway.
  static List<Note> _assignHands(List<Note> notes, List<int> noteTracks) {
    final tracked = notes.cast<_TrackedNote>();

    if (noteTracks.length >= 2) {
      // The lower-sounding track is the left hand, whichever order it is in.
      final averagePitch = <int, double>{};
      for (final track in noteTracks) {
        final inTrack = tracked.where((t) => t.track == track);
        averagePitch[track] =
            inTrack.map((t) => t.note.midi).reduce((a, b) => a + b) /
                inTrack.length;
      }
      final lowest = averagePitch.entries
          .reduce((a, b) => a.value <= b.value ? a : b)
          .key;
      return [
        for (final t in tracked)
          t.note.copyWith(hand: t.track == lowest ? Hand.left : Hand.right),
      ];
    }

    final split = _splitPoint(tracked.map((t) => t.note.midi));
    return [
      for (final t in tracked)
        t.note.copyWith(hand: t.note.midi < split ? Hand.left : Hand.right),
    ];
  }

  /// Where to divide the hands: the median pitch, but never so far from middle
  /// C that one hand is left with almost nothing.
  static int _splitPoint(Iterable<int> pitches) {
    final sorted = pitches.toList()..sort();
    final median = sorted[sorted.length ~/ 2];
    return median.clamp(52, 67);
  }
}

/// A note-on waiting for its note-off.
class _OpenNote {
  _OpenNote({required this.pitch, required this.tick, required this.velocity});
  final int pitch;
  final int tick;
  final int velocity;
}

/// A parsed note that still remembers which track it came from, so hands can
/// be assigned once the whole file has been read.
class _TrackedNote implements Note {
  _TrackedNote({required this.track, required this.note});

  final int track;
  final Note note;

  @override
  double get beat => note.beat;
  @override
  int get midi => note.midi;
  @override
  double get duration => note.duration;
  @override
  double get velocity => note.velocity;
  @override
  Hand get hand => note.hand;
  @override
  double get endBeat => note.endBeat;

  @override
  Note copyWith({
    double? beat,
    int? midi,
    double? duration,
    double? velocity,
    Hand? hand,
  }) =>
      note.copyWith(
          beat: beat,
          midi: midi,
          duration: duration,
          velocity: velocity,
          hand: hand);
}

/// A byte reader over the file, tracking position for the variable-length
/// quantities MIDI is full of.
class _Cursor {
  _Cursor(this.bytes) : _data = ByteData.sublistView(bytes);

  final Uint8List bytes;
  final ByteData _data;
  int offset = 0;

  bool get atEnd => offset >= bytes.length;

  void _need(int count) {
    if (offset + count > bytes.length) {
      throw const FormatException('Corrupt MIDI: file ends mid-event');
    }
  }

  int uint8() {
    _need(1);
    return bytes[offset++];
  }

  int uint16() {
    _need(2);
    final v = _data.getUint16(offset, Endian.big);
    offset += 2;
    return v;
  }

  int uint32() {
    _need(4);
    final v = _data.getUint32(offset, Endian.big);
    offset += 4;
    return v;
  }

  String string(int length) {
    _need(length);
    final s = String.fromCharCodes(bytes, offset, offset + length);
    offset += length;
    return s;
  }

  /// MIDI's variable-length quantity: seven bits per byte, high bit continues.
  int varInt() {
    var value = 0;
    for (var i = 0; i < 4; i++) {
      final byte = uint8();
      value = (value << 7) | (byte & 0x7F);
      if (byte & 0x80 == 0) return value;
    }
    throw const FormatException('Corrupt MIDI: oversized variable-length value');
  }

  void skip(int count) {
    if (count < 0) throw const FormatException('Corrupt MIDI: negative length');
    _need(count);
    offset += count;
  }

  void rewind(int count) => offset -= count;

  void seek(int position) => offset = position;
}
