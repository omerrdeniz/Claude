import 'dart:io';

import 'package:piano_flow/data/catalog.g.dart';
import 'package:piano_flow/data/score_import.dart';
import 'package:piano_flow/music/song.dart';

/// The shipped songs, read off disk rather than out of an asset bundle.
///
/// The app reads `assets/songs/<id>.mid` through `rootBundle`, which is
/// asynchronous and needs a Flutter binding. Tests want the same notes with
/// neither — a group cannot be declared inside a `Future`, and most of these
/// tests have nothing to do with widgets. The bytes are the same file either
/// way, so this reads it directly and shapes it exactly as the app does.
///
/// `SongLibrary.load` is the path the app takes; the song-list tests exercise
/// that one, through a real screen.
Song shipped(String id) => _read[id] ??= _load(id);

final Map<String, Song> _read = {};

Song _load(String id) {
  final info = catalog.firstWhere((info) => info.id == id,
      orElse: () => throw ArgumentError.value(id, 'id', 'no such song'));
  return ScoreImport.read(File(info.asset).readAsBytesSync(), info);
}

/// Every shipped song, for the checks that should hold across the library.
List<Song> get shippedSongs => [for (final info in catalog) shipped(info.id)];
