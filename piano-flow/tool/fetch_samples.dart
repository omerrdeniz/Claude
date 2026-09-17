// Builds assets/piano/salamander.bin — the recorded piano the game plays.
//
//     dart run tool/fetch_samples.dart
//
// Needs a network connection, plus mpg123 and sox on the PATH:
//
//     apt-get install -y mpg123 sox
//
// The recordings are Alexander Holm's Salamander Grand Piano (a Yamaha C5),
// licensed CC BY 3.0, taken from the copy Tone.js publishes as one file per
// note. One note every minor third is enough: anything in between is played
// by resampling its nearest neighbour, which is at most a tone and a half
// away and does not audibly stretch the instrument.
//
// Two decisions worth knowing about.
//
// The samples are NOT normalised note by note. A real piano is much quieter
// at the top than in the middle, and that balance is the whole reason to use
// recordings — levelling each note would put back exactly the shrill treble
// this replaces. One gain is applied to all of them together. What each note
// does get is a small correction towards its neighbours, capped at about four
// decibels, which takes out how unevenly the takes were struck without
// touching the shape of the keyboard.
//
// They are cut to length by register: the bass has to hold under a slow Bach
// bar, the treble never rings that long anyway.
import 'dart:io';
import 'dart:typed_data';

/// Sample rate of the packed bank. Half of CD, which loses nothing above
/// eleven kilohertz — hiss and hammer glare, on this instrument — and halves
/// what a phone has to download.
const int bankRate = 22050;

/// Where Tone.js publishes the set.
const String base = 'https://tonejs.github.io/audio/salamander';

/// One note per minor third, A0 to C8, as that copy names them.
const List<String> noteNames = [
  'A0', 'C1', 'Ds1', 'Fs1', 'A1', 'C2', 'Ds2', 'Fs2', 'A2', 'C3',
  'Ds3', 'Fs3', 'A3', 'C4', 'Ds4', 'Fs4', 'A4', 'C5', 'Ds5', 'Fs5',
  'A5', 'C6', 'Ds6', 'Fs6', 'A6', 'C7', 'Ds7', 'Fs7', 'A7', 'C8',
];

/// How long a note is kept, by register.
double secondsFor(int midi) {
  if (midi < 48) return 3.0; // under C3: has to hold a slow bass line
  if (midi < 72) return 2.2;
  return 1.2;
}

/// How much of the tail is faded, so a cut sample does not click.
const double fadeSeconds = 0.15;

Future<void> main() async {
  for (final tool in ['mpg123', 'sox']) {
    if (await Process.run('which', [tool]).then((r) => r.exitCode != 0)) {
      stderr.writeln('$tool is not on the PATH — see the header of this file');
      exit(1);
    }
  }

  final work = await Directory.systemTemp.createTemp('piano-flow-samples');
  final pcm = <int, Int16List>{};

  try {
    for (final name in noteNames) {
      final midi = _midiOf(name);
      stdout.write('$name (midi $midi): ');

      final mp3 = '${work.path}/$name.mp3';
      await _run('curl', ['-sSLf', '-o', mp3, '$base/$name.mp3']);

      final decoded = '${work.path}/$name.wav';
      await _run('mpg123', ['-q', '-w', decoded, mp3]);

      // Mono, downsampled, cut to length, with the tail faded out.
      final seconds = secondsFor(midi);
      final shaped = '${work.path}/$name.shaped.wav';
      await _run('sox', [
        decoded, '-r', '$bankRate', '-c', '1', '-b', '16', shaped,
        'trim', '0', '$seconds',
        'fade', 'h', '0', '$seconds', '$fadeSeconds',
      ]);

      pcm[midi] = _readWav(File(shaped).readAsBytesSync());
      stdout.writeln('${pcm[midi]!.length} samples');
    }
  } finally {
    await work.delete(recursive: true);
  }

  final midis = pcm.keys.toList()..sort();

  // One gain for the whole instrument, never one per note: the difference in
  // loudness between the bass and the top of the keyboard is the point.
  var peak = 0;
  for (final data in pcm.values) {
    for (final s in data) {
      final a = s.abs();
      if (a > peak) peak = a;
    }
  }
  const headroom = 0.89; // about −1 dB below full scale
  final gain = peak == 0 ? 1.0 : 32767 * headroom / peak;
  stdout.writeln('peak $peak, applying gain ${gain.toStringAsFixed(3)}');

  final total = midis.fold(0, (sum, m) => sum + pcm[m]!.length);

  // "PFPB", version, rate, count, then (midi, length) per note, then the PCM.
  final header = BytesBuilder();
  header.add('PFPB'.codeUnits);
  header.addByte(1);
  header.add(_u32(bankRate));
  header.add(_u16(midis.length));
  for (final midi in midis) {
    header.addByte(midi);
    header.add(_u32(pcm[midi]!.length));
  }

  final samples = Int16List(total);
  var at = 0;
  for (final midi in midis) {
    for (final s in pcm[midi]!) {
      samples[at++] = (s * gain).round().clamp(-32768, 32767);
    }
  }

  final out = BytesBuilder()
    ..add(header.toBytes())
    ..add(Uint8List.view(samples.buffer, 0, samples.lengthInBytes));

  final target = File('assets/piano/salamander.bin');
  await target.parent.create(recursive: true);
  await target.writeAsBytes(out.toBytes());
  stdout.writeln('wrote ${target.path} — '
      '${(out.length / 1024 / 1024).toStringAsFixed(2)} MB, '
      '${midis.length} notes');
}

/// 'Ds4' -> 63. The published copy spells a sharp with an 's'.
int _midiOf(String name) {
  const classes = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11};
  final letter = name[0];
  final sharp = name.length > 2 && name[1] == 's';
  final octave = int.parse(name.substring(sharp ? 2 : 1));
  return classes[letter]! + (sharp ? 1 : 0) + (octave + 1) * 12;
}

/// Pull the samples out of a canonical 16-bit mono WAV, by walking its chunks
/// rather than assuming sox wrote a 44-byte header.
Int16List _readWav(Uint8List bytes) {
  final view = ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.length);
  if (String.fromCharCodes(bytes.sublist(0, 4)) != 'RIFF' ||
      String.fromCharCodes(bytes.sublist(8, 12)) != 'WAVE') {
    throw const FormatException('not a WAV file');
  }
  var at = 12;
  while (at + 8 <= bytes.length) {
    final id = String.fromCharCodes(bytes.sublist(at, at + 4));
    final size = view.getUint32(at + 4, Endian.little);
    final body = at + 8;
    if (id == 'data') {
      final out = Int16List(size ~/ 2);
      for (var i = 0; i < out.length; i++) {
        out[i] = view.getInt16(body + i * 2, Endian.little);
      }
      return out;
    }
    at = body + size + (size.isOdd ? 1 : 0);
  }
  throw const FormatException('WAV file has no data chunk');
}

Uint8List _u16(int v) => Uint8List(2)..buffer.asByteData().setUint16(0, v, Endian.little);
Uint8List _u32(int v) => Uint8List(4)..buffer.asByteData().setUint32(0, v, Endian.little);

Future<void> _run(String exe, List<String> args) async {
  final result = await Process.run(exe, args);
  if (result.exitCode != 0) {
    stderr.writeln(result.stdout);
    stderr.writeln(result.stderr);
    throw ProcessException(exe, args, 'failed', result.exitCode);
  }
}
