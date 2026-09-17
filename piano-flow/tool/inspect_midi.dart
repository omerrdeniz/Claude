import 'dart:io';
import 'dart:typed_data';

import 'package:piano_flow/music/midi_reader.dart';
import 'package:piano_flow/music/notation.dart';
import 'package:piano_flow/music/note.dart';

/// Dump a MIDI file bar by bar, so it can be read against a score.
void main(List<String> args) {
  final bytes = Uint8List.fromList(File(args[0]).readAsBytesSync());
  final song = MidiReader.read(bytes);
  // How many MIDI quarter-beats make one written bar.
  final quartersPerBar = double.parse(args.length > 1 ? args[1] : '4');
  final from = args.length > 2 ? int.parse(args[2]) : 0;
  final to = args.length > 3 ? int.parse(args[3]) : 1 << 30;

  stdout.writeln('bpm=${song.bpm} notes=${song.notes.length} '
      'quarters=${song.lengthInBeats} bars=${song.lengthInBeats / quartersPerBar}');

  final byBar = <int, List<Note>>{};
  for (final n in song.notes) {
    byBar.putIfAbsent((n.beat / quartersPerBar).floor(), () => []).add(n);
  }
  final bars = byBar.keys.toList()..sort();
  for (final bar in bars.where((b) => b >= from && b <= to)) {
    final right = byBar[bar]!.where((n) => n.hand == Hand.right);
    final left = byBar[bar]!.where((n) => n.hand == Hand.left);
    String show(Iterable<Note> ns) => ns
        .map((n) =>
            '${midiToNote(n.midi)}@${(n.beat - bar * quartersPerBar).toStringAsFixed(2)}')
        .join(' ');
    stdout.writeln('bar ${bar + 1}');
    if (right.isNotEmpty) stdout.writeln('   R ${show(right)}');
    if (left.isNotEmpty) stdout.writeln('   L ${show(left)}');
  }
}
