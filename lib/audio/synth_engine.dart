import 'dart:math' as math;
import 'dart:typed_data';

/// A small polyphonic piano synthesiser, in pure Dart.
///
/// It has no Flutter or platform dependency on purpose: the whole thing is a
/// function from note events to PCM samples, which means it can be unit tested
/// on the Dart VM without an audio device.
///
/// Sound design, briefly. A struck piano string is a stack of partials that
/// each decay at their own rate — the bright ones die first, which is why a
/// piano note grows darker as it rings. That single behaviour carries most of
/// the realism, so each partial here gets its own envelope. Two details on top:
/// partials sit slightly sharp of the pure harmonic series (inharmonicity, real
/// strings are stiff), and a short filtered noise burst stands in for the
/// hammer strike.
///
/// Everything is precomputed into per-sample multipliers, so the inner loop is
/// a handful of multiply-adds per partial and no transcendental calls.
class SynthEngine {
  SynthEngine({this.sampleRate = 44100, this.maxVoices = 24})
      : assert(sampleRate > 0),
        assert(maxVoices > 0) {
    for (var i = 0; i < _tableSize; i++) {
      _sine[i] = math.sin(2 * math.pi * i / _tableSize);
    }
    _voices = List.generate(maxVoices, (_) => _Voice(sampleRate));
  }

  final int sampleRate;
  final int maxVoices;

  static const int _tableSize = 2048;

  /// Where the cubic saturator x - x³/3 flattens out, at x = 1.
  static const double _saturationCeiling = 2.0 / 3.0;

  /// Restores the level the saturator takes off, less ~0.3 dB of headroom so
  /// even a saturated passage stays off full scale.
  static const double _makeupGain = 32767.0 / _saturationCeiling * 0.97;
  static final Float32List _sine = Float32List(_tableSize);

  late final List<_Voice> _voices;
  Float32List _mix = Float32List(0);

  /// Overall output level, before the soft clipper.
  double masterGain = 0.55;

  int get activeVoiceCount => _voices.where((v) => v.active).length;

  /// Start a note. [velocity] is 0..1 and controls both loudness and
  /// brightness, the way striking a key harder does.
  void noteOn(int midi, {double velocity = 0.8}) {
    final v = velocity.clamp(0.02, 1.0).toDouble();
    // Re-striking a sounding key restarts it, as a real damper-and-hammer does.
    final existing = _voices.where((x) => x.active && x.midi == midi);
    final voice = existing.isNotEmpty ? existing.first : _allocate();
    voice.start(midi, v, _sine);
  }

  /// Release a note: the damper falls and the string is silenced quickly.
  void noteOff(int midi) {
    for (final v in _voices) {
      if (v.active && v.midi == midi && !v.releasing) v.release();
    }
  }

  void allNotesOff() {
    for (final v in _voices) {
      if (v.active) v.release();
    }
  }

  /// Cut every voice immediately, without a release tail.
  void panic() {
    for (final v in _voices) {
      v.kill();
    }
  }

  /// Render the next [out].length mono samples as signed 16-bit PCM.
  void render(Int16List out) {
    final frames = out.length;
    if (_mix.length < frames) _mix = Float32List(frames);
    final mix = _mix;
    for (var i = 0; i < frames; i++) {
      mix[i] = 0;
    }

    for (final v in _voices) {
      if (v.active) v.addTo(mix, frames);
    }

    for (var i = 0; i < frames; i++) {
      // Soft clip: a cubic saturator, so a dense chord compresses instead of
      // tearing. Cheaper than tanh and indistinguishable here.
      //
      // The curve flattens out at _saturationCeiling, so that is what a loud
      // input has to be pinned to — clamping to 1.0 instead would let the
      // makeup gain below drive it straight into the rail, which is the
      // hard clipping this saturator exists to avoid.
      var x = mix[i] * masterGain;
      if (x > 1.0) {
        x = _saturationCeiling;
      } else if (x < -1.0) {
        x = -_saturationCeiling;
      } else {
        x = x - (x * x * x) / 3.0;
      }
      out[i] = (x * _makeupGain).round().clamp(-32768, 32767);
    }
  }

  /// Pick a free voice, otherwise steal the quietest sounding one.
  _Voice _allocate() {
    _Voice? quietest;
    for (final v in _voices) {
      if (!v.active) return v;
      if (quietest == null || v.loudness < quietest.loudness) quietest = v;
    }
    return quietest!;
  }
}

/// One sounding note.
class _Voice {
  _Voice(this.sampleRate);

  final int sampleRate;

  static const int _partialCount = 7;
  static const double _inharmonicity = 0.0004;

  final Float64List _phase = Float64List(_partialCount);
  final Float64List _increment = Float64List(_partialCount);
  final Float64List _amp = Float64List(_partialCount);
  final Float64List _decay = Float64List(_partialCount);

  late Float32List _table;

  int midi = -1;
  bool active = false;
  bool releasing = false;

  // Attack ramp, so a note starts at zero instead of clicking.
  double _attack = 0;
  double _attackStep = 0;

  // Hammer transient.
  double _noiseAmp = 0;
  double _noiseDecay = 0;
  double _noiseLp = 0;
  int _rng = 1;

  /// Rough current level, used to choose which voice to steal.
  double get loudness {
    var sum = 0.0;
    for (var i = 0; i < _partialCount; i++) {
      sum += _amp[i];
    }
    return sum;
  }

  void start(int note, double velocity, Float32List table) {
    _table = table;
    midi = note;
    active = true;
    releasing = false;

    final freq = 440.0 * math.pow(2, (note - 69) / 12.0);

    // Low strings ring for many seconds, the top octave barely at all.
    final baseDecay = 6.0 * math.pow(2.0, (60 - note) / 30.0).toDouble();

    // Harder strikes excite the upper partials far more than the fundamental;
    // this is what makes velocity read as brightness rather than just volume.
    final brightness = math.pow(velocity, 1.6).toDouble();

    for (var i = 0; i < _partialCount; i++) {
      final n = i + 1;
      // Stiff strings: partials sit progressively sharp of the harmonic series.
      final ratio = n * math.sqrt(1 + _inharmonicity * n * n);
      final partialFreq = freq * ratio;

      if (partialFreq >= sampleRate / 2) {
        // Above Nyquist this would alias back down as an audible whistle.
        _amp[i] = 0;
        _increment[i] = 0;
        _decay[i] = 0;
        continue;
      }

      _phase[i] = 0;
      _increment[i] = partialFreq * SynthEngine._tableSize / sampleRate;

      final gain = 1.0 / math.pow(n, 1.35);
      _amp[i] = gain * velocity * (i == 0 ? 1.0 : brightness);

      // Higher partials decay faster — the note darkens as it rings.
      final tau = baseDecay / (1.0 + 0.55 * i * i.toDouble()) / 6.9;
      _decay[i] = math.exp(-1.0 / (tau * sampleRate));
    }

    _attack = 0;
    _attackStep = 1.0 / (0.003 * sampleRate);

    _noiseAmp = 0.28 * velocity * velocity;
    _noiseDecay = math.exp(-1.0 / (0.006 * sampleRate));
    _noiseLp = 0;
    _rng = (note * 2654435761 + 1) & 0x7fffffff;
    if (_rng == 0) _rng = 1;
  }

  void release() {
    releasing = true;
    // A damper mutes the string in a couple of tenths of a second; bass
    // strings, being heavier, take a little longer. Slower than this and
    // consecutive notes would smear into each other.
    final tau = midi < 48 ? 0.15 : 0.08;
    final coef = math.exp(-1.0 / (tau * sampleRate));
    for (var i = 0; i < _partialCount; i++) {
      if (_decay[i] > coef) _decay[i] = coef;
    }
    _noiseAmp = 0;
  }

  void kill() {
    active = false;
    releasing = false;
    midi = -1;
    for (var i = 0; i < _partialCount; i++) {
      _amp[i] = 0;
    }
    _noiseAmp = 0;
  }

  void addTo(Float32List mix, int frames) {
    const table = SynthEngine._tableSize;
    final sine = _table;

    for (var f = 0; f < frames; f++) {
      var sample = 0.0;

      for (var i = 0; i < _partialCount; i++) {
        final amp = _amp[i];
        if (amp <= 1e-6) continue;

        var p = _phase[i] + _increment[i];
        if (p >= table) p -= table;
        _phase[i] = p;

        final idx = p.toInt();
        final frac = p - idx;
        final a = sine[idx];
        final b = sine[idx + 1 == table ? 0 : idx + 1];
        sample += (a + (b - a) * frac) * amp;

        _amp[i] = amp * _decay[i];
      }

      if (_noiseAmp > 1e-6) {
        // xorshift keeps the transient deterministic, which makes it testable.
        _rng ^= _rng << 13;
        _rng ^= _rng >> 17;
        _rng ^= _rng << 5;
        _rng &= 0x7fffffff;
        final white = (_rng / 0x3fffffff) - 1.0;
        // One-pole lowpass: an unfiltered burst reads as a click, not a hammer.
        _noiseLp += 0.35 * (white - _noiseLp);
        sample += _noiseLp * _noiseAmp;
        _noiseAmp *= _noiseDecay;
      }

      if (_attack < 1.0) {
        sample *= _attack;
        _attack += _attackStep;
      }

      mix[f] += sample;
    }

    if (loudness < 5e-5 && _noiseAmp < 1e-6) kill();
  }
}
