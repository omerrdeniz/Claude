// Yol bulma: elle yerleştirilmiş waypoint'lerden görüş hattına göre graf kurar, A* ile yol üretir.

import { segmentClear } from '../core/math.js';

const LINK_RADIUS = 13;
const CLEARANCE = 0.6;     // botun omuz genişliği payı
const TEST_HEIGHTS = [0.55, 1.35];

// İki nokta arasında bot geçebilir mi? (yanal pay ve iki yükseklikte kontrol)
// y: testin yapılacağı taban yüksekliği (kasa üstünde duran bot için önemli).
export function walkClear(ax, az, bx, bz, colliders, y = 0) {
  let dx = bx - ax;
  let dz = bz - az;
  const len = Math.hypot(dx, dz);
  if (len < 1e-5) return true;
  dx /= len; dz /= len;
  const px = -dz * CLEARANCE;
  const pz = dx * CLEARANCE;
  for (const h0 of TEST_HEIGHTS) {
    const h = y + h0;
    for (const s of [0, 1, -1]) {
      const ox = ax + px * s;
      const oz = az + pz * s;
      if (!segmentClear(ox, h, oz, bx + px * s, h, bz + pz * s, colliders)) return false;
    }
  }
  return true;
}

// Bir nokta katı bir cismin içinde mi (veya çok yakınında)?
function blocked(x, z, colliders, pad = 0.55) {
  for (const o of colliders) {
    if (o.ground) continue;
    if (o.maxY < 0.5 || o.minY > 1.4) continue;     // altından/üstünden geçilebilenler sayılmaz
    if (x > o.minX - pad && x < o.maxX + pad && z > o.minZ - pad && z < o.maxZ + pad) return true;
  }
  return false;
}

// Engel içinde kalan waypoint'leri en yakın boş noktaya kaydırır, olmazsa eler.
function sanitize(points, colliders) {
  const out = [];
  for (const p of points) {
    if (!blocked(p.x, p.z, colliders)) { out.push({ x: p.x, z: p.z }); continue; }
    let moved = null;
    for (const r of [0.9, 1.6, 2.4, 3.2]) {
      for (let a = 0; a < 12 && !moved; a++) {
        const ang = (a / 12) * Math.PI * 2;
        const nx = p.x + Math.cos(ang) * r;
        const nz = p.z + Math.sin(ang) * r;
        if (!blocked(nx, nz, colliders)) moved = { x: +nx.toFixed(2), z: +nz.toFixed(2) };
      }
      if (moved) break;
    }
    if (moved) out.push(moved);
    else console.warn(`[nav] waypoint (${p.x}, ${p.z}) engel içinde ve taşınamadı, elendi`);
  }
  return out;
}

// Haritayı ızgarayla tarayıp boş noktalara ek düğüm koyar (grafik kopmasın).
function gridFill(points, world, spacing = 4.5, minDist = 3.4) {
  const b = world.bounds;
  const out = points.slice();
  for (let x = b.minX + spacing / 2; x <= b.maxX; x += spacing) {
    for (let z = b.minZ + spacing / 2; z <= b.maxZ; z += spacing) {
      if (blocked(x, z, world.navColliders, 0.75)) continue;
      let near = false;
      for (const p of out) {
        if ((p.x - x) ** 2 + (p.z - z) ** 2 < minDist * minDist) { near = true; break; }
      }
      if (!near) out.push({ x: +x.toFixed(2), z: +z.toFixed(2) });
    }
  }
  return out;
}

export function buildNav(world) {
  const manual = sanitize(world.waypointPositions, world.navColliders);
  const points = gridFill(manual, world);
  const nodes = points.map((p, i) => ({ id: i, x: p.x, z: p.z, links: [] }));
  for (let i = 0; i < nodes.length; i++) {
    for (let j = i + 1; j < nodes.length; j++) {
      const a = nodes[i];
      const b = nodes[j];
      const d = Math.hypot(a.x - b.x, a.z - b.z);
      if (d > LINK_RADIUS) continue;
      if (!walkClear(a.x, a.z, b.x, b.z, world.navColliders)) continue;
      a.links.push({ id: j, cost: d });
      b.links.push({ id: i, cost: d });
    }
  }

  const nav = {
    nodes,
    nearest(x, z, requireVisible = false, y = 0) {
      let best = -1;
      let bestD = Infinity;
      for (const n of nodes) {
        const d = (n.x - x) ** 2 + (n.z - z) ** 2;
        if (d < bestD) {
          if (requireVisible && !walkClear(x, z, n.x, n.z, world.navColliders, y)) continue;
          bestD = d; best = n.id;
        }
      }
      if (best < 0 && requireVisible) return nav.nearest(x, z, false, y);
      return best;
    },
    // A* — düğüm kimlikleri dizisi döner (start dahil değil).
    path(startId, goalId) {
      if (startId < 0 || goalId < 0) return null;
      if (startId === goalId) return [];
      const n = nodes.length;
      const g = new Float64Array(n).fill(Infinity);
      const f = new Float64Array(n).fill(Infinity);
      const prev = new Int32Array(n).fill(-1);
      const closed = new Uint8Array(n);
      const open = [startId];
      const goal = nodes[goalId];
      const h = (node) => Math.hypot(node.x - goal.x, node.z - goal.z);
      g[startId] = 0;
      f[startId] = h(nodes[startId]);
      while (open.length) {
        // küçük graf: doğrusal arama yeterince hızlı
        let bi = 0;
        for (let i = 1; i < open.length; i++) if (f[open[i]] < f[open[bi]]) bi = i;
        const cur = open.splice(bi, 1)[0];
        if (cur === goalId) {
          const out = [];
          let c = cur;
          while (c !== startId && c !== -1) { out.push(c); c = prev[c]; }
          out.reverse();
          return out;
        }
        closed[cur] = 1;
        for (const link of nodes[cur].links) {
          if (closed[link.id]) continue;
          const tentative = g[cur] + link.cost;
          if (tentative < g[link.id]) {
            g[link.id] = tentative;
            f[link.id] = tentative + h(nodes[link.id]);
            prev[link.id] = cur;
            if (!open.includes(link.id)) open.push(link.id);
          }
        }
      }
      return null;
    },
    // Bir noktaya en yakın, hedefe ulaşılabilir düğüm
    nodesNear(x, z, radius) {
      const out = [];
      for (const n of nodes) {
        if (Math.hypot(n.x - x, n.z - z) <= radius) out.push(n.id);
      }
      return out;
    },
  };

  // Bağlantı doğrulaması: izole düğüm varsa konsola uyarı bırak.
  const seen = new Set([0]);
  const stack = [0];
  while (stack.length) {
    const cur = stack.pop();
    for (const l of nodes[cur].links) {
      if (!seen.has(l.id)) { seen.add(l.id); stack.push(l.id); }
    }
  }
  if (seen.size !== nodes.length) {
    const missing = nodes.filter((n) => !seen.has(n.id)).map((n) => `${n.id}(${n.x},${n.z})`);
    console.warn('[nav] Bağlantısız waypoint(ler):', missing.join(', '));
  }
  nav.connected = seen.size === nodes.length;
  return nav;
}
