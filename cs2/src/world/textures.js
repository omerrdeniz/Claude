// Prosedürel PBR doku üretimi: albedo + yükseklikten türetilmiş normal + pürüzlülük.
// Harici dosya kullanılmaz; her doku canvas 2D ile çizilir.

import * as THREE from 'three';

const cache = new Map();

function canvas(size) {
  const c = document.createElement('canvas');
  c.width = c.height = size;
  c.getContext('2d', { willReadFrequently: true });
  return c;
}

// Basit değer gürültüsü (deterministik, seed'li)
function makeRng(seed) {
  let s = seed >>> 0;
  return () => {
    s ^= s << 13; s >>>= 0;
    s ^= s >> 17;
    s ^= s << 5; s >>>= 0;
    return s / 4294967296;
  };
}

function fbm(ctx, size, { octaves = 4, alpha = 0.5, seed = 1, tint = '255,255,255' }) {
  const rng = makeRng(seed);
  for (let o = 0; o < octaves; o++) {
    const cells = 4 << o;
    const cell = size / cells;
    const a = alpha / (o + 1);
    for (let y = 0; y < cells; y++) {
      for (let x = 0; x < cells; x++) {
        const v = rng();
        ctx.fillStyle = `rgba(${tint},${(a * v).toFixed(3)})`;
        ctx.fillRect(x * cell, y * cell, cell + 1, cell + 1);
      }
    }
  }
}

function grain(ctx, size, amount, seed) {
  const rng = makeRng(seed);
  const img = ctx.getImageData(0, 0, size, size);
  const d = img.data;
  for (let i = 0; i < d.length; i += 4) {
    const n = (rng() - 0.5) * amount;
    d[i] = Math.max(0, Math.min(255, d[i] + n));
    d[i + 1] = Math.max(0, Math.min(255, d[i + 1] + n));
    d[i + 2] = Math.max(0, Math.min(255, d[i + 2] + n));
  }
  ctx.putImageData(img, 0, 0);
}

// Yükseklik haritasından normal haritası (Sobel).
function normalFromHeight(heightCanvas, strength = 2.2) {
  const size = heightCanvas.width;
  const src = heightCanvas.getContext('2d').getImageData(0, 0, size, size).data;
  const out = canvas(size);
  const ctx = out.getContext('2d');
  const img = ctx.createImageData(size, size);
  const h = (x, y) => {
    const xx = (x + size) % size;
    const yy = (y + size) % size;
    return src[(yy * size + xx) * 4] / 255;
  };
  for (let y = 0; y < size; y++) {
    for (let x = 0; x < size; x++) {
      const dx = (h(x - 1, y) - h(x + 1, y)) * strength;
      const dy = (h(x, y - 1) - h(x, y + 1)) * strength;
      const len = Math.hypot(dx, dy, 1);
      const i = (y * size + x) * 4;
      img.data[i] = ((dx / len) * 0.5 + 0.5) * 255;
      img.data[i + 1] = ((dy / len) * 0.5 + 0.5) * 255;
      img.data[i + 2] = ((1 / len) * 0.5 + 0.5) * 255;
      img.data[i + 3] = 255;
    }
  }
  ctx.putImageData(img, 0, 0);
  return out;
}

// Yükseklikten pürüzlülük: girintiler daha mat.
function roughFromHeight(heightCanvas, base = 0.75, contrast = 0.35) {
  const size = heightCanvas.width;
  const src = heightCanvas.getContext('2d').getImageData(0, 0, size, size).data;
  const out = canvas(size);
  const ctx = out.getContext('2d');
  const img = ctx.createImageData(size, size);
  for (let i = 0; i < src.length; i += 4) {
    const hgt = src[i] / 255;
    const v = Math.max(0, Math.min(1, base + (0.5 - hgt) * contrast));
    img.data[i] = img.data[i + 1] = img.data[i + 2] = v * 255;
    img.data[i + 3] = 255;
  }
  ctx.putImageData(img, 0, 0);
  return out;
}

function texture(c, repeatX, repeatY, srgb) {
  const t = new THREE.CanvasTexture(c);
  t.wrapS = t.wrapT = THREE.RepeatWrapping;
  t.repeat.set(repeatX, repeatY);
  t.anisotropy = 8;
  if (srgb) t.colorSpace = THREE.SRGBColorSpace;
  return t;
}

// --- Doku çizicileri -------------------------------------------------
const DRAWERS = {
  // Kum taşı blok duvar
  sandstone(albedo, height, size) {
    const a = albedo.getContext('2d');
    const h = height.getContext('2d');
    const rng = makeRng(7);
    a.fillStyle = '#5c5138'; a.fillRect(0, 0, size, size);
    h.fillStyle = '#303030'; h.fillRect(0, 0, size, size);
    const rows = 6;
    const rh = size / rows;
    for (let r = 0; r < rows; r++) {
      const offset = (r % 2) * rh * 0.9;
      const cols = 3;
      const cw = size / cols;
      for (let c = -1; c <= cols; c++) {
        const x = c * cw + offset;
        const y = r * rh;
        const shade = 0.82 + rng() * 0.3;
        const base = [196, 168, 116].map((v) => Math.min(255, v * shade));
        a.fillStyle = `rgb(${base[0] | 0},${base[1] | 0},${base[2] | 0})`;
        a.fillRect(x + 2, y + 2, cw - 4, rh - 4);
        h.fillStyle = `rgb(${(190 + rng() * 40) | 0},0,0)`;
        h.fillRect(x + 2, y + 2, cw - 4, rh - 4);
        // blok içi leke
        a.fillStyle = `rgba(120,104,74,${0.05 + rng() * 0.12})`;
        a.fillRect(x + 4 + rng() * cw * 0.4, y + 4 + rng() * rh * 0.4, cw * 0.35, rh * 0.35);
      }
    }
    fbm(a, size, { octaves: 4, alpha: 0.18, seed: 3, tint: '110,96,70' });
    grain(a, size, 16, 11);
    grain(h, size, 22, 12);
  },

  // Sıvalı duvar
  plaster(albedo, height, size) {
    const a = albedo.getContext('2d');
    const h = height.getContext('2d');
    const rng = makeRng(21);
    a.fillStyle = '#a99c83'; a.fillRect(0, 0, size, size);
    h.fillStyle = '#9a9a9a'; h.fillRect(0, 0, size, size);
    fbm(a, size, { octaves: 5, alpha: 0.3, seed: 5, tint: '140,128,106' });
    fbm(h, size, { octaves: 5, alpha: 0.25, seed: 5, tint: '60,60,60' });
    // dökülmüş sıva lekeleri
    for (let i = 0; i < 12; i++) {
      const x = rng() * size;
      const y = rng() * size;
      const r = 6 + rng() * 26;
      a.fillStyle = `rgba(150,136,110,${0.25 + rng() * 0.3})`;
      a.beginPath(); a.arc(x, y, r, 0, Math.PI * 2); a.fill();
      h.fillStyle = 'rgba(40,40,40,0.5)';
      h.beginPath(); h.arc(x, y, r, 0, Math.PI * 2); h.fill();
    }
    grain(a, size, 12, 31);
  },

  // Beton
  concrete(albedo, height, size) {
    const a = albedo.getContext('2d');
    const h = height.getContext('2d');
    const rng = makeRng(41);
    a.fillStyle = '#7e7d78'; a.fillRect(0, 0, size, size);
    h.fillStyle = '#8c8c8c'; h.fillRect(0, 0, size, size);
    fbm(a, size, { octaves: 5, alpha: 0.28, seed: 9, tint: '60,60,58' });
    fbm(h, size, { octaves: 5, alpha: 0.22, seed: 9, tint: '40,40,40' });
    // çatlaklar
    for (let i = 0; i < 5; i++) {
      let x = rng() * size;
      let y = rng() * size;
      a.strokeStyle = 'rgba(60,58,54,0.5)';
      h.strokeStyle = 'rgba(0,0,0,0.7)';
      a.lineWidth = 1 + rng();
      h.lineWidth = a.lineWidth;
      a.beginPath(); a.moveTo(x, y);
      h.beginPath(); h.moveTo(x, y);
      for (let s = 0; s < 8; s++) {
        x += (rng() - 0.5) * 40;
        y += (rng() - 0.5) * 40;
        a.lineTo(x, y);
        h.lineTo(x, y);
      }
      a.stroke(); h.stroke();
    }
    grain(a, size, 14, 51);
  },

  // Ahşap tahta
  wood(albedo, height, size) {
    const a = albedo.getContext('2d');
    const h = height.getContext('2d');
    const rng = makeRng(63);
    const planks = 5;
    const pw = size / planks;
    for (let p = 0; p < planks; p++) {
      const shade = 0.78 + rng() * 0.4;
      a.fillStyle = `rgb(${(150 * shade) | 0},${(102 * shade) | 0},${(56 * shade) | 0})`;
      a.fillRect(p * pw, 0, pw, size);
      h.fillStyle = `rgb(${(150 + rng() * 60) | 0},0,0)`;
      h.fillRect(p * pw, 0, pw, size);
      // damar çizgileri
      for (let g = 0; g < 26; g++) {
        const y = rng() * size;
        a.strokeStyle = `rgba(90,58,28,${0.08 + rng() * 0.22})`;
        a.lineWidth = 0.6 + rng() * 1.6;
        a.beginPath();
        a.moveTo(p * pw, y);
        a.bezierCurveTo(p * pw + pw * 0.3, y + (rng() - 0.5) * 12,
          p * pw + pw * 0.7, y + (rng() - 0.5) * 12, p * pw + pw, y + (rng() - 0.5) * 6);
        a.stroke();
      }
      // budak
      if (rng() < 0.5) {
        const kx = p * pw + pw * (0.3 + rng() * 0.4);
        const ky = rng() * size;
        for (let r = 8; r > 0; r--) {
          a.strokeStyle = `rgba(70,44,20,${0.3 - r * 0.02})`;
          a.beginPath(); a.ellipse(kx, ky, r * 1.6, r, 0, 0, Math.PI * 2); a.stroke();
        }
      }
      // tahta arası boşluk
      a.fillStyle = 'rgba(30,20,10,0.75)';
      a.fillRect(p * pw - 1.5, 0, 3, size);
      h.fillStyle = 'rgba(0,0,0,0.85)';
      h.fillRect(p * pw - 1.5, 0, 3, size);
    }
    grain(a, size, 10, 71);
  },

  // Metal panel + perçin
  metal(albedo, height, size) {
    const a = albedo.getContext('2d');
    const h = height.getContext('2d');
    const rng = makeRng(83);
    a.fillStyle = '#55595e'; a.fillRect(0, 0, size, size);
    h.fillStyle = '#b4b4b4'; h.fillRect(0, 0, size, size);
    // fırçalama
    for (let i = 0; i < 900; i++) {
      const y = rng() * size;
      a.strokeStyle = `rgba(255,255,255,${rng() * 0.05})`;
      a.beginPath(); a.moveTo(0, y); a.lineTo(size, y); a.stroke();
    }
    // panel çizgileri
    a.strokeStyle = 'rgba(35,38,42,0.9)';
    h.strokeStyle = 'rgba(0,0,0,0.9)';
    a.lineWidth = h.lineWidth = 3;
    a.strokeRect(4, 4, size - 8, size - 8);
    h.strokeRect(4, 4, size - 8, size - 8);
    // perçinler
    for (let i = 0; i < 16; i++) {
      const t = (i / 16) * Math.PI * 2;
      const x = size / 2 + Math.cos(t) * (size / 2 - 14);
      const y = size / 2 + Math.sin(t) * (size / 2 - 14);
      a.fillStyle = '#8b9095';
      a.beginPath(); a.arc(x, y, 3.2, 0, Math.PI * 2); a.fill();
      h.fillStyle = '#ffffff';
      h.beginPath(); h.arc(x, y, 3.2, 0, Math.PI * 2); h.fill();
    }
    // pas lekeleri
    for (let i = 0; i < 6; i++) {
      a.fillStyle = `rgba(120,70,40,${0.1 + rng() * 0.2})`;
      a.beginPath(); a.arc(rng() * size, rng() * size, 6 + rng() * 20, 0, Math.PI * 2); a.fill();
    }
    grain(a, size, 8, 91);
  },

  // Zemin: sıkışmış toprak + çakıl
  ground(albedo, height, size) {
    const a = albedo.getContext('2d');
    const h = height.getContext('2d');
    const rng = makeRng(101);
    a.fillStyle = '#8d7c58'; a.fillRect(0, 0, size, size);
    h.fillStyle = '#808080'; h.fillRect(0, 0, size, size);
    fbm(a, size, { octaves: 6, alpha: 0.3, seed: 13, tint: '90,78,56' });
    fbm(h, size, { octaves: 6, alpha: 0.3, seed: 13, tint: '70,70,70' });
    for (let i = 0; i < 260; i++) {
      const x = rng() * size;
      const y = rng() * size;
      const r = 1 + rng() * 3.4;
      const v = 120 + rng() * 90;
      a.fillStyle = `rgba(${v | 0},${(v * 0.92) | 0},${(v * 0.76) | 0},0.9)`;
      a.beginPath(); a.arc(x, y, r, 0, Math.PI * 2); a.fill();
      h.fillStyle = `rgba(255,255,255,${0.25 + rng() * 0.4})`;
      h.beginPath(); h.arc(x, y, r, 0, Math.PI * 2); h.fill();
    }
    grain(a, size, 14, 111);
  },

  // Kasa: tahta + metal köşebent
  crate(albedo, height, size) {
    DRAWERS.wood(albedo, height, size);
    const a = albedo.getContext('2d');
    const h = height.getContext('2d');
    a.fillStyle = '#4a4a4d';
    h.fillStyle = '#e8e8e8';
    const band = size * 0.09;
    for (const [x, y, w, hh] of [[0, 0, size, band], [0, size - band, size, band],
      [0, 0, band, size], [size - band, 0, band, size]]) {
      a.fillRect(x, y, w, hh);
      h.fillRect(x, y, w, hh);
    }
    // damga
    a.save();
    a.translate(size / 2, size / 2);
    a.rotate(-0.06);
    a.strokeStyle = 'rgba(40,30,18,0.35)';
    a.lineWidth = 4;
    a.strokeRect(-size * 0.22, -size * 0.14, size * 0.44, size * 0.28);
    a.fillStyle = 'rgba(40,30,18,0.32)';
    a.font = `bold ${Math.round(size * 0.11)}px Arial`;
    a.textAlign = 'center';
    a.textBaseline = 'middle';
    a.fillText('CARGO', 0, 0);
    a.restore();
  },

  // Kum torbası / branda
  fabric(albedo, height, size) {
    const a = albedo.getContext('2d');
    const h = height.getContext('2d');
    a.fillStyle = '#9a8a63'; a.fillRect(0, 0, size, size);
    h.fillStyle = '#8a8a8a'; h.fillRect(0, 0, size, size);
    for (let y = 0; y < size; y += 3) {
      a.strokeStyle = `rgba(70,60,40,${y % 6 === 0 ? 0.22 : 0.12})`;
      a.beginPath(); a.moveTo(0, y); a.lineTo(size, y); a.stroke();
      h.strokeStyle = `rgba(0,0,0,${y % 6 === 0 ? 0.35 : 0.15})`;
      h.beginPath(); h.moveTo(0, y); h.lineTo(size, y); h.stroke();
    }
    for (let x = 0; x < size; x += 3) {
      a.strokeStyle = 'rgba(120,106,74,0.16)';
      a.beginPath(); a.moveTo(x, 0); a.lineTo(x, size); a.stroke();
    }
    fbm(a, size, { octaves: 4, alpha: 0.22, seed: 17, tint: '80,70,48' });
    grain(a, size, 10, 121);
  },
};

const SETTINGS = {
  sandstone: { size: 512, normal: 2.4, rough: [0.88, 0.22], metal: 0 },
  plaster: { size: 512, normal: 1.5, rough: [0.92, 0.14], metal: 0 },
  concrete: { size: 512, normal: 1.6, rough: [0.9, 0.18], metal: 0 },
  wood: { size: 512, normal: 1.8, rough: [0.8, 0.24], metal: 0 },
  metal: { size: 512, normal: 2.0, rough: [0.42, 0.3], metal: 0.85 },
  ground: { size: 512, normal: 2.2, rough: [0.95, 0.16], metal: 0 },
  crate: { size: 512, normal: 2.0, rough: [0.82, 0.24], metal: 0.1 },
  fabric: { size: 512, normal: 1.9, rough: [0.96, 0.1], metal: 0 },
};

// Belirli bir malzeme için doku setini üretir (önbellekli).
export function textureSet(name) {
  if (cache.has(name)) return cache.get(name);
  const cfg = SETTINGS[name] || SETTINGS.concrete;
  const size = cfg.size;
  const albedo = canvas(size);
  const height = canvas(size);
  (DRAWERS[name] || DRAWERS.concrete)(albedo, height, size);
  const set = {
    map: texture(albedo, 1, 1, true),
    normalMap: texture(normalFromHeight(height, cfg.normal), 1, 1, false),
    roughnessMap: texture(roughFromHeight(height, cfg.rough[0], cfg.rough[1]), 1, 1, false),
    metalness: cfg.metal,
  };
  cache.set(name, set);
  return set;
}

// Malzeme üretir; tekrar sayısı yüzey büyüklüğüne göre ayarlanır.
export function pbrMaterial(name, { repeat = 1, color = 0xffffff, normalScale = 1 } = {}) {
  const set = textureSet(name);
  const map = set.map.clone();
  const normalMap = set.normalMap.clone();
  const roughnessMap = set.roughnessMap.clone();
  for (const t of [map, normalMap, roughnessMap]) {
    t.needsUpdate = true;
    t.wrapS = t.wrapT = THREE.RepeatWrapping;
    t.repeat.set(repeat, repeat);
    t.anisotropy = 8;
  }
  map.colorSpace = THREE.SRGBColorSpace;
  return new THREE.MeshStandardMaterial({
    color,
    map,
    normalMap,
    roughnessMap,
    normalScale: new THREE.Vector2(normalScale, normalScale),
    metalness: set.metalness,
    envMapIntensity: 0.3,
  });
}

export function clearTextureCache() {
  cache.clear();
}
