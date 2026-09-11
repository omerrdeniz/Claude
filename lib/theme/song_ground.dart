import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../music/note.dart';
import '../music/song.dart';
import 'app_theme.dart';

/// What key a piece is in, as far as its notes give it away.
class MusicalKey {
  const MusicalKey({required this.tonic, required this.minor});

  /// 0 for C, 1 for C♯, up to 11 for B.
  final int tonic;

  final bool minor;

  /// Where the key sits on the circle of fifths, 0 for C and stepping a fifth
  /// each time: C G D A E B F♯ …
  ///
  /// This, not the chromatic number, is the musical distance between two
  /// keys — C and G are neighbours, C and C♯ are as far apart as keys get —
  /// and it is what the ground is coloured by, so that pieces that sound
  /// related look related.
  int get fifths => (tonic * 7) % 12;

  @override
  bool operator ==(Object other) =>
      other is MusicalKey && other.tonic == tonic && other.minor == minor;

  @override
  int get hashCode => Object.hash(tonic, minor);

  static const _names = [
    'C', 'C♯', 'D', 'E♭', 'E', 'F', 'F♯', 'G', 'A♭', 'A', 'B♭', 'B',
  ];

  @override
  String toString() => '${_names[tonic]}${minor ? ' minor' : ' major'}';
}

/// The light each piece is played in, worked out from the piece.
///
/// This used to be a hand-written table: eight songs, eight grounds, chosen
/// by ear. The table's own comment argued that no rule could do it — that a
/// rule from the notes would get every one of them wrong. That was true of
/// the rule it had in mind, which was register: high means cold, low means
/// warm. Bach's prelude and Chopin's nocturne live in the same octaves and
/// have nothing else in common.
///
/// **Key is the rule that works.** It is the one fact about a piece that is
/// both musical and computable, it is what musicians themselves have always
/// reached for when they talk about a piece's colour, and — the part a table
/// can never have — it costs nothing per song. Nineteen songs became
/// nineteen grounds without a line written for any of them, and the
/// twentieth is already done.
///
/// Two pieces in the same key do come out alike. That is the point: D major
/// and A major are neighbours in sound and neighbours here, and the ground is
/// atmosphere rather than a name badge.
Ground groundOf(Song song) {
  final key = keyOf(song);
  if (key == null) return AppTheme.defaultGround;

  // Round the colour wheel by fifths, so neighbouring keys are neighbouring
  // hues. C is put at amber because C major is the plainest, warmest daylight
  // this game has in it — Bach's prelude and Mozart's sonata — and everything
  // else falls where the circle puts it.
  const cIsAmber = 42.0;
  final hue = (cIsAmber + key.fifths * 30 - (key.minor ? 14 : 0)) % 360;

  // Minor goes deeper and colder, major keeps a little more light in it.
  // Not a claim that minor is sad; a claim that the two should not look the
  // same, and this is the direction every listener already expects.
  final lift = song.notes.isEmpty ? 0.0 : _pace(song);
  return Ground(
    top: _lit(hue, key.minor ? 0.46 : 0.38, 0.0130 + lift * 0.0022),
    bottom: _lit(hue, 0.5, 0.0032),
    glow: _lit(hue, key.minor ? 0.58 : 0.66, 0.2000 + lift * 0.0450),
  );
}

/// A colour of this hue and saturation, taken down to a given weight on the
/// screen.
///
/// Not lightness: the same HSL lightness is a very different amount of light
/// depending on the hue — green at 0.12 glares where blue at 0.12 is nearly
/// black, and a ground picked by key would have been a lottery for how heavy
/// it looked. Luminance is what the eye actually receives, so it is what is
/// held level, and every key gets the same weight of ground.
Color _lit(double hue, double saturation, double luminance) {
  var low = 0.0, high = 1.0;
  var colour = HSLColor.fromAHSL(1, hue, saturation, 0.5).toColor();
  for (var step = 0; step < 14; step++) {
    final middle = (low + high) / 2;
    colour = HSLColor.fromAHSL(1, hue, saturation, middle).toColor();
    if (colour.computeLuminance() < luminance) {
      low = middle;
    } else {
      high = middle;
    }
  }
  return colour;
}

/// How busy the piece is, 0 for still and 1 for headlong.
///
/// Only ever a nudge: a fast piece gets a brighter pool of light at the line,
/// because a fast piece has more landing in it. It must not decide the
/// colour — pace is a property of the performance, key is a property of the
/// piece.
double _pace(Song song) {
  final seconds = song.lengthInBeats / song.bpm * 60;
  if (seconds <= 0) return 0;
  return ((song.notes.length / seconds - 3) / 6).clamp(0.0, 1.0);
}

/// Estimate what key a piece is in, or null if it has no notes.
///
/// Krumhansl-Schmuckler: weigh every pitch class by how long it sounds, then
/// see which of the twenty-four keys' profiles that weighting looks most
/// like. It is the standard method, it is a dozen lines, and it needs nothing
/// but the notes — no key signature, which is exactly what MIDI does not
/// carry.
///
/// Time, not count, is what is weighed. A passing note struck twenty times is
/// worth less than the note the phrase rests on, which is what tells a key
/// from its relative minor.
MusicalKey? keyOf(Song song) {
  if (song.notes.isEmpty) return null;

  final weight = List<double>.filled(12, 0);
  for (final note in song.notes) {
    weight[note.midi % 12] += note.duration;
  }

  // Where the bass starts and, above all, where it ends. Profiles alone
  // confuse a key with its dominant — the notes of A-flat major and E-flat
  // major are nearly the same handful — and the piece itself settles the
  // argument by coming home at the end. Chopin's Raindrop read as A-flat
  // against its own D-flat, the Pathétique as E-flat against its A-flat,
  // and the closing bass note fixed both.
  final bass = song.accompaniment.isEmpty ? song.notes : song.accompaniment;
  final home = _root(bass, bass.map((n) => n.beat).reduce(math.max));
  final opening = _root(bass, bass.map((n) => n.beat).reduce(math.min));

  MusicalKey? best;
  var bestFit = double.negativeInfinity;
  for (var tonic = 0; tonic < 12; tonic++) {
    for (final minor in [false, true]) {
      final profile = minor ? _minorProfile : _majorProfile;
      var fit = _correlation(weight, profile, tonic);
      if (tonic == home) fit += 0.20;
      if (tonic == opening) fit += 0.04;
      if (fit > bestFit) {
        bestFit = fit;
        best = MusicalKey(tonic: tonic, minor: minor);
      }
    }
  }
  return best;
}

/// The pitch class a chord stands on, taken as the lowest note sounding at
/// [beat].
///
/// Not simply the last note in the file: a final chord is several notes at
/// one moment, and which of them comes last in a list is an accident of how
/// the score was written. The Raindrop ends on D-flat with the A-flat it has
/// been repeating for four minutes still ringing on top of it, and picking
/// the wrong one of those two puts the whole piece a fifth away from itself.
int _root(Iterable<Note> notes, double beat) {
  var lowest = 128;
  for (final note in notes) {
    if ((note.beat - beat).abs() < 0.01 && note.midi < lowest) {
      lowest = note.midi;
    }
  }
  return lowest % 12;
}

/// How well a weighting matches one key's profile, rotated to that key.
double _correlation(List<double> weight, List<double> profile, int tonic) {
  var sumW = 0.0, sumP = 0.0;
  for (var i = 0; i < 12; i++) {
    sumW += weight[i];
    sumP += profile[i];
  }
  final meanW = sumW / 12, meanP = sumP / 12;

  var top = 0.0, varW = 0.0, varP = 0.0;
  for (var i = 0; i < 12; i++) {
    final w = weight[(tonic + i) % 12] - meanW;
    final p = profile[i] - meanP;
    top += w * p;
    varW += w * w;
    varP += p * p;
  }
  if (varW == 0 || varP == 0) return double.negativeInfinity;
  return top / math.sqrt(varW * varP);
}

/// Krumhansl and Kessler's profiles, from listeners rating how well each note
/// fits a key. Left exactly as published.
const List<double> _majorProfile = [
  6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88,
];
const List<double> _minorProfile = [
  6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17,
];
