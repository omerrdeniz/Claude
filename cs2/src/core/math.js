// Eksen hizalı kutu (AABB) matematiği: çarpışma, ışın testi ve küçük yardımcılar.

export function makeBox(cx, cy, cz, sx, sy, sz, meta = {}) {
  return {
    minX: cx - sx / 2, maxX: cx + sx / 2,
    minY: cy - sy / 2, maxY: cy + sy / 2,
    minZ: cz - sz / 2, maxZ: cz + sz / 2,
    ...meta,
  };
}

// x0..x1 / z0..z1 aralığı ve yükseklikten kutu üretir (harita tanımı için pratik).
export function boxFromRect(x0, z0, x1, z1, y0, y1, meta = {}) {
  return {
    minX: Math.min(x0, x1), maxX: Math.max(x0, x1),
    minY: y0, maxY: y1,
    minZ: Math.min(z0, z1), maxZ: Math.max(z0, z1),
    ...meta,
  };
}

export function boxOverlap(a, b) {
  return a.minX < b.maxX && a.maxX > b.minX &&
         a.minY < b.maxY && a.maxY > b.minY &&
         a.minZ < b.maxZ && a.maxZ > b.minZ;
}

export function pointInBoxXZ(x, z, b) {
  return x >= b.minX && x <= b.maxX && z >= b.minZ && z <= b.maxZ;
}

export function boxCenter(b, out = {}) {
  out.x = (b.minX + b.maxX) / 2;
  out.y = (b.minY + b.maxY) / 2;
  out.z = (b.minZ + b.maxZ) / 2;
  return out;
}

const EPS = 1e-6;

// Işın - AABB kesişimi. Kesişme yoksa null döner.
// Dönen normal, ışının çarptığı yüzeyin normalidir.
export function rayBox(ox, oy, oz, dx, dy, dz, b, maxT) {
  let tmin = 0;
  let tmax = maxT;
  let nAxis = 0;
  let nSign = 0;

  // X ekseni
  if (Math.abs(dx) < EPS) {
    if (ox < b.minX || ox > b.maxX) return null;
  } else {
    const inv = 1 / dx;
    let t1 = (b.minX - ox) * inv;
    let t2 = (b.maxX - ox) * inv;
    let sign = -1;
    if (t1 > t2) { const tmp = t1; t1 = t2; t2 = tmp; sign = 1; }
    if (t1 > tmin) { tmin = t1; nAxis = 0; nSign = sign; }
    if (t2 < tmax) tmax = t2;
    if (tmin > tmax) return null;
  }

  // Y ekseni
  if (Math.abs(dy) < EPS) {
    if (oy < b.minY || oy > b.maxY) return null;
  } else {
    const inv = 1 / dy;
    let t1 = (b.minY - oy) * inv;
    let t2 = (b.maxY - oy) * inv;
    let sign = -1;
    if (t1 > t2) { const tmp = t1; t1 = t2; t2 = tmp; sign = 1; }
    if (t1 > tmin) { tmin = t1; nAxis = 1; nSign = sign; }
    if (t2 < tmax) tmax = t2;
    if (tmin > tmax) return null;
  }

  // Z ekseni
  if (Math.abs(dz) < EPS) {
    if (oz < b.minZ || oz > b.maxZ) return null;
  } else {
    const inv = 1 / dz;
    let t1 = (b.minZ - oz) * inv;
    let t2 = (b.maxZ - oz) * inv;
    let sign = -1;
    if (t1 > t2) { const tmp = t1; t1 = t2; t2 = tmp; sign = 1; }
    if (t1 > tmin) { tmin = t1; nAxis = 2; nSign = sign; }
    if (t2 < tmax) tmax = t2;
    if (tmin > tmax) return null;
  }

  if (tmax < 0) return null;
  return {
    t: tmin,
    nx: nAxis === 0 ? nSign : 0,
    ny: nAxis === 1 ? nSign : 0,
    nz: nAxis === 2 ? nSign : 0,
    box: b,
  };
}

// Kutu listesine karşı en yakın kesişimi bulur.
export function raycastBoxes(ox, oy, oz, dx, dy, dz, maxT, boxes, skip = null) {
  let best = null;
  for (let i = 0; i < boxes.length; i++) {
    const b = boxes[i];
    if (b === skip) continue;
    const hit = rayBox(ox, oy, oz, dx, dy, dz, b, maxT);
    if (hit && (!best || hit.t < best.t)) best = hit;
  }
  return best;
}

// İki nokta arasında engel var mı? (görüş hattı)
export function segmentClear(ax, ay, az, bx, by, bz, boxes) {
  let dx = bx - ax, dy = by - ay, dz = bz - az;
  const len = Math.hypot(dx, dy, dz);
  if (len < EPS) return true;
  dx /= len; dy /= len; dz /= len;
  const hit = raycastBoxes(ax, ay, az, dx, dy, dz, len, boxes);
  return !hit;
}

export function clamp(v, lo, hi) { return v < lo ? lo : (v > hi ? hi : v); }
export function lerp(a, b, t) { return a + (b - a) * t; }

// Kare hızından bağımsız yumuşatma katsayısı.
export function damp(current, target, rate, dt) {
  return lerp(current, target, 1 - Math.exp(-rate * dt));
}

export function randRange(a, b) { return a + Math.random() * (b - a); }
export function randInt(a, b) { return Math.floor(randRange(a, b + 1)); }
export function pick(arr) { return arr[Math.floor(Math.random() * arr.length)]; }

// Gauss dağılımı (Box-Muller), nişan hatası için.
export function gauss() {
  let u = 0, v = 0;
  while (u === 0) u = Math.random();
  while (v === 0) v = Math.random();
  return Math.sqrt(-2 * Math.log(u)) * Math.cos(2 * Math.PI * v);
}

export function angleDiff(a, b) {
  let d = (a - b) % (Math.PI * 2);
  if (d > Math.PI) d -= Math.PI * 2;
  if (d < -Math.PI) d += Math.PI * 2;
  return d;
}

export function approachAngle(current, target, maxDelta) {
  const d = angleDiff(target, current);
  if (Math.abs(d) <= maxDelta) return target;
  return current + Math.sign(d) * maxDelta;
}

export const DEG = Math.PI / 180;
