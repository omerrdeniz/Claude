// Builds the song library from tool/catalog.dart.
//
//     dart run tool/build_library.dart            # everything not cached
//     dart run tool/build_library.dart fur-elise  # force one, cache or not
//
// For each entry it fetches the score, renders it to MIDI with every repeat
// written out, writes `assets/songs/<id>.mid`, and regenerates
// `lib/data/catalog.g.dart` with what it read off the score: tempo, metre,
// length, range, how many notes.
//
// Rendered MIDI is cached under `tool/.cache/`, keyed by everything that
// could change it, so a rebuild after adding one song costs one song. The
// cache is not committed; the assets are, so building the app needs neither
// this tool nor a network.
//
// Needs LilyPond, and unzip and patch for the scores that arrive as archives:
//
//     apt-get install -y lilypond unzip patch
import 'dart:io';
import 'dart:typed_data';

import 'package:piano_flow/data/score_import.dart';
import 'package:piano_flow/data/song_info.dart';
import 'package:piano_flow/music/midi_reader.dart';

import 'catalog.dart';

const _cacheDir = 'tool/.cache';
const _assetDir = 'assets/songs';
const _generated = 'lib/data/catalog.g.dart';
const _scoreDir = 'tool/scores';

Future<void> main(List<String> args) async {
  final forced = args.toSet();
  final infos = <SongInfo>[];
  Directory(_cacheDir).createSync(recursive: true);
  Directory(_assetDir).createSync(recursive: true);

  for (final score in catalog) {
    final midi = File('$_cacheDir/${score.id}.mid');
    final stamp = File('$_cacheDir/${score.id}.stamp');
    final recipe = _recipeOf(score);
    final cached = midi.existsSync() &&
        stamp.existsSync() &&
        stamp.readAsStringSync() == recipe &&
        !forced.contains(score.id);

    if (cached) {
      stdout.writeln('${score.id}: cached');
    } else {
      stdout.writeln('${score.id}: building');
      await midi.writeAsBytes(await _render(score));
      await stamp.writeAsString(recipe);
    }

    final bytes = Uint8List.fromList(await midi.readAsBytes());
    await File('$_assetDir/${score.id}.mid').writeAsBytes(bytes);
    final info = _describe(score, bytes);
    infos.add(info);
    stdout.writeln('  ${info.noteCount} nota, ${info.bpm.round()} bpm, '
        '${info.beatsPerBar} vuruş/ölçü, ${_clock(info.duration)}');
  }

  await File(_generated).writeAsString(_emit(infos));
  stdout.writeln('wrote $_generated (${infos.length} songs)');
}

/// Everything that decides what the MIDI comes out as. Change any of it and
/// the cached render is stale.
String _recipeOf(Score score) => [
      score.url ?? '',
      score.patchUrl ?? '',
      score.entry ?? '',
      score.unfoldAt ?? '',
      for (final name in [score.local, score.assemble])
        if (name != null) File('$_scoreDir/$name').readAsStringSync(),
    ].join(' ');

/// Read off the score everything a score can tell us; take the rest from the
/// catalogue.
SongInfo _describe(Score score, Uint8List midi) {
  final raw = MidiReader.read(midi);
  // The edition marks the quarter; the piece may be counted in something
  // else. A 3/8 rondo marked quarter = 72 is played at 144 eighths.
  final beatsPerBar = score.beatsPerBar ?? raw.beatsPerBar;
  final facts = SongInfo(
    id: score.id,
    title: score.title,
    composer: score.composer,
    source: score.credit,
    bpm: score.bpm ?? _tidy(raw.bpm * score.beatsPerQuarter),
    beatsPerBar: beatsPerBar,
    beatsPerQuarter: score.beatsPerQuarter,
    rightVelocity: score.rightVelocity,
    leftVelocity: score.leftVelocity,
    startBeat:
        score.fromBar == null ? 0 : (score.fromBar! - 1) * beatsPerBar * 1.0,
    noteCount: 0,
    durationMs: 0,
    lowMidi: 0,
    highMidi: 0,
  );

  final song = ScoreImport.read(midi, facts);
  final (low, high) = song.pitchRange;
  return SongInfo(
    id: facts.id,
    title: facts.title,
    composer: facts.composer,
    source: facts.source,
    bpm: facts.bpm,
    beatsPerBar: facts.beatsPerBar,
    beatsPerQuarter: facts.beatsPerQuarter,
    rightVelocity: facts.rightVelocity,
    leftVelocity: facts.leftVelocity,
    startBeat: facts.startBeat,
    noteCount: song.notes.length,
    durationMs: song.duration.inMilliseconds,
    lowMidi: low,
    highMidi: high,
  );
}

/// A tempo without the arithmetic showing.
///
/// MIDI stores microseconds per quarter note as a whole number, so a mark of
/// 132 comes back as 132.000132. Nothing can hear the difference, but it
/// makes the generated file look like a measurement rather than an edition's
/// own instruction.
double _tidy(double bpm) {
  final whole = bpm.roundToDouble();
  return (bpm - whole).abs() < 0.01 ? whole : (bpm * 100).round() / 100;
}

String _clock(Duration d) =>
    '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

/// Fetch, assemble and render one score.
Future<List<int>> _render(Score score) async {
  final work = await Directory.systemTemp.createTemp('piano-flow-${score.id}');
  try {
    final File entry;
    if (score.local != null) {
      entry = File('${work.path}/${score.id}.ly');
      await entry.writeAsString(
          await File('$_scoreDir/${score.local}').readAsString());
    } else if (score.url!.endsWith('.zip')) {
      entry = await _unpack(score, work);
    } else {
      entry = File('${work.path}/${score.id}.ly');
      await entry.writeAsBytes(await _download(score.url!));
    }

    // Every file, not only the one being rendered: LilyPond sources include
    // each other, and a stale `\layout` two files away still pulls the
    // engraver in and fails the build.
    final sources = entry.parent
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.ly') || f.path.endsWith('.ily'));
    for (final file in sources) {
      await _run('convert-ly', ['-e', file.path], entry.parent.path);
      await file.writeAsString(_shapeForMidi(await file.readAsString()));
    }

    if (score.unfoldAt != null) {
      final text = await entry.readAsString();
      if (!text.contains(score.unfoldAt!)) {
        throw StateError('${score.id}: no "${score.unfoldAt}" to unfold '
            'repeats around — the upstream file has changed shape');
      }
      await entry.writeAsString(text.replaceFirst(
          score.unfoldAt!, r'\unfoldRepeats ' + score.unfoldAt!));
    }

    await _run('lilypond',
        ['-dno-point-and-click', '-o', score.id, entry.path], entry.parent.path);

    final midi = File('${entry.parent.path}/${score.id}.midi');
    if (!midi.existsSync()) {
      throw StateError('${score.id}: LilyPond produced no MIDI');
    }
    return midi.readAsBytes();
  } finally {
    await work.delete(recursive: true);
  }
}

/// Unpack an archive of parts, patch it if asked, and return the file to
/// render — either one of the edition's own, or ours written in beside them.
Future<File> _unpack(Score score, Directory work) async {
  final archive = File('${work.path}/sources.zip');
  await archive.writeAsBytes(await _download(score.url!));
  await _run('unzip', ['-q', '-o', archive.path], work.path);

  final unpacked = work.listSync().whereType<Directory>().firstWhere(
        (d) => d.path.endsWith('-lys'),
        orElse: () => throw StateError(
            '${score.id}: the archive did not unpack into a folder of sources'),
      );

  if (score.patchUrl != null) {
    final patch = File('${work.path}/arrangement.patch');
    await patch.writeAsBytes(await _download(score.patchUrl!));
    await _run('patch', ['-p0', '-i', patch.path], unpacked.path);
  }

  if (score.assemble != null) {
    final ours = File('${unpacked.path}/${score.id}.ly');
    await ours.writeAsString(
        await File('$_scoreDir/${score.assemble}').readAsString());
    return ours;
  }

  final entry = File('${unpacked.path}/${score.entry}');
  if (!entry.existsSync()) {
    throw StateError('${score.id}: the archive has no ${score.entry}');
  }
  return entry;
}

/// Strip a source of everything that only matters when engraving.
///
/// Rendering the picture takes far longer than the MIDI and produces a PDF
/// nothing here reads. It also sidesteps a pile of old engraving syntax that
/// no longer compiles.
String _shapeForMidi(String text) {
  var out = _stripLayout(text);
  // `set-octavation` is a Scheme call convert-ly leaves alone in files that
  // already claim a recent version. It draws the 8va bracket and moves the
  // printed notes under it; the sounding pitch is what the source says either
  // way, so this cannot change a note.
  out = out.replaceAllMapped(
      RegExp(r'#\(set-octavation\s+(-?\d+)\)'), (m) => r'\ottava #' + m[1]!);
  return out;
}

/// Cut every `\layout { ... }` block out of [text], braces matched.
///
/// A regular expression will not do it: these blocks nest, and the one in the
/// Chopin carries a whole `\context` inside it.
String _stripLayout(String text) {
  final out = StringBuffer();
  var i = 0;
  while (true) {
    final start = text.indexOf(r'\layout', i);
    if (start == -1) {
      out.write(text.substring(i));
      return out.toString();
    }
    out.write(text.substring(i, start));

    final open = text.indexOf('{', start);
    if (open == -1) throw StateError(r'a \layout with no block after it');
    var depth = 0;
    var at = open;
    while (at < text.length) {
      if (text[at] == '{') depth++;
      if (text[at] == '}') depth--;
      at++;
      if (depth == 0) break;
    }
    if (depth != 0) throw StateError(r'unbalanced braces in a \layout block');
    i = at;
  }
}

String _emit(List<SongInfo> infos) {
  final out = StringBuffer()
    ..writeln('// GENERATED BY tool/build_library.dart — DO NOT EDIT BY HAND.')
    ..writeln('//')
    ..writeln('// What the game knows about each song before opening it. The')
    ..writeln('// notes themselves are in assets/songs/, read when a song is')
    ..writeln('// chosen. Add a song in tool/catalog.dart and run the tool.')
    ..writeln('library;')
    ..writeln()
    ..writeln("import 'song_info.dart';")
    ..writeln()
    ..writeln('const List<SongInfo> catalog = [');

  for (final info in infos) {
    out
      ..writeln('  SongInfo(')
      ..writeln("    id: '${info.id}',")
      ..writeln('    title: ${_quote(info.title)},')
      ..writeln('    composer: ${_quote(info.composer)},')
      ..writeln('    source: ${_quote(info.source)},')
      ..writeln('    bpm: ${_number(info.bpm)},')
      ..writeln('    beatsPerBar: ${info.beatsPerBar},')
      ..writeln('    beatsPerQuarter: ${_number(info.beatsPerQuarter)},')
      ..writeln('    rightVelocity: ${_number(info.rightVelocity)},')
      ..writeln('    leftVelocity: ${_number(info.leftVelocity)},')
      ..writeln('    startBeat: ${_number(info.startBeat)},')
      ..writeln('    noteCount: ${info.noteCount},')
      ..writeln('    durationMs: ${info.durationMs},')
      ..writeln('    lowMidi: ${info.lowMidi},')
      ..writeln('    highMidi: ${info.highMidi},')
      ..writeln('  ),');
  }
  out.writeln('];');
  return out.toString();
}

/// A Dart single-quoted literal, wrapped so the generated file keeps to the
/// line length the rest of the project does.
String _quote(String text) {
  final escaped = text.replaceAll(r'\', r'\\').replaceAll("'", r"\'");
  if (escaped.length <= 56) return "'$escaped'";

  final lines = <String>[];
  var line = StringBuffer();
  for (final word in escaped.split(' ')) {
    if (line.isNotEmpty && line.length + word.length + 1 > 52) {
      lines.add(line.toString());
      line = StringBuffer();
    }
    if (line.isNotEmpty) line.write(' ');
    line.write(word);
  }
  if (line.isNotEmpty) lines.add(line.toString());

  final joined = StringBuffer();
  for (var i = 0; i < lines.length; i++) {
    if (i > 0) joined.write('\n        ');
    joined.write("'${lines[i]}${i == lines.length - 1 ? '' : ' '}'");
  }
  return joined.toString();
}

String _number(double value) =>
    value == value.roundToDouble() ? '${value.round()}' : '$value';

Future<List<int>> _download(String url) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(Uri.parse(url));
    final response = await request.close();
    if (response.statusCode != 200) {
      throw HttpException('HTTP ${response.statusCode} for $url');
    }
    return [await for (final chunk in response) ...chunk];
  } finally {
    client.close();
  }
}

Future<void> _run(String executable, List<String> args, String cwd) async {
  final result = await Process.run(executable, args, workingDirectory: cwd);
  if (result.exitCode != 0) {
    stderr.writeln(result.stdout);
    stderr.writeln(result.stderr);
    throw ProcessException(executable, args, 'failed', result.exitCode);
  }
}
