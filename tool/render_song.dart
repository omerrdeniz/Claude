// Plays a song from the library through the synthesiser and writes it to WAV,
// so song data can be checked by ear — the only way to catch a wrong note.
//
//   dart run tool/render_song.dart fur-elise [output.wav]
//   dart run tool/render_song.dart --list

import 'dart:io';
import 'dart:typed_data';

import 'package:piano_flow/audio/synth_engine.dart';
import 'package:piano_flow/data/song_library.dart';
import 'package:piano_flow/music/song.dart';

import 'wav.dart';

const int sampleRate = 44100;

void main(List<String> args) {
  if (args.isEmpty || args.first == '--list') {
    stdout.writeln('Şarkılar:');
    for (final song in SongLibrary.all) {
      stdout.writeln('  ${song.id.padRight(14)} ${song.title} — $song');
    }
    return;
  }

  final song = SongLibrary.byId(args.first);
  if (song == null) {
    stderr.writeln('Bilinmeyen şarkı: ${args.first}');
    exit(1);
  }

  final path = args.length > 1 ? args[1] : '${song.id}.wav';
  writeWav(path, render(song), sampleRate: sampleRate);
  stdout.writeln('wrote $path — $song');
}

/// Render a whole song, sample accurately: audio is generated in chunks that
/// run right up to each note event, so onsets land where the data says.
List<int> render(Song song, {double tailSeconds = 3.0}) {
  final engine = SynthEngine(sampleRate: sampleRate);
  final secondsPerBeat = 60.0 / song.bpm;

  final events = <_Event>[];
  for (final note in song.notes) {
    events.add(_Event(note.beat * secondsPerBeat, true, note.midi, note.velocity));
    events.add(_Event(note.endBeat * secondsPerBeat, false, note.midi, 0));
  }
  // Releases before strikes at the same instant, so a repeated pitch is
  // damped and then struck again rather than the other way round.
  events.sort((a, b) =>
      a.time != b.time ? a.time.compareTo(b.time) : (a.isOn ? 1 : -1));

  final out = <int>[];
  var renderedSamples = 0;

  void renderUntil(double time) {
    final target = (time * sampleRate).round();
    final frames = target - renderedSamples;
    if (frames <= 0) return;
    final buf = Int16List(frames);
    engine.render(buf);
    out.addAll(buf);
    renderedSamples = target;
  }

  for (final event in events) {
    renderUntil(event.time);
    if (event.isOn) {
      engine.noteOn(event.midi, velocity: event.velocity);
    } else {
      engine.noteOff(event.midi);
    }
  }
  renderUntil(renderedSamples / sampleRate + tailSeconds);
  return out;
}

class _Event {
  _Event(this.time, this.isOn, this.midi, this.velocity);
  final double time;
  final bool isOn;
  final int midi;
  final double velocity;
}
