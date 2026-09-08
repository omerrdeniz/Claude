// "de_verge" — CS tarzı, iki bombalı, simetrik olmayan küçük harita.
// Tüm geometri eksen hizalı kutulardan oluşur; aynı kutular hem render hem çarpışma için kullanılır.

import * as THREE from 'three';
import { boxFromRect } from '../core/math.js';
import { COLORS } from '../config.js';

const WALL_H = 6;

// [x0, z0, x1, z1, y0, y1, malzeme]
const SOLIDS = [
  // Dış duvarlar
  [-36, -40, 36, -38, 0, WALL_H, 'wall'],
  [-36, 38, 36, 40, 0, WALL_H, 'wall'],
  [-36, -40, -34, 40, 0, WALL_H, 'wall'],
  [34, -40, 36, 40, 0, WALL_H, 'wall'],

  // Kuzey bölge blokları (koridorları ayıran binalar)
  [5, -14, 18, 26, 0, WALL_H, 'building'],
  [28, -14, 34, 26, 0, WALL_H, 'building'],
  [-18, -14, -5, 26, 0, WALL_H, 'building'],
  [-34, -14, -28, 26, 0, WALL_H, 'building'],

  // T spawn köşeleri
  [-34, 26, -30, 38, 0, WALL_H, 'building'],
  [30, 26, 34, 38, 0, WALL_H, 'building'],

  // Bomba alanı çevresi
  [5, -32, 12, -24, 0, WALL_H, 'building'],
  [5, -18, 12, -14, 0, WALL_H, 'building'],
  [-12, -32, -5, -24, 0, WALL_H, 'building'],
  [-12, -18, -5, -14, 0, WALL_H, 'building'],
  [30, -32, 34, -14, 0, WALL_H, 'building'],
  [-34, -32, -30, -14, 0, WALL_H, 'building'],
  [30, -38, 34, -32, 0, WALL_H, 'building'],
  [-34, -38, -30, -32, 0, WALL_H, 'building'],

  // Mid kapıları (ortada 2.8 m geçit)
  [-5, 5, -1.9, 6.5, 0, 4, 'wall'],
  [1.9, 5, 5, 6.5, 0, 4, 'wall'],
];

// Kapak amaçlı sandık ve engeller: [merkezX, merkezZ, genişlik, derinlik, taban, yükseklik, malzeme]
const PROPS = [
  // A bombasahası
  [16, -20, 2.2, 2.2, 0, 1.05, 'crate'],
  [24, -26, 2.6, 2.6, 0, 2.0, 'crate'],
  [24, -26, 1.8, 1.8, 2.0, 1.2, 'crate'],
  [20, -16.5, 3.2, 1.4, 0, 1.2, 'crate'],
  [27.5, -20, 2.0, 2.0, 0, 2.0, 'metalbox'],
  [14.5, -28, 1.6, 4.0, 0, 1.4, 'crate'],

  // B bombasahası
  [-16, -20, 2.2, 2.2, 0, 1.05, 'crate'],
  [-24, -26, 2.6, 2.6, 0, 2.0, 'crate'],
  [-24, -26, 1.8, 1.8, 2.0, 1.2, 'crate'],
  [-20, -16.5, 3.2, 1.4, 0, 1.2, 'crate'],
  [-27.5, -20, 2.0, 2.0, 0, 2.0, 'metalbox'],
  [-14.5, -28, 1.6, 4.0, 0, 1.4, 'crate'],

  // Long (doğu koridoru)
  [23, 6, 2.2, 2.2, 0, 1.05, 'crate'],
  [20, -4, 1.4, 3.2, 0, 1.4, 'crate'],
  [26, 18, 2.0, 2.0, 0, 1.6, 'metalbox'],
  [26, -10, 1.6, 1.6, 0, 1.2, 'crate'],

  // Tünel (batı koridoru)
  [-23, 6, 2.2, 2.2, 0, 1.05, 'crate'],
  [-20, -4, 1.4, 3.2, 0, 1.4, 'crate'],
  [-26, 18, 2.0, 2.0, 0, 1.6, 'metalbox'],
  [-26, -10, 1.6, 1.6, 0, 1.2, 'crate'],

  // Mid
  [3.2, 14, 1.4, 1.4, 0, 1.2, 'crate'],
  [-3.2, -4, 1.4, 1.4, 0, 1.2, 'crate'],
  [3.4, -16, 1.2, 3.0, 0, 1.4, 'crate'],

  // Spawnlar
  [6, 29, 2.0, 2.0, 0, 1.3, 'crate'],
  [-14, 30, 2.4, 2.4, 0, 1.6, 'crate'],
  [14, 30, 2.4, 2.4, 0, 1.6, 'crate'],
  [-14, -35, 2.2, 2.2, 0, 1.5, 'metalbox'],
  [14, -35, 2.2, 2.2, 0, 1.5, 'metalbox'],
];

const MATERIAL_INFO = {
  wall: { color: COLORS.sand, pen: 1.0, sound: 'concrete' },
  building: { color: COLORS.sandDark, pen: 1.3, sound: 'concrete' },
  crate: { color: COLORS.wood, pen: 0.45, sound: 'wood' },
  metalbox: { color: COLORS.metal, pen: 0.8, sound: 'metal' },
};

// Yön tanımı: yaw = 0 iken ileri yön (0, 0, -1).
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

const SITES = {
  A: { name: 'A', minX: 13.5, maxX: 29, minZ: -30.5, maxZ: -15, center: { x: 21, z: -23 } },
  B: { name: 'B', minX: -29, maxX: -13.5, minZ: -30.5, maxZ: -15, center: { x: -21, z: -23 } },
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
  // A short / B short
  [8, -21], [13, -21], [-8, -21], [-13, -21],
  // A site
  [15, -17], [21, -18], [27, -17], [15, -24], [21, -24], [27, -24], [17, -29], [25, -29],
  // B site
  [-15, -17], [-21, -18], [-27, -17], [-15, -24], [-21, -24], [-27, -24], [-17, -29], [-25, -29],
  // CT spawn
  [-20, -35], [-10, -35], [0, -35], [10, -35], [20, -35], [26, -35], [-26, -35],
];

function noiseTexture(baseHex, contrast = 18, size = 128) {
  const canvas = document.createElement('canvas');
  canvas.width = canvas.height = size;
  const ctx = canvas.getContext('2d');
  const base = new THREE.Color(baseHex);
  const r = Math.round(base.r * 255);
  const g = Math.round(base.g * 255);
  const b = Math.round(base.b * 255);
  const img = ctx.createImageData(size, size);
  for (let i = 0; i < size * size; i++) {
    const n = (Math.random() - 0.5) * contrast;
    img.data[i * 4 + 0] = Math.max(0, Math.min(255, r + n));
    img.data[i * 4 + 1] = Math.max(0, Math.min(255, g + n));
    img.data[i * 4 + 2] = Math.max(0, Math.min(255, b + n));
    img.data[i * 4 + 3] = 255;
  }
  ctx.putImageData(img, 0, 0);
  const tex = new THREE.CanvasTexture(canvas);
  tex.wrapS = tex.wrapT = THREE.RepeatWrapping;
  tex.colorSpace = THREE.SRGBColorSpace;
  return tex;
}

function siteTexture(letter, color) {
  const canvas = document.createElement('canvas');
  canvas.width = canvas.height = 256;
  const ctx = canvas.getContext('2d');
  ctx.clearRect(0, 0, 256, 256);
  ctx.strokeStyle = color;
  ctx.lineWidth = 10;
  ctx.setLineDash([28, 18]);
  ctx.strokeRect(14, 14, 228, 228);
  ctx.setLineDash([]);
  ctx.fillStyle = color;
  ctx.font = 'bold 150px Arial, sans-serif';
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.globalAlpha = 0.85;
  ctx.fillText(letter, 128, 132);
  const tex = new THREE.CanvasTexture(canvas);
  tex.colorSpace = THREE.SRGBColorSpace;
  return tex;
}

export function buildMap(scene) {
  const group = new THREE.Group();
  group.name = 'map';
  scene.add(group);

  const colliders = [];
  const byMaterial = new Map();

  const push = (x0, z0, x1, z1, y0, y1, mat) => {
    const box = boxFromRect(x0, z0, x1, z1, y0, y1, {
      mat,
      pen: MATERIAL_INFO[mat].pen,
      solid: true,
    });
    colliders.push(box);
    if (!byMaterial.has(mat)) byMaterial.set(mat, []);
    byMaterial.get(mat).push(box);
    return box;
  };

  for (const [x0, z0, x1, z1, y0, y1, mat] of SOLIDS) push(x0, z0, x1, z1, y0, y1, mat);
  for (const [cx, cz, w, d, y0, h, mat] of PROPS) {
    push(cx - w / 2, cz - d / 2, cx + w / 2, cz + d / 2, y0, y0 + h, mat);
  }

  // Gökyüzü (dikey gradyan)
  const skyCanvas = document.createElement('canvas');
  skyCanvas.width = 4;
  skyCanvas.height = 128;
  const skyCtx = skyCanvas.getContext('2d');
  const skyGrad = skyCtx.createLinearGradient(0, 0, 0, 128);
  skyGrad.addColorStop(0, '#3f7fc4');
  skyGrad.addColorStop(0.45, '#9fc4e8');
  skyGrad.addColorStop(0.72, '#d8e4ee');
  skyGrad.addColorStop(1, '#e9dcc4');
  skyCtx.fillStyle = skyGrad;
  skyCtx.fillRect(0, 0, 4, 128);
  const skyTex = new THREE.CanvasTexture(skyCanvas);
  skyTex.colorSpace = THREE.SRGBColorSpace;
  const sky = new THREE.Mesh(
    new THREE.SphereGeometry(240, 24, 16),
    new THREE.MeshBasicMaterial({ map: skyTex, side: THREE.BackSide, fog: false, depthWrite: false }),
  );
  sky.renderOrder = -1;
  group.add(sky);

  // Zemin
  const groundTex = noiseTexture(COLORS.floor, 22, 256);
  groundTex.repeat.set(36, 40);
  const ground = new THREE.Mesh(
    new THREE.PlaneGeometry(72, 80),
    new THREE.MeshLambertMaterial({ map: groundTex }),
  );
  ground.rotation.x = -Math.PI / 2;
  ground.position.set(0, 0, 0);
  ground.receiveShadow = true;
  group.add(ground);
  // Zemin çarpışma kutusu (kalın taban)
  colliders.push(boxFromRect(-40, -44, 40, 44, -4, 0, { mat: 'wall', pen: 99, solid: true, ground: true }));

  // Her malzeme için tek InstancedMesh
  const unit = new THREE.BoxGeometry(1, 1, 1);
  const dummy = new THREE.Object3D();
  for (const [mat, boxes] of byMaterial) {
    const info = MATERIAL_INFO[mat];
    const tex = noiseTexture(info.color, mat === 'crate' ? 28 : 16);
    const material = new THREE.MeshLambertMaterial({ map: tex });
    const mesh = new THREE.InstancedMesh(unit, material, boxes.length);
    mesh.castShadow = true;
    mesh.receiveShadow = true;
    for (let i = 0; i < boxes.length; i++) {
      const b = boxes[i];
      dummy.position.set((b.minX + b.maxX) / 2, (b.minY + b.maxY) / 2, (b.minZ + b.maxZ) / 2);
      dummy.scale.set(b.maxX - b.minX, b.maxY - b.minY, b.maxZ - b.minZ);
      dummy.updateMatrix();
      mesh.setMatrixAt(i, dummy.matrix);
    }
    // Her blok için hafif renk varyasyonu (düz görünmesin)
    const tint = new THREE.Color();
    for (let i = 0; i < boxes.length; i++) {
      const v = 0.88 + Math.random() * 0.2;
      tint.setRGB(v, v * (0.99 + Math.random() * 0.02), v * (0.97 + Math.random() * 0.05));
      mesh.setColorAt(i, tint);
    }
    if (mesh.instanceColor) mesh.instanceColor.needsUpdate = true;
    mesh.instanceMatrix.needsUpdate = true;
    group.add(mesh);
  }

  // Bombasahası işaretleri
  for (const key of ['A', 'B']) {
    const s = SITES[key];
    const tex = siteTexture(key, key === 'A' ? '#e8613c' : '#e8613c');
    const plane = new THREE.Mesh(
      new THREE.PlaneGeometry(s.maxX - s.minX, s.maxZ - s.minZ),
      new THREE.MeshBasicMaterial({ map: tex, transparent: true, depthWrite: false }),
    );
    plane.rotation.x = -Math.PI / 2;
    plane.position.set((s.minX + s.maxX) / 2, 0.02, (s.minZ + s.maxZ) / 2);
    plane.renderOrder = 1;
    group.add(plane);
  }

  const world = {
    group,
    colliders,
    materialInfo: MATERIAL_INFO,
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

  // Satın alma bölgeleri (spawn çevresi)
  world.inBuyZone = (team, x, z) => {
    if (team === 'T') return z > 24;
    return z < -22;
  };

  return world;
}
