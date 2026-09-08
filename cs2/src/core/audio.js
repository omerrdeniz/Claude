// WebAudio ile prosedürel ses efektleri (harici dosya yok).

export class AudioEngine {
  constructor(volume = 0.6) {
    this.ctx = null;
    this.master = null;
    this.noiseBuffer = null;
    this.volume = volume;
    this.enabled = true;
    this.listener = { x: 0, y: 0, z: 0, yaw: 0 };
  }

  init() {
    if (this.ctx) return;
    const Ctx = window.AudioContext || window.webkitAudioContext;
    if (!Ctx) { this.enabled = false; return; }
    this.ctx = new Ctx();
    this.master = this.ctx.createGain();
    this.master.gain.value = this.volume;
    this.master.connect(this.ctx.destination);

    const len = Math.floor(this.ctx.sampleRate * 1.0);
    const buf = this.ctx.createBuffer(1, len, this.ctx.sampleRate);
    const data = buf.getChannelData(0);
    for (let i = 0; i < len; i++) data[i] = Math.random() * 2 - 1;
    this.noiseBuffer = buf;
  }

  resume() {
    if (!this.ctx) this.init();
    if (this.ctx && this.ctx.state === 'suspended') this.ctx.resume();
  }

  setVolume(v) {
    this.volume = v;
    if (this.master) this.master.gain.value = v;
  }

  setListener(pos, yaw) {
    this.listener.x = pos.x;
    this.listener.y = pos.y;
    this.listener.z = pos.z;
    this.listener.yaw = yaw;
  }

  // Konumsal kazanç ve stereo pan hesapla.
  _spatial(pos, maxDist) {
    if (!pos) return { gain: 1, pan: 0 };
    const dx = pos.x - this.listener.x;
    const dy = pos.y - this.listener.y;
    const dz = pos.z - this.listener.z;
    const dist = Math.hypot(dx, dy, dz);
    const gain = Math.max(0, 1 - dist / maxDist) ** 1.6;
    // Dinleyici yaw'ına göre sağ vektör
    const rx = Math.cos(this.listener.yaw);
    const rz = -Math.sin(this.listener.yaw);
    const pan = dist > 0.01 ? Math.max(-1, Math.min(1, (dx * rx + dz * rz) / dist)) : 0;
    return { gain, pan, dist };
  }

  _out(gainValue, pan) {
    const g = this.ctx.createGain();
    g.gain.value = gainValue;
    if (this.ctx.createStereoPanner) {
      const p = this.ctx.createStereoPanner();
      p.pan.value = pan;
      g.connect(p);
      p.connect(this.master);
    } else {
      g.connect(this.master);
    }
    return g;
  }

  _noise(dest, duration, filterType, freq, q = 1) {
    const src = this.ctx.createBufferSource();
    src.buffer = this.noiseBuffer;
    src.loop = true;
    const filter = this.ctx.createBiquadFilter();
    filter.type = filterType;
    filter.frequency.value = freq;
    filter.Q.value = q;
    src.connect(filter);
    filter.connect(dest);
    src.start();
    src.stop(this.ctx.currentTime + duration + 0.05);
    return { src, filter };
  }

  play(name, opts = {}) {
    if (!this.enabled) return;
    if (!this.ctx) this.init();
    if (!this.ctx || this.ctx.state !== 'running') return;
    const maxDist = opts.maxDist || 55;
    const { gain, pan } = this._spatial(opts.pos, maxDist);
    const vol = (opts.volume ?? 1) * gain;
    if (vol <= 0.001) return;
    const t = this.ctx.currentTime;

    switch (name) {
      case 'shot': {
        const kind = opts.kind || 'rifle';
        const cfg = {
          rifle: { dur: 0.24, freq: 1800, boom: 110, level: 1.0 },
          smg: { dur: 0.17, freq: 2400, boom: 150, level: 0.8 },
          pistol: { dur: 0.16, freq: 2600, boom: 180, level: 0.75 },
          sniper: { dur: 0.5, freq: 1200, boom: 80, level: 1.3 },
          silenced: { dur: 0.12, freq: 3200, boom: 260, level: 0.4 },
        }[kind] || { dur: 0.2, freq: 2000, boom: 130, level: 0.9 };
        const out = this._out(vol * 0.55 * cfg.level, pan);
        out.gain.setValueAtTime(vol * 0.55 * cfg.level, t);
        out.gain.exponentialRampToValueAtTime(0.0008, t + cfg.dur);
        this._noise(out, cfg.dur, 'bandpass', cfg.freq, 0.7);
        // Alçak frekans patlama
        const osc = this.ctx.createOscillator();
        const og = this.ctx.createGain();
        osc.type = 'sine';
        osc.frequency.setValueAtTime(cfg.boom, t);
        osc.frequency.exponentialRampToValueAtTime(cfg.boom * 0.45, t + cfg.dur);
        og.gain.setValueAtTime(vol * 0.5 * cfg.level, t);
        og.gain.exponentialRampToValueAtTime(0.0008, t + cfg.dur);
        osc.connect(og);
        og.connect(this.master);
        osc.start(t);
        osc.stop(t + cfg.dur + 0.02);
        break;
      }
      case 'impact': {
        const mat = opts.mat || 'concrete';
        const cfg = {
          concrete: { freq: 1400, dur: 0.09 },
          wood: { freq: 900, dur: 0.10 },
          metal: { freq: 3200, dur: 0.16 },
          flesh: { freq: 500, dur: 0.10 },
        }[mat] || { freq: 1200, dur: 0.09 };
        const out = this._out(vol * 0.35, pan);
        out.gain.setValueAtTime(vol * 0.35, t);
        out.gain.exponentialRampToValueAtTime(0.0008, t + cfg.dur);
        this._noise(out, cfg.dur, 'bandpass', cfg.freq, mat === 'metal' ? 6 : 1.5);
        break;
      }
      case 'hitmarker':
      case 'headshot': {
        const out = this._out(vol * 0.4, 0);
        const osc = this.ctx.createOscillator();
        osc.type = 'square';
        const base = name === 'headshot' ? 1400 : 900;
        osc.frequency.setValueAtTime(base, t);
        osc.frequency.exponentialRampToValueAtTime(base * 1.6, t + 0.05);
        out.gain.setValueAtTime(vol * 0.25, t);
        out.gain.exponentialRampToValueAtTime(0.0008, t + 0.09);
        osc.connect(out);
        osc.start(t);
        osc.stop(t + 0.1);
        break;
      }
      case 'footstep': {
        const out = this._out(vol * 0.22, pan);
        out.gain.setValueAtTime(vol * 0.22, t);
        out.gain.exponentialRampToValueAtTime(0.0008, t + 0.08);
        this._noise(out, 0.08, 'bandpass', 620 + Math.random() * 260, 1.2);
        break;
      }
      case 'reload': {
        const out = this._out(vol * 0.3, pan);
        out.gain.setValueAtTime(vol * 0.3, t);
        out.gain.exponentialRampToValueAtTime(0.0008, t + 0.07);
        this._noise(out, 0.07, 'highpass', 2400, 1);
        break;
      }
      case 'empty': {
        const out = this._out(vol * 0.25, pan);
        out.gain.setValueAtTime(vol * 0.25, t);
        out.gain.exponentialRampToValueAtTime(0.0008, t + 0.05);
        this._noise(out, 0.05, 'highpass', 4000, 1);
        break;
      }
      case 'knife': {
        const out = this._out(vol * 0.3, pan);
        out.gain.setValueAtTime(vol * 0.3, t);
        out.gain.exponentialRampToValueAtTime(0.0008, t + 0.12);
        this._noise(out, 0.12, 'highpass', 1800, 0.8);
        break;
      }
      case 'explosion': {
        const out = this._out(vol * 0.9, pan);
        out.gain.setValueAtTime(vol * 0.9, t);
        out.gain.exponentialRampToValueAtTime(0.0008, t + 0.9);
        this._noise(out, 0.9, 'lowpass', 700, 0.8);
        const osc = this.ctx.createOscillator();
        const og = this.ctx.createGain();
        osc.type = 'sine';
        osc.frequency.setValueAtTime(80, t);
        osc.frequency.exponentialRampToValueAtTime(28, t + 0.7);
        og.gain.setValueAtTime(vol * 0.8, t);
        og.gain.exponentialRampToValueAtTime(0.0008, t + 0.8);
        osc.connect(og); og.connect(this.master);
        osc.start(t); osc.stop(t + 0.85);
        break;
      }
      case 'beep': {
        const out = this._out(vol * 0.35, pan);
        const osc = this.ctx.createOscillator();
        osc.type = 'sine';
        osc.frequency.value = opts.freq || 1800;
        out.gain.setValueAtTime(vol * 0.3, t);
        out.gain.exponentialRampToValueAtTime(0.0008, t + 0.12);
        osc.connect(out);
        osc.start(t);
        osc.stop(t + 0.13);
        break;
      }
      case 'ui': {
        const out = this._out(vol * 0.25, 0);
        const osc = this.ctx.createOscillator();
        osc.type = 'triangle';
        osc.frequency.setValueAtTime(opts.freq || 620, t);
        out.gain.setValueAtTime(vol * 0.2, t);
        out.gain.exponentialRampToValueAtTime(0.0008, t + 0.16);
        osc.connect(out);
        osc.start(t);
        osc.stop(t + 0.17);
        break;
      }
      case 'roundstart': {
        for (let i = 0; i < 3; i++) {
          const out = this._out(vol * 0.22, 0);
          const osc = this.ctx.createOscillator();
          osc.type = 'sawtooth';
          osc.frequency.value = [330, 440, 550][i];
          const st = t + i * 0.12;
          out.gain.setValueAtTime(0.0001, st);
          out.gain.linearRampToValueAtTime(vol * 0.2, st + 0.02);
          out.gain.exponentialRampToValueAtTime(0.0008, st + 0.3);
          osc.connect(out);
          osc.start(st);
          osc.stop(st + 0.32);
        }
        break;
      }
      default:
        break;
    }
  }
}
