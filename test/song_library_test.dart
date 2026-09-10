import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:piano_flow/data/song_library.dart';
import 'package:piano_flow/game/chart.dart';
import 'package:piano_flow/music/note.dart';

import 'support/library.dart';

void main() {
  test('the library is not empty and ids are unique', () {
    final songs = shippedSongs;
    expect(songs, isNotEmpty);
    expect(songs.map((s) => s.id).toSet(), hasLength(songs.length));
  });

  test('songs can be looked up by id', () {
    expect(SongLibrary.infoOf('fur-elise')?.title, 'Für Elise');
    expect(SongLibrary.infoOf('nope'), isNull);
  });

  // Adding a song is one entry in tool/catalog.dart and a run of the builder.
  // These are what catch a run that was forgotten, or half done: a catalogue
  // that no longer matches the scores beside it fails quietly at run time,
  // with a song that plays at the wrong tempo or is not there at all.
  group('the catalogue and the scores agree', () {
    test('every song has the score it names', () {
      for (final info in SongLibrary.all) {
        expect(File(info.asset).existsSync(), isTrue,
            reason: '${info.id}: no ${info.asset} — run '
                'tool/build_library.dart');
      }
    });

    test('no score is shipped that no song claims', () {
      final claimed = {for (final info in SongLibrary.all) info.asset};
      final present = Directory('assets/songs')
          .listSync()
          .whereType<File>()
          .map((f) => f.path)
          .where((p) => p.endsWith('.mid'));
      for (final path in present) {
        expect(claimed, contains(path),
            reason: '$path is not in the catalogue — a song was removed '
                'without rebuilding');
      }
    });

    test('what the catalogue says about a song is what the score says', () {
      for (final info in SongLibrary.all) {
        final song = shipped(info.id);
        final (low, high) = song.pitchRange;
        expect(song.notes.length, info.noteCount, reason: info.id);
        expect(song.duration.inMilliseconds, info.durationMs, reason: info.id);
        expect(low, info.lowMidi, reason: info.id);
        expect(high, info.highMidi, reason: info.id);
      }
    });

    test('an excerpt is the piece from where it says, and nothing before', () {
      // Cut so a mechanic buried eighty seconds into a piece can be tried in
      // five. It has to be the same music, only later — not a re-render, not
      // a different arrangement.
      final excerpt = shipped('canon-run-test');
      final whole = shipped('canon-in-d');
      final from = SongLibrary.infoOf('canon-run-test')!.startBeat;
      expect(from, greaterThan(0), reason: 'nothing was cut');

      final kept = whole.notes.where((n) => n.beat >= from).toList();
      expect(excerpt.notes, hasLength(kept.length));
      for (var i = 0; i < kept.length; i++) {
        expect(excerpt.notes[i].midi, kept[i].midi, reason: 'note $i');
        expect(excerpt.notes[i].beat, closeTo(kept[i].beat - from, 1e-9),
            reason: 'note $i');
      }
      expect(excerpt.notes.first.beat, 0, reason: 'it should start at once');
    });

    test('the excerpt reaches what it was cut for within a few seconds', () {
      // Its whole reason to exist. If the runs move, this catches it.
      final excerpt = shipped('canon-run-test');
      final runs = Chart.build(excerpt).runs.values.toList()
        ..sort((a, b) => a.first.beat.compareTo(b.first.beat));
      expect(runs, isNotEmpty);
      final seconds = runs.first.first.beat / excerpt.bpm * 60;
      expect(seconds, lessThan(10), reason: 'the first run is $seconds s in');
    });

    test('everything else starts at its beginning', () {
      for (final info in SongLibrary.all) {
        if (info.id == 'canon-run-test') continue;
        expect(info.startBeat, 0, reason: '${info.id} is not an excerpt');
      }
    });

    test('an id is safe to use as a file name and as saved data', () {
      for (final info in SongLibrary.all) {
        expect(info.id, matches(RegExp(r'^[a-z0-9][a-z0-9-]*$')),
            reason: '${info.id} would not survive a round trip');
      }
    });
  });

  testWidgets('a song loads through the asset bundle, as the app loads it',
      (tester) async {
    // The path everything else here sidesteps: rootBundle rather than the
    // file system. If the asset directory ever falls out of pubspec.yaml,
    // every other test still passes and the app opens to a list of songs
    // that cannot be played.
    final song = await SongLibrary.load('fur-elise');
    expect(song.title, 'Für Elise');
    expect(song.notes, isNotEmpty);
    expect(identical(await SongLibrary.load('fur-elise'), song), isTrue,
        reason: 'a song read twice should be read once');
    expect(() => SongLibrary.load('nope'), throwsArgumentError);
  });

  for (final song in shippedSongs) {
    group(song.title, () {
      test('has notes, in order, within the MIDI range', () {
        expect(song.notes, isNotEmpty);
        var previous = -1.0;
        for (final n in song.notes) {
          expect(n.beat, greaterThanOrEqualTo(previous));
          expect(n.midi, inInclusiveRange(21, 108),
              reason: 'outside an 88-key piano');
          expect(n.duration, greaterThan(0));
          previous = n.beat;
        }
      });

      test('gives the player a melody and plays an accompaniment', () {
        expect(song.melody, isNotEmpty, reason: 'nothing for the player to tap');
        expect(song.accompaniment, isNotEmpty, reason: 'no left hand');
      });

      test('the accompaniment sits below the melody', () {
        final melodyAverage = song.melody.map((n) => n.midi).reduce((a, b) => a + b) /
            song.melody.length;
        final leftAverage =
            song.accompaniment.map((n) => n.midi).reduce((a, b) => a + b) /
                song.accompaniment.length;
        expect(leftAverage, lessThan(melodyAverage));
      });

      test('credits a public-domain source', () {
        expect(song.source, isNotEmpty);
        expect(song.composer, isNotEmpty);
      });

      test('runs for a sensible length of time', () {
        expect(song.duration.inSeconds, greaterThan(5));
        expect(song.duration.inMinutes, lessThan(10));
      });

      // Not a promise that every touch can be caught — at their written
      // tempo these pieces run past what a finger can do, and Chopin's
      // thirty-second triplets leave 76 ms. What it catches is an import
      // gone wrong: an ornament left in, or a chord split into a stutter of
      // separate touches a few milliseconds apart.
      test('no two touches land close enough to be one mangled chord', () {
        final moments = song.chordsOf(song.notes);
        expect(moments, isNotEmpty);
        final secondsPerBeat = 60 / song.bpm;
        for (var i = 1; i < moments.length; i++) {
          final gap = (moments[i].first.beat - moments[i - 1].first.beat) *
              secondsPerBeat;
          expect(gap, greaterThan(0.05),
              reason: 'two moments ${(gap * 1000).round()} ms apart');
        }
      });
    });
  }

  test('chordsOf groups notes struck together', () {
    final song = shipped('ode-to-joy');
    final chords = song.chordsOf(song.accompaniment);
    expect(chords.first, hasLength(3), reason: 'a triad is one tap');
  });

  test('Ode to Joy opens on the melody everyone knows', () {
    final opening = shipped('ode-to-joy').melody.take(4).map((n) => n.midi);
    expect(opening, [64, 64, 65, 67], reason: 'E E F G');
  });

  test('Für Elise opens on its alternating semitone', () {
    final opening = shipped('fur-elise').melody.take(4).map((n) => n.midi);
    expect(opening, [76, 75, 76, 75], reason: 'E5 D#5 E5 D#5');
  });

  test('the Bach prelude repeats one figure under changing harmony', () {
    final song = shipped('prelude-in-c');
    final figure = song.melody.take(3).map((n) => n.midi).toList();
    // Written out from memory this sat an octave low; the engraved edition
    // puts the right hand above middle C, where it belongs.
    expect(figure, [67, 72, 76], reason: 'G4 C5 E5');
    // The same shape returns immediately, a step further into the bar.
    expect(song.melody.skip(3).take(3).map((n) => n.midi), figure);
    // Bar three changes harmony, so the figure moves.
    final barThree = song.melody
        .where((n) => n.beat >= 8 && n.beat < 12)
        .take(3)
        .map((n) => n.midi);
    expect(barThree, isNot(figure));
  });

  group('the pieces are complete, at the tempo they are written at', () {
    test('Für Elise is the whole rondo, not just its theme', () {
      final song = shipped('fur-elise');
      // A B A C A with the repeats played out, counted in eighths.
      expect(song.lengthInBeats / song.beatsPerBar, greaterThan(100),
          reason: 'bars');
      expect(song.duration.inSeconds, inInclusiveRange(140, 190));
      expect(song.bpm, 144, reason: 'the edition marks the quarter at 72');
      expect(song.beatsPerBar, 3);
      // It reaches the top of the C section and the bottom of the bass.
      expect(song.pitchRange.$2, greaterThan(93), reason: 'above A6');
      expect(song.pitchRange.$1, lessThan(40), reason: 'below E2');
    });

    test('the Bach prelude runs all thirty-five bars', () {
      final song = shipped('prelude-in-c');
      expect(song.lengthInBeats / song.beatsPerBar, closeTo(35, 0.5));
      expect(song.bpm, 60, reason: 'the edition marks the quarter at 60');
      // The last bar is the long tonic the piece settles onto.
      expect(song.notes.last.endBeat, greaterThan(135));
    });

    test('Ode to Joy keeps Beethoven Allegro assai', () {
      // Half note = 80 in the Ninth, so the quarter is 160.
      expect(shipped('ode-to-joy').bpm, 160);
      expect(shipped('ode-to-joy').lengthInBeats / 4, closeTo(16, 0.5));
    });

    test('the canon is a piano arrangement, not a reading score', () {
      // The transcription this started from folded all three violins and the
      // bass onto two staves — faithful, and up to four notes thick in the
      // right hand at every eighth. What is shipped is the leading voice over
      // the ground, which is what anybody means by the Canon in D on a piano.
      final song = shipped('canon-in-d');
      final thickest = song
          .chordsOf(song.melody)
          .map((moment) => moment.length)
          .reduce((a, b) => a > b ? a : b);
      expect(thickest, lessThanOrEqualTo(2),
          reason: 'the right hand is one violin, not three');
    });

    test('the canon opens on its ground bass, alone', () {
      final song = shipped('canon-in-d');
      // Two bars of the ground before any voice enters: D A B F# G D G A.
      expect(
          song.accompaniment.take(8).map((n) => n.midi),
          [50, 45, 47, 42, 43, 38, 43, 45],
          reason: 'the bass everyone knows');
      expect(song.melody.where((n) => n.beat < 8), isEmpty,
          reason: 'the violins wait two bars');
      // And it is the whole piece, not the first page.
      expect(song.duration.inMinutes, greaterThanOrEqualTo(3));
      expect(song.bpm, 55, reason: 'the edition marks the quarter at 55');
    });

    test('the Chopin nocturne is the whole piece, cadenza and all', () {
      final song = shipped('nocturne-op9-no2');
      expect(song.bpm, 132, reason: 'the edition marks the eighth at 132');
      expect(song.beatsPerBar, 12, reason: '12/8');
      expect(song.lengthInBeats / song.beatsPerBar, greaterThan(35));
      expect(song.duration.inSeconds, inInclusiveRange(180, 230));
      // The cadenza climbs far above where the melody sits.
      expect(song.pitchRange.$2, greaterThan(95));
      // Its accompaniment is the thickest in the library: chords three notes
      // deep on nearly every eighth, so it outnumbers the melody.
      expect(song.accompaniment.length, greaterThan(song.melody.length));
    });

    test('its engraving is credited, since that one is not public domain', () {
      // Chopin is long out of copyright but this typesetting is CC BY-SA,
      // which asks for the typesetter's name to travel with it.
      expect(shipped('nocturne-op9-no2').source, contains('CC BY-SA'));
      expect(shipped('nocturne-op9-no2').source, contains('Renato'));
    });
  });

  test('every note belongs to a hand', () {
    for (final song in shippedSongs) {
      expect(song.notes.length,
          song.melody.length + song.accompaniment.length);
      expect(song.notes.every((n) => n.hand == Hand.right || n.hand == Hand.left),
          isTrue);
    }
  });
}
