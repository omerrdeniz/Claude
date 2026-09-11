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
import 'package:piano_flow/game/chart.dart';
import 'package:piano_flow/music/midi_reader.dart';

import 'arrangement.dart';
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
        '${info.beatsPerBar} vuruş/ölçü, ${_clock(info.duration)}, '
        '${info.tapsPerSecond.toStringAsFixed(1)} dokunuş/sn');
  }

  // Gentlest first. The catalogue is written in whatever order songs were
  // added, which is no use to anybody looking for something they can play.
  infos.sort((a, b) => a.tapsPerSecond.compareTo(b.tapsPerSecond));

  await File(_generated).writeAsString(_emit(infos));
  stdout.writeln('wrote $_generated (${infos.length} songs)');
}

/// Everything that decides what the MIDI comes out as. Change any of it and
/// the cached render is stale.
String _recipeOf(Score score) => [
      score.url ?? '',
      score.midiUrl ?? '',
      score.patchUrl ?? '',
      score.entry ?? '',
      for (final name in [score.local, score.assemble, score.arrangement])
        if (name != null) File('$_scoreDir/$name').readAsStringSync(),
      if (score.localMidi != null)
        File('$_scoreDir/${score.localMidi}').lengthSync().toString(),
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
    tapCount: 0,
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
    tapCount: Chart.build(song).taps.length,
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
  // A score already published as MIDI needs no rendering at all. See
  // [Score.midiUrl] for why that is not a shortcut.
  if (score.midiUrl != null) return _download(score.midiUrl!);

  // A MIDI sitting next to the scores is already the notes.
  if (score.localMidi != null) {
    return File('$_scoreDir/${score.localMidi}').readAsBytes();
  }

  // An arrangement of our own is already the notes; there is no engraving to
  // typeset, so LilyPond never enters into it.
  if (score.arrangement != null) {
    final source = await File('$_scoreDir/${score.arrangement}').readAsString();
    return Arrangement.parse(source).toMidi();
  }

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
      // Best effort: an included file without a \version of its own makes
      // convert-ly complain and skip it, which is fine — there is nothing
      // there to upgrade. LilyPond itself is the judge of whether the result
      // compiles.
      await _run('convert-ly', ['-e', file.path], entry.parent.path,
          mustSucceed: false);
      await file.writeAsString(_shapeForMidi(await file.readAsString()));
    }

    await entry.writeAsString(_unfolded(await entry.readAsString(), score.id));

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

  // Most archives unpack into a folder named for themselves; some spill
  // their files straight out.
  final unpacked = work
          .listSync()
          .whereType<Directory>()
          .where((d) => d.path.endsWith('-lys'))
          .firstOrNull ??
      work;

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

/// Put `\unfoldRepeats` around the music the MIDI is rendered from, so a
/// volta bracket comes out as the notes a performer actually plays.
///
/// It has to go in the right `\score` block. Editions routinely carry two —
/// one for the page and one for the MIDI — and putting it round the printed
/// one changes nothing audible while looking as though it worked. That was a
/// per-score setting once, which is a thing to get wrong quietly on every
/// score added; now the block is found by looking for the one that has a
/// `\midi` in it.
///
/// Inside that block it goes immediately after the opening brace, in front
/// of whatever music expression follows — which may be `{ ... }`, `<< ... >>`,
/// a `\new PianoStaff`, or the bare name of a variable holding any of those.
/// Editions use all four, and a rule that looked for staves missed the ones
/// that keep their staves in a variable.
///
/// Applied to every score, repeats or not: unfolding a piece that has none
/// does nothing.
String _unfolded(String text, String id) {
  final blocks = _blocksOf(text, r'\score');
  final sounding =
      blocks.where((b) => text.substring(b.$1, b.$2).contains(r'\midi'));
  final target = sounding.isEmpty ? blocks : sounding;
  if (target.isEmpty) throw StateError(r'no \score block to render in ' + id);

  final block = target.first;
  var at = text.indexOf('{', block.$1) + 1;
  // A score may open with its own header; the music comes after it.
  final header = RegExp(r'^\s*\\header\s*\{').firstMatch(text.substring(at));
  if (header != null) {
    final headerBlock = _blocksOf(text.substring(at), r'\header').first;
    at += headerBlock.$2;
  }
  return '${text.substring(0, at)} \\unfoldRepeats ${text.substring(at)}';
}

/// Every `\name { ... }` block in [text], as (start, end) offsets, braces
/// matched so a nested block does not end its parent early.
List<(int, int)> _blocksOf(String text, String keyword) {
  // Word-bounded: `\score` must not match the `\scoreAll` that half the
  // Chopin editions keep their music in. That one cost an afternoon.
  final word = RegExp('${RegExp.escape(keyword)}' r'(?![A-Za-z])');
  final out = <(int, int)>[];
  var i = 0;
  while (true) {
    final found = word.firstMatch(text.substring(i));
    if (found == null) return out;
    final start = i + found.start;
    final open = text.indexOf('{', start);
    if (open == -1) return out;
    var depth = 0;
    var at = open;
    while (at < text.length) {
      if (text[at] == '{') depth++;
      if (text[at] == '}') depth--;
      at++;
      if (depth == 0) break;
    }
    out.add((start, at));
    i = at;
  }
}

/// Strip a source of everything that only matters when engraving.
///
/// Rendering the picture takes far longer than the MIDI and produces a PDF
/// nothing here reads. It also sidesteps a pile of old engraving syntax that
/// no longer compiles.
String _shapeForMidi(String text) {
  // `\layout` is how a score is engraved and `\paper` is the page it is
  // engraved on. Neither has anything to do with what the piece sounds like,
  // and both carry old syntax that fails the build long after the MIDI has
  // been written — the worst kind of failure to have to read.
  // Comments first, and not only for tidiness: a commented-out `\midi` is
  // how one edition offers a MIDI score you have to switch on, and reading
  // it as a real one sends the unfolding into the printed score instead.
  var out = _uncommented(text);
  out = _stripBlocks(out, r'\layout');
  out = _stripBlocks(out, r'\paper');
  // Beaming is a picture. `override-auto-beam-setting` is old Scheme that
  // convert-ly leaves alone in files claiming a recent version, and it stops
  // the build dead — after LilyPond has already written a perfectly good
  // MIDI, which is the worst kind of failure to trust.
  for (final call in ['override-auto-beam-setting', 'revert-auto-beam-setting']) {
    out = _stripScheme(out, call);
  }
  // Some editions already unfold their MIDI score, in syntax whose Scheme
  // procedure has since changed shape and now fails to load. Ours goes on
  // afterwards and does the same job, so this one just goes.
  out = out.replaceAll(RegExp(r'\\applyMusic\s+#unfold-repeats'), '');
  // `set-octavation` is a Scheme call convert-ly leaves alone in files that
  // already claim a recent version. It draws the 8va bracket and moves the
  // printed notes under it; the sounding pitch is what the source says either
  // way, so this cannot change a note.
  out = out.replaceAllMapped(
      RegExp(r'#\(set-octavation\s+(-?\d+)\)'), (m) => r'\ottava #' + m[1]!);
  return out;
}

/// Cut every `#(name ...)` Scheme call out of [text], parens matched.
String _stripScheme(String text, String name) {
  final out = StringBuffer();
  var i = 0;
  while (true) {
    final start = text.indexOf('#($name', i);
    if (start == -1) {
      out.write(text.substring(i));
      return out.toString();
    }
    out.write(text.substring(i, start));

    var depth = 0;
    var at = start + 1;
    while (at < text.length) {
      if (text[at] == '(') depth++;
      if (text[at] == ')') depth--;
      at++;
      if (depth == 0) break;
    }
    if (depth != 0) throw StateError('unbalanced parens after #($name');
    i = at;
  }
}

/// Drop LilyPond's comments: `%{ ... %}` blocks and `%` to end of line.
///
/// Quotes are tracked, so a per cent sign inside a title stays where it is.
String _uncommented(String text) {
  final out = StringBuffer();
  var quoted = false;
  var block = false;
  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (block) {
      if (c == '%' && i + 1 < text.length && text[i + 1] == '}') {
        block = false;
        i++;
      }
      continue;
    }
    if (c == '"' && (i == 0 || text[i - 1] != r'\')) quoted = !quoted;
    if (!quoted && c == '%') {
      if (i + 1 < text.length && text[i + 1] == '{') {
        block = true;
        i++;
        continue;
      }
      while (i < text.length && text[i] != '\n') {
        i++;
      }
      out.write('\n');
      continue;
    }
    out.write(c);
  }
  return out.toString();
}

/// Cut every `\keyword { ... }` block out of [text], braces matched.
///
/// A regular expression will not do it: these blocks nest, and the `\layout`
/// in the Chopin carries a whole `\context` inside it.
String _stripBlocks(String text, String keyword) {
  final out = StringBuffer();
  var i = 0;
  while (true) {
    final start = text.indexOf(keyword, i);
    if (start == -1) {
      out.write(text.substring(i));
      return out.toString();
    }
    out.write(text.substring(i, start));

    final open = text.indexOf('{', start);
    if (open == -1) throw StateError('a $keyword with no block after it');
    var depth = 0;
    var at = open;
    while (at < text.length) {
      if (text[at] == '{') depth++;
      if (text[at] == '}') depth--;
      at++;
      if (depth == 0) break;
    }
    if (depth != 0) throw StateError('unbalanced braces in a $keyword block');
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
      ..writeln('    tapCount: ${info.tapCount},')
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

/// Fetch a file, with a few goes at it.
///
/// A score archive is one request; a library rebuild is dozens in a row, and
/// a server that is happy to serve one is not always happy to serve twenty —
/// KernScores drops the connection partway through a run of them. Failing
/// the whole build on that means starting over for the sake of one file, so
/// this waits and asks again.
Future<List<int>> _download(String url, {int tries = 4}) async {
  for (var attempt = 1;; attempt++) {
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      if (response.statusCode != 200) {
        throw HttpException('HTTP ${response.statusCode} for $url');
      }
      return [await for (final chunk in response) ...chunk];
    } catch (error) {
      if (attempt >= tries) rethrow;
      stdout.writeln('  yeniden deneniyor ($attempt/$tries): $error');
      await Future<void>.delayed(Duration(seconds: 2 * attempt));
    } finally {
      client.close();
    }
  }
}

Future<void> _run(String executable, List<String> args, String cwd,
    {bool mustSucceed = true}) async {
  final result = await Process.run(executable, args, workingDirectory: cwd);
  if (result.exitCode != 0 && !mustSucceed) return;
  if (result.exitCode != 0) {
    stderr.writeln(result.stdout);
    stderr.writeln(result.stderr);
    throw ProcessException(executable, args, 'failed', result.exitCode);
  }
}
