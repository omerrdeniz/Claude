import 'dart:typed_data';

/// A recorded piano, one note every minor third.
///
/// This exists because a synthesised piano was not good enough. Seven partials
/// and a noise burst is a convincing enough middle register and an unpleasant
/// treble — and no amount of tuning the partials fixed it, because the problem
/// was never the timbre of one note. It was the balance between them.
///
/// A real instrument is dramatically quieter at the top: in these recordings
/// D sharp 7 comes in about eighteen decibels under middle C for the same
/// strike. A synthesiser gives every note the amplitude it is asked for, so
/// the treble arrives at full level in the band the ear is most sensitive to,
/// and a piece that lives high — Chopin's nocturne — comes out piercing.
/// Carrying the recordings carries that balance with them, measured off a real
/// piano rather than guessed at.
///
/// Nothing here touches Flutter: this parses bytes, and where those bytes came
/// from is the caller's business.
class SampleBank {
  SampleBank._({
    required this.sampleRate,
    required this.midis,
    required this.samples,
  });

  /// Rate the recordings were stored at, which need not be the engine's.
  final int sampleRate;

  /// The pitch of each recording, ascending.
  final List<int> midis;

  /// The recordings, parallel to [midis].
  final List<Int16List> samples;

  bool get isEmpty => midis.isEmpty;

  /// Read a bank built by `tool/fetch_samples.dart`.
  ///
  /// Layout: 'PFPB', a version byte, the sample rate and the note count, then
  /// a (pitch, length) pair per note, then all the PCM back to back.
  static SampleBank parse(Uint8List bytes) {
    if (bytes.length < 11 ||
        String.fromCharCodes(bytes.sublist(0, 4)) != 'PFPB') {
      throw const FormatException('Not a Piano Flow sample bank');
    }
    final view = ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.length);
    var at = 4;
    final version = view.getUint8(at++);
    if (version != 1) {
      throw FormatException('Sample bank version $version is not supported');
    }
    final rate = view.getUint32(at, Endian.little);
    at += 4;
    final count = view.getUint16(at, Endian.little);
    at += 2;

    final midis = <int>[];
    final lengths = <int>[];
    for (var i = 0; i < count; i++) {
      midis.add(view.getUint8(at));
      at += 1;
      lengths.add(view.getUint32(at, Endian.little));
      at += 4;
    }

    final samples = <Int16List>[];
    for (var i = 0; i < count; i++) {
      final length = lengths[i];
      if (at + length * 2 > bytes.length) {
        throw const FormatException('Sample bank is truncated');
      }
      final data = Int16List(length);
      for (var k = 0; k < length; k++) {
        data[k] = view.getInt16(at + k * 2, Endian.little);
      }
      samples.add(data);
      at += length * 2;
    }

    return SampleBank._(sampleRate: rate, midis: midis, samples: samples);
  }

  /// The recording to play [midi] from: the nearest one in pitch.
  ///
  /// With a note every minor third nothing is stretched by more than a tone
  /// and a half, which resampling carries without sounding like a tape.
  int nearestTo(int midi) {
    var best = 0;
    var bestDistance = (midis[0] - midi).abs();
    for (var i = 1; i < midis.length; i++) {
      final distance = (midis[i] - midi).abs();
      if (distance < bestDistance) {
        best = i;
        bestDistance = distance;
      }
    }
    return best;
  }
}
