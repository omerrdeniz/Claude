// "de_verge" — CS tarzı bomba haritası.
// Geometri eksen hizalı kutulardan üretilir; her kutu dünya ölçeğinde UV'lerle
// tek bir birleşik mesh'e yazılır (malzeme başına tek çizim çağrısı, doğru doku yoğunluğu).

import * as THREE from 'three';
import { pbrMaterial } from './textures.js';

// pen: mermi delme maliyeti (m başına), sound: çarpma sesi, tex: doku, scale: 1 doku karosu kaç metre
export const MATERIALS = {
  sandstone: { pen: 1.0, sound: 'concrete', tex: 'sandstone', scale: 2.6 },
  plaster: { pen: 1.15, sound: 'concrete', tex: 'plaster', scale: 3.2 },
  concrete: { pen: 1.35, sound: 'concrete', tex: 'concrete', scale: 3.0 },
  wood: { pen: 0.45, sound: 'wood', tex: 'wood', scale: 2.0 },
  crate: { pen: 0.45, sound: 'wood', tex: 'crate', scale: 2.2 },
  metal: { pen: 0.8, sound: 'metal', tex: 'metal', scale: 1.7 },
  ground: { pen: 99, sound: 'concrete', tex: 'ground', scale: 5.0 },
  fabric: { pen: 0.4, sound: 'wood', tex: 'fabric', scale: 1.1 },
};

const WALL_H = 8;

export function buildMap(scene) {
  const group = new THREE.Group();
  group.name = 'map';
  scene.add(group);

  const colliders = [];      // oyuncu + mermi çarpışması
  const navExtra = [];       // yalnızca yol bulma için engel (pencere boşlukları vb.)
  const byMat = new Map();   // malzeme -> kutu listesi (çizim)

  // --- Yardımcılar ---------------------------------------------------
  // x0,z0,x1,z1 alanı, y0..y1 yüksekliği. opts: {solid, draw, nav}
  function box(mat, x0, z0, x1, z1, y0, y1, opts = {}) {
    const b = {
      minX: Math.min(x0, x1), maxX: Math.max(x0, x1),
      minY: y0, maxY: y1,
      minZ: Math.min(z0, z1), maxZ: Math.max(z0, z1),
      mat,
      pen: MATERIALS[mat].pen,
      solid: opts.solid !== false,
      ground: !!opts.ground,
    };
    if (opts.solid !== false) colliders.push(b);
    if (opts.draw !== false) {
      if (!byMat.has(mat)) byMat.set(mat, []);
      byMat.get(mat).push(b);
    }
    return b;
  }

  // Yol bulmayı engelleyen görünmez blok (pencere/mazgal boşlukları için)
  function navBlock(x0, z0, x1, z1) {
    navExtra.push({
      minX: Math.min(x0, x1), maxX: Math.max(x0, x1),
      minY: 0, maxY: WALL_H,
      minZ: Math.min(z0, z1), maxZ: Math.max(z0, z1),
      mat: 'concrete', pen: 99, solid: true, navOnly: true,
    });
  }

  // Duvar + üstünde ve altında pencere boşluğu (x ekseni boyunca uzanan duvar)
  function wallWithWindowX(mat, x0, x1, z0, z1, y0, y1, winX0, winX1, winY0, winY1) {
    box(mat, x0, z0, winX0, z1, y0, y1);
    box(mat, winX1, z0, x1, z1, y0, y1);
    box(mat, winX0, z0, winX1, z1, y0, winY0);
    box(mat, winX0, z0, winX1, z1, winY1, y1);
    navBlock(winX0, z0, winX1, z1);
  }

  // Merdiven: adım adım yükselen basamaklar (0.3 m adım, step-up ile çıkılır)
  function stairs(mat, x0, z0, x1, z1, steps, height, dir) {
    const stepH = height / steps;
    for (let i = 0; i < steps; i++) {
      const t0 = i / steps;
      const t1 = (i + 1) / steps;
      if (dir === 'x') {
        box(mat, x0 + (x1 - x0) * t0, z0, x1, z1, 0, stepH * (i + 1));
      } else {
        box(mat, x0, z0 + (z1 - z0) * t0, x1, z1, 0, stepH * (i + 1));
      }
      void t1;
    }
  }

  // Kum torbası yığını
  function sandbags(cx, cz, w, d, rows = 3) {
    for (let r = 0; r < rows; r++) {
      const shrink = r * 0.12;
      const off = (r % 2) * 0.18;
      box('fabric', cx - w / 2 + shrink + off, cz - d / 2 + shrink,
        cx + w / 2 - shrink + off, cz + d / 2 - shrink, r * 0.36, (r + 1) * 0.36);
    }
  }

  // Kasa yığını
  function crate(cx, cz, size, h, y0 = 0) {
    box('crate', cx - size / 2, cz - size / 2, cx + size / 2, cz + size / 2, y0, y0 + h);
  }

  // --- Zemin ---------------------------------------------------------
  const groundBox = box('ground', -40, -46, 40, 46, -4, 0, { ground: true, draw: false });
  groundBox.ground = true;

  const groundMat = pbrMaterial('ground', { repeat: 1 });
  const groundGeo = new THREE.PlaneGeometry(80, 92, 1, 1);
  // Dünya ölçeğinde UV
  {
    const uv = groundGeo.attributes.uv;
    for (let i = 0; i < uv.count; i++) {
      uv.setXY(i, uv.getX(i) * (80 / MATERIALS.ground.scale), uv.getY(i) * (92 / MATERIALS.ground.scale));
    }
    uv.needsUpdate = true;
  }
  const ground = new THREE.Mesh(groundGeo, groundMat);
  ground.rotation.x = -Math.PI / 2;
  ground.receiveShadow = true;
  group.add(ground);

  // --- Dış duvarlar --------------------------------------------------
  box('sandstone', -38, -42, 38, -38, 0, WALL_H);
  box('sandstone', -38, 38, 38, 42, 0, WALL_H);
  box('sandstone', -38, -42, -34, 42, 0, WALL_H);
  box('sandstone', 34, -42, 38, 42, 0, WALL_H);
  // Üst korniş
  box('sandstone', -38.4, -42.4, 38.4, -37.6, WALL_H, WALL_H + 0.5);
  box('sandstone', -38.4, 37.6, 38.4, 42.4, WALL_H, WALL_H + 0.5);
  box('sandstone', -38.4, -42.4, -33.6, 42.4, WALL_H, WALL_H + 0.5);
  box('sandstone', 33.6, -42.4, 38.4, 42.4, WALL_H, WALL_H + 0.5);

  // --- Ana bloklar (koridorları ayıran binalar) ----------------------
  const buildings = [
    [5, -14, 18, 26],     // mid ile long arası
    [28, -14, 34, 26],    // long doğusu
    [-18, -14, -5, 26],   // mid ile tünel arası
    [-34, -14, -28, 26],  // tünel batısı
    [-34, 26, -30, 38],
    [30, 26, 34, 38],
    [5, -32, 12, -24],
    [5, -18, 12, -14],
    [-12, -32, -5, -24],
    [-12, -18, -5, -14],
    [30, -32, 34, -14],
    [-34, -32, -30, -14],
    [30, -38, 34, -32],
    [-34, -38, -30, -32],
  ];
  for (const [x0, z0, x1, z1] of buildings) {
    box('plaster', x0, z0, x1, z1, 0, WALL_H);
    // taban süpürgeliği ve üst korniş (biraz taşar)
    box('sandstone', x0 - 0.12, z0 - 0.12, x1 + 0.12, z1 + 0.12, 0, 0.4);
    box('sandstone', x0 - 0.25, z0 - 0.25, x1 + 0.25, z1 + 0.25, WALL_H - 0.45, WALL_H);
  }

  // --- Mid kapıları: pencereli duvar + sütun + kiriş ------------------
  wallWithWindowX('sandstone', -5, -1.9, 5, 6.6, 0, 4.2, -4.3, -2.7, 1.15, 2.05);
  wallWithWindowX('sandstone', 1.9, 5, 5, 6.6, 0, 4.2, 2.7, 4.3, 1.15, 2.05);
  // geçidin iki yanındaki sütunlar
  box('concrete', -2.3, 4.8, -1.7, 6.8, 0, 5.2);
  box('concrete', 1.7, 4.8, 2.3, 6.8, 0, 5.2);
  // lento
  box('concrete', -2.4, 4.8, 2.4, 6.8, 4.6, 5.2);

  // --- Tünel ve long üzerindeki çatı + kirişler ----------------------
  for (const [x0, x1] of [[-28, -18], [18, 28]]) {
    box('concrete', x0, 2, x1, 24, 4.8, 5.2);              // çatı plakası
    for (let z = 3; z <= 23; z += 4) {
      box('wood', x0, z - 0.2, x1, z + 0.2, 4.4, 4.8);     // kiriş
    }
    // duvar dibi lamba kutuları (yalnız görsel)
    for (let z = 6; z <= 22; z += 8) {
      box('metal', x0 + 0.2, z - 0.3, x0 + 0.5, z + 0.3, 3.4, 3.7, { solid: false });
      box('metal', x1 - 0.5, z - 0.3, x1 - 0.2, z + 0.3, 3.4, 3.7, { solid: false });
    }
  }

  // --- Koridor girişlerinde kemerler ---------------------------------
  const arches = [
    [18, 26, 28, 26.8], [-28, 26, -18, 26.8],   // T spawn çıkışları
    [18, -14.8, 28, -14], [-28, -14.8, -18, -14], // site girişleri
  ];
  for (const [x0, z0, x1, z1] of arches) {
    box('concrete', x0, z0, x1, z1, 4.2, 5.0);
    box('concrete', x0, z0, x0 + 0.7, z1, 0, 4.2);
    box('concrete', x1 - 0.7, z0, x1, z1, 0, 4.2);
  }

  // --- A bombasahası -------------------------------------------------
  // yükseltilmiş platform + merdiven
  box('concrete', 22, -32, 30, -24, 0, 1.25);
  stairs('concrete', 20.4, -30, 22, -25, 4, 1.25, 'x');
  box('concrete', 22, -24.25, 30, -24, 1.25, 1.9);          // platform korkuluğu
  box('concrete', 21.75, -32, 22, -24, 1.25, 1.9);
  // kapaklar
  crate(16, -20, 2.2, 1.05);
  crate(24.2, -26.4, 2.6, 2.0);
  crate(24.2, -26.4, 1.9, 1.1, 2.0);
  crate(20, -16.6, 1.5, 1.25);
  box('crate', 18.6, -17.3, 21.4, -15.9, 0, 1.25);
  box('metal', 26.6, -21, 28.6, -19, 0, 2.0);
  crate(14.6, -28, 1.6, 1.4);
  sandbags(15.4, -22.6, 2.6, 1.0, 3);
  sandbags(26.5, -16.4, 2.4, 1.0, 2);

  // --- B bombasahası -------------------------------------------------
  box('concrete', -30, -22, -22, -14, 0, 1.0);
  stairs('concrete', -20.6, -21, -22, -16, 3, 1.0, 'x');
  box('concrete', -30, -22.25, -22, -22, 1.0, 1.65);
  crate(-16, -20, 2.2, 1.05);
  crate(-24.2, -26.4, 2.6, 2.0);
  crate(-24.2, -26.4, 1.9, 1.1, 2.0);
  crate(-20, -16.6, 1.5, 1.25);
  box('crate', -21.4, -17.3, -18.6, -15.9, 0, 1.25);
  box('metal', -28.6, -29, -26.6, -27, 0, 2.0);
  crate(-14.6, -28, 1.6, 1.4);
  sandbags(-15.4, -25.6, 2.6, 1.0, 3);
  sandbags(-26.5, -25.4, 2.4, 1.0, 2);

  // --- Long (doğu koridoru) ------------------------------------------
  crate(23, 6, 2.2, 1.05);
  box('crate', 19.3, -5.6, 20.7, -2.4, 0, 1.4);
  box('metal', 25, 17, 27, 19, 0, 1.6);
  crate(26, -10, 1.6, 1.2);
  sandbags(21.5, 12, 3.0, 1.0, 2);
  // long ortasında daraltan sütunlar
  box('concrete', 18.0, 9.4, 18.7, 10.6, 0, 5.0);
  box('concrete', 27.3, -0.6, 28.0, 0.6, 0, 5.0);

  // --- Tünel (batı koridoru) -----------------------------------------
  crate(-23, 6, 2.2, 1.05);
  box('crate', -20.7, -5.6, -19.3, -2.4, 0, 1.4);
  box('metal', -27, 17, -25, 19, 0, 1.6);
  crate(-26, -10, 1.6, 1.2);
  sandbags(-21.5, 12, 3.0, 1.0, 2);
  box('concrete', -18.7, 9.4, -18.0, 10.6, 0, 5.0);
  box('concrete', -28.0, -0.6, -27.3, 0.6, 0, 5.0);

  // --- Mid -----------------------------------------------------------
  crate(3.2, 14, 1.4, 1.2);
  crate(-3.2, -4, 1.4, 1.2);
  box('crate', 2.8, -17.5, 4.0, -14.5, 0, 1.4);
  sandbags(-4.2, -24, 1.0, 2.6, 2);

  // --- Spawn bölgeleri -----------------------------------------------
  crate(6, 29, 2.0, 1.3);
  crate(-14, 30, 2.4, 1.6);
  crate(14, 30, 2.4, 1.6);
  box('metal', -15.1, -36.1, -12.9, -33.9, 0, 1.5);
  box('metal', 12.9, -36.1, 15.1, -33.9, 0, 1.5);
  sandbags(-6, 31.5, 3.2, 1.0, 2);
  sandbags(6, -36.0, 3.2, 1.0, 2);

  // --- Birleşik geometri ---------------------------------------------
  for (const [mat, boxes] of byMat) {
    const geo = buildBoxGeometry(boxes, MATERIALS[mat].scale);
    const mesh = new THREE.Mesh(geo, pbrMaterial(MATERIALS[mat].tex, { repeat: 1 }));
    mesh.castShadow = true;
    mesh.receiveShadow = true;
    mesh.name = `map-${mat}`;
    group.add(mesh);
  }

  // --- Variller (silindir) -------------------------------------------
  const barrelSpots = [
    [17.8, -25.5], [18.6, -26.8], [27.5, -29.5], [12.9, -18.4],
    [-17.8, -18.5], [-18.6, -19.8], [-27.5, -29.5], [-12.9, -18.4],
    [24.5, 20.5], [-24.5, 20.5], [26.8, 2.5], [-26.8, 2.5],
    [-4.2, 22.5], [4.2, -28.0],
  ];
  const barrelGeo = new THREE.CylinderGeometry(0.34, 0.34, 0.95, 16, 1);
  const barrelMat = pbrMaterial('metal', { repeat: 1, color: 0x9d5a3a });
  const barrels = new THREE.InstancedMesh(barrelGeo, barrelMat, barrelSpots.length);
  barrels.castShadow = true;
  barrels.receiveShadow = true;
  const dummy = new THREE.Object3D();
  barrelSpots.forEach(([x, z], i) => {
    dummy.position.set(x, 0.475, z);
    dummy.rotation.set(0, (i * 1.7) % Math.PI, 0);
    dummy.updateMatrix();
    barrels.setMatrixAt(i, dummy.matrix);
    colliders.push({
      minX: x - 0.34, maxX: x + 0.34, minY: 0, maxY: 0.95,
      minZ: z - 0.34, maxZ: z + 0.34, mat: 'metal', pen: MATERIALS.metal.pen, solid: true,
    });
  });
  barrels.instanceMatrix.needsUpdate = true;
  group.add(barrels);

  // --- Bombasahası zemin işaretleri ----------------------------------
  const SITES = {
    A: { name: 'A', minX: 13.5, maxX: 29, minZ: -30.5, maxZ: -15, center: { x: 20, z: -21 } },
    B: { name: 'B', minX: -29, maxX: -13.5, minZ: -30.5, maxZ: -15, center: { x: -20, z: -21 } },
  };
  for (const key of ['A', 'B']) {
    const s = SITES[key];
    const tex = siteTexture(key);
    const plane = new THREE.Mesh(
      new THREE.PlaneGeometry(s.maxX - s.minX, s.maxZ - s.minZ),
      new THREE.MeshBasicMaterial({ map: tex, transparent: true, depthWrite: false, opacity: 0.85 }),
    );
    plane.rotation.x = -Math.PI / 2;
    plane.position.set((s.minX + s.maxX) / 2, 0.015, (s.minZ + s.maxZ) / 2);
    plane.renderOrder = 1;
    group.add(plane);
  }

  const world = {
    group,
    colliders,
    navColliders: colliders.concat(navExtra),
    materialInfo: MATERIALS,
    spawns: SPAWNS,
    sites: SITES,
    waypointPositions: WAYPOINTS.map(([x, z]) => ({ x, z })),
    bounds: { minX: -34, maxX: 34, minZ: -38, maxZ: 38 },
  };

  world.siteAt = (x, z) => {
    for (const key of ['A', 'B']) {
      const s = SITES[key];
      if (x >= s.minX && x <= s.maxX && z >= s.minZ && z <= s.maxZ) return s;
    }
    return null;
  };
  world.inBuyZone = (team, x, z) => (team === 'T' ? z > 24 : z < -22);

  return world;
}

// --- Kutu listesinden dünya ölçekli UV'li birleşik geometri ----------
function buildBoxGeometry(boxes, texScale) {
  const pos = [];
  const nor = [];
  const uv = [];
  const idx = [];
  const s = 1 / texScale;

  const quad = (a, b, c, d, n, uvs) => {
    // Sarım yönünü normale göre düzelt
    const ux = b[0] - a[0], uy = b[1] - a[1], uz = b[2] - a[2];
    const vx = c[0] - a[0], vy = c[1] - a[1], vz = c[2] - a[2];
    const cx = uy * vz - uz * vy;
    const cy = uz * vx - ux * vz;
    const cz = ux * vy - uy * vx;
    let verts = [a, b, c, d];
    let uvv = uvs;
    if (cx * n[0] + cy * n[1] + cz * n[2] < 0) {
      verts = [a, d, c, b];
      uvv = [uvs[0], uvs[3], uvs[2], uvs[1]];
    }
    const base = pos.length / 3;
    for (let i = 0; i < 4; i++) {
      pos.push(verts[i][0], verts[i][1], verts[i][2]);
      nor.push(n[0], n[1], n[2]);
      uv.push(uvv[i][0], uvv[i][1]);
    }
    idx.push(base, base + 1, base + 2, base, base + 2, base + 3);
  };

  for (const b of boxes) {
    const { minX, maxX, minY, maxY, minZ, maxZ } = b;
    // +X / -X (uv: z,y)
    for (const [x, n] of [[maxX, [1, 0, 0]], [minX, [-1, 0, 0]]]) {
      quad([x, minY, minZ], [x, minY, maxZ], [x, maxY, maxZ], [x, maxY, minZ], n,
        [[minZ * s, minY * s], [maxZ * s, minY * s], [maxZ * s, maxY * s], [minZ * s, maxY * s]]);
    }
    // +Z / -Z (uv: x,y)
    for (const [z, n] of [[maxZ, [0, 0, 1]], [minZ, [0, 0, -1]]]) {
      quad([minX, minY, z], [maxX, minY, z], [maxX, maxY, z], [minX, maxY, z], n,
        [[minX * s, minY * s], [maxX * s, minY * s], [maxX * s, maxY * s], [minX * s, maxY * s]]);
    }
    // Üst yüz (uv: x,z)
    quad([minX, maxY, minZ], [maxX, maxY, minZ], [maxX, maxY, maxZ], [minX, maxY, maxZ], [0, 1, 0],
      [[minX * s, minZ * s], [maxX * s, minZ * s], [maxX * s, maxZ * s], [minX * s, maxZ * s]]);
    // Alt yüz (yalnızca havada duran kutular için)
    if (minY > 0.05) {
      quad([minX, minY, minZ], [maxX, minY, minZ], [maxX, minY, maxZ], [minX, minY, maxZ], [0, -1, 0],
        [[minX * s, minZ * s], [maxX * s, minZ * s], [maxX * s, maxZ * s], [minX * s, maxZ * s]]);
    }
  }

  const geo = new THREE.BufferGeometry();
  geo.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
  geo.setAttribute('normal', new THREE.Float32BufferAttribute(nor, 3));
  geo.setAttribute('uv', new THREE.Float32BufferAttribute(uv, 2));
  geo.setIndex(idx);
  geo.computeBoundingSphere();
  return geo;
}

function siteTexture(letter) {
  const c = document.createElement('canvas');
  c.width = c.height = 256;
  const ctx = c.getContext('2d');
  ctx.clearRect(0, 0, 256, 256);
  ctx.strokeStyle = '#e8613c';
  ctx.lineWidth = 9;
  ctx.setLineDash([26, 20]);
  ctx.strokeRect(12, 12, 232, 232);
  ctx.setLineDash([]);
  ctx.globalAlpha = 0.9;
  ctx.fillStyle = '#e8613c';
  ctx.font = 'bold 150px Arial, sans-serif';
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.fillText(letter, 128, 132);
  const tex = new THREE.CanvasTexture(c);
  tex.colorSpace = THREE.SRGBColorSpace;
  return tex;
}

// Yön: yaw = 0 iken ileri (0, 0, -1)
const SPAWNS = {
  T: [
    { x: -8, z: 34.5, yaw: 0 }, { x: -4, z: 35.5, yaw: 0 }, { x: 0, z: 34.5, yaw: 0 },
    { x: 4, z: 35.5, yaw: 0 }, { x: 8, z: 34.5, yaw: 0 }, { x: -12, z: 35.5, yaw: 0 },
    { x: 12, z: 35.5, yaw: 0 },
  ],
  CT: [
    { x: -8, z: -35.5, yaw: Math.PI }, { x: -4, z: -34.5, yaw: Math.PI }, { x: 0, z: -35.5, yaw: Math.PI },
    { x: 4, z: -34.5, yaw: Math.PI }, { x: 8, z: -35.5, yaw: Math.PI }, { x: -12, z: -34.5, yaw: Math.PI },
    { x: 12, z: -34.5, yaw: Math.PI },
  ],
};

const WAYPOINTS = [
  // T spawn
  [-20, 34], [-10, 34], [0, 34], [10, 34], [20, 34], [-24, 29], [24, 29], [0, 29],
  // Long
  [23, 24], [23, 16], [26, 10], [23, 2], [21, -6], [23, -12],
  // Mid
  [0, 22], [0, 14], [0, 8], [0, 2], [0, -6], [0, -13], [0, -20], [0, -28],
  // Tünel
  [-23, 24], [-23, 16], [-26, 10], [-23, 2], [-21, -6], [-23, -12],
  // Short geçitler
  [8, -21], [13, -21], [-8, -21], [-13, -21],
  // A site
  [15, -17], [21, -18], [27, -17], [15, -24], [20, -22], [27, -21], [17, -29], [25, -22],
  // B site
  [-15, -17], [-20, -18], [-27, -18], [-15, -24], [-20, -25], [-27, -25], [-17, -29], [-25, -29],
  // CT spawn
  [-20, -35], [-10, -35], [0, -35], [10, -35], [20, -35], [26, -35], [-26, -35],
];
