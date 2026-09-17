import 'package:flutter/services.dart' show rootBundle;

import '../music/song.dart';
import 'catalog.g.dart' as generated;
import 'score_import.dart';
import 'song_info.dart';

/// The songs that ship with the game.
///
/// Everything here is public domain — the composers died well over a century
/// ago — and the editions are freely licensed. That is deliberate: it is what
/// lets the whole library be open from the first launch, with nothing locked
/// behind a paywall, which is the single loudest complaint against the game
/// this one takes after.
///
/// **Adding a song is one entry in `tool/catalog.dart`** plus a run of
/// `tool/build_library.dart`. Nothing here changes, and nothing in this file
/// names a piece: the list is generated, and grows without being edited.
///
/// The notes live in `assets/songs/<id>.mid`, rendered from published
/// LilyPond editions with every repeat played out. They used to be base64
/// strings compiled into the app, which was fine for four songs and would be
/// a megabyte of Dart at a hundred — every one of them downloaded before the
/// first note of the first. As assets, a song costs nothing until it is
/// chosen.
///
/// So [all] is synchronous and cheap, and [load] is the only thing that
/// touches a score.
abstract final class SongLibrary {
  /// Every song, as much as can be known without opening it: what it is
  /// called, how long it runs, what tempo it is at.
  static const List<SongInfo> all = generated.catalog;

  static final Map<String, SongInfo> _byId = {
    for (final info in all) info.id: info,
  };

  static SongInfo? infoOf(String id) => _byId[id];

  /// Songs already read, so leaving a song and coming back is free.
  ///
  /// Small: a score is a few tens of kilobytes of MIDI and a few thousand
  /// notes. Nothing is evicted because nothing needs to be — a player cannot
  /// open enough songs in one sitting to matter.
  static final Map<String, Song> _loaded = {};

  /// The notes of a song, read from its asset the first time it is asked for.
  static Future<Song> load(String id) async {
    final cached = _loaded[id];
    if (cached != null) return cached;

    final info = _byId[id];
    if (info == null) throw ArgumentError.value(id, 'id', 'no such song');

    final data = await rootBundle.load(info.asset);
    return _loaded[id] = ScoreImport.read(data.buffer.asUint8List(), info);
  }
}

// Anything without a Flutter asset bundle behind it — the tools that render a
// song to WAV, and most of the tests — reaches for `catalog` and
// [ScoreImport.read] instead, and reads the same file off disk. This class is
// the one place that needs `rootBundle`, and importing it costs `dart:ui`.
