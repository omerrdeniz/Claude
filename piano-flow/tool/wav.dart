import 'dart:io';
import 'dart:typed_data';

/// Write mono 16-bit samples to a WAV file.
void writeWav(String path, List<int> samples, {int sampleRate = 44100}) {
  const channels = 1;
  const bitsPerSample = 16;
  final dataBytes = samples.length * 2;
  final bytes = BytesBuilder();

  void ascii(String s) => bytes.add(s.codeUnits);
  void u32(int v) =>
      bytes.add(Uint8List(4)..buffer.asByteData().setUint32(0, v, Endian.little));
  void u16(int v) =>
      bytes.add(Uint8List(2)..buffer.asByteData().setUint16(0, v, Endian.little));

  ascii('RIFF');
  u32(36 + dataBytes);
  ascii('WAVE');
  ascii('fmt ');
  u32(16);
  u16(1); // PCM
  u16(channels);
  u32(sampleRate);
  u32(sampleRate * channels * bitsPerSample ~/ 8);
  u16(channels * bitsPerSample ~/ 8);
  u16(bitsPerSample);
  ascii('data');
  u32(dataBytes);

  final pcm = ByteData(dataBytes);
  for (var i = 0; i < samples.length; i++) {
    pcm.setInt16(i * 2, samples[i], Endian.little);
  }
  bytes.add(pcm.buffer.asUint8List());
  File(path).writeAsBytesSync(bytes.toBytes());
}
