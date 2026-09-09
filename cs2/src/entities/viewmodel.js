// Birinci şahıs silah modeli: parça parça prosedürel geometri, eldivenli eller,
// şarjör değiştirme / sürgü animasyonu ve namlu alevi.
// Ayrı bir sahnede ve dar FOV'lu kamerayla çizilir (duvara girmez, bozulmaz).

import * as THREE from 'three';
import { damp, clamp } from '../core/math.js';

const M = {};
function mat(key, params) {
  if (!M[key]) M[key] = new THREE.MeshStandardMaterial(params);
  return M[key];
}
const MATS = {
  get steel() { return mat('steel', { color: 0x2a2d33, roughness: 0.35, metalness: 0.9 }); },
  get dark() { return mat('dark', { color: 0x1b1e22, roughness: 0.55, metalness: 0.6 }); },
  get polymer() { return mat('polymer', { color: 0x24272c, roughness: 0.85, metalness: 0.05 }); },
  get wood() { return mat('wood', { color: 0x7b4f28, roughness: 0.7, metalness: 0.02 }); },
  get glass() { return mat('glass', { color: 0x0b1622, roughness: 0.1, metalness: 0.4 }); },
  get brass() { return mat('brass', { color: 0xb08a3a, roughness: 0.35, metalness: 0.95 }); },
  get glove() { return mat('glove', { color: 0x2c3037, roughness: 0.9, metalness: 0.04 }); },
  get skin() { return mat('skin', { color: 0xb2865e, roughness: 0.95, metalness: 0 }); },
};

function box(w, h, d, material, x = 0, y = 0, z = 0, rx = 0, ry = 0, rz = 0) {
  const m = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), material);
  m.position.set(x, y, z);
  m.rotation.set(rx, ry, rz);
  return m;
}

function cyl(r1, r2, h, material, x = 0, y = 0, z = 0, axis = 'z', seg = 12) {
  const m = new THREE.Mesh(new THREE.CylinderGeometry(r1, r2, h, seg), material);
  if (axis === 'z') m.rotation.x = Math.PI / 2;
  if (axis === 'x') m.rotation.z = Math.PI / 2;
  m.position.set(x, y, z);
  return m;
}

// Eldivenli el: avuç + parmaklar
function hand(rotZ = 0) {
  const g = new THREE.Group();
  g.add(box(0.055, 0.085, 0.075, MATS.glove, 0, 0, 0));
  for (let i = 0; i < 4; i++) {
    const f = box(0.05, 0.019, 0.019, MATS.glove, 0, 0.028 - i * 0.019, -0.045);
    f.rotation.x = -0.5;
    g.add(f);
  }
  const thumb = box(0.022, 0.022, 0.05, MATS.glove, -0.03, 0.02, -0.02);
  thumb.rotation.y = 0.5;
  g.add(thumb);
  g.add(box(0.06, 0.09, 0.05, MATS.polymer, 0, 0.02, 0.06));   // bilek / kol ucu
  g.rotation.z = rotZ;
  return g;
}

// --- Silah üreticileri ------------------------------------------------
function buildAK() {
  const g = new THREE.Group();
  const parts = {};
  g.add(box(0.052, 0.082, 0.40, MATS.steel, 0, 0, -0.12));           // gövde
  g.add(box(0.046, 0.03, 0.34, MATS.dark, 0, 0.055, -0.14));         // üst kapak
  g.add(box(0.05, 0.055, 0.20, MATS.wood, 0, -0.005, -0.40));        // ön el kundağı alt
  g.add(box(0.044, 0.036, 0.19, MATS.wood, 0, 0.055, -0.40));        // üst kundak
  g.add(cyl(0.014, 0.014, 0.36, MATS.steel, 0, 0.012, -0.62));       // namlu
  g.add(cyl(0.019, 0.019, 0.06, MATS.dark, 0, 0.012, -0.80));        // ağızlık
  g.add(cyl(0.016, 0.016, 0.20, MATS.steel, 0, 0.052, -0.52));       // gaz tüpü
  g.add(box(0.016, 0.05, 0.02, MATS.dark, 0, 0.08, -0.70));          // arpacık
  g.add(box(0.03, 0.028, 0.05, MATS.dark, 0, 0.075, -0.22));         // gez
  // kabza
  const grip = box(0.042, 0.14, 0.055, MATS.polymer, 0, -0.095, 0.02);
  grip.rotation.x = -0.28;
  g.add(grip);
  // dipçik
  const stock = box(0.048, 0.075, 0.26, MATS.wood, 0, -0.035, 0.24);
  stock.rotation.x = 0.06;
  g.add(stock);
  g.add(box(0.05, 0.09, 0.05, MATS.wood, 0, -0.055, 0.36));
  // tetik korkuluğu
  g.add(box(0.03, 0.012, 0.09, MATS.steel, 0, -0.06, -0.02));
  // kavisli şarjör (üç parça)
  const mag = new THREE.Group();
  const m1 = box(0.032, 0.09, 0.075, MATS.polymer, 0, -0.075, -0.09);
  m1.rotation.x = 0.18;
  const m2 = box(0.03, 0.075, 0.07, MATS.polymer, 0, -0.145, -0.115);
  m2.rotation.x = 0.42;
  const m3 = box(0.028, 0.05, 0.06, MATS.polymer, 0, -0.2, -0.155);
  m3.rotation.x = 0.68;
  mag.add(m1, m2, m3);
  g.add(mag);
  parts.mag = mag;
  // kurma kolu
  const bolt = box(0.02, 0.02, 0.06, MATS.steel, 0.036, 0.045, -0.2);
  g.add(bolt);
  parts.bolt = bolt;
  parts.muzzleZ = -0.84;
  parts.gripLocal = new THREE.Vector3(0.0, -0.10, 0.02);
  parts.foreLocal = new THREE.Vector3(0.0, -0.05, -0.42);
  return { group: g, parts };
}

function buildM4() {
  const g = new THREE.Group();
  const parts = {};
  g.add(box(0.05, 0.08, 0.34, MATS.dark, 0, 0, -0.10));
  g.add(box(0.042, 0.028, 0.42, MATS.dark, 0, 0.055, -0.20));         // üst ray
  for (let i = 0; i < 7; i++) g.add(box(0.046, 0.008, 0.012, MATS.steel, 0, 0.071, -0.05 - i * 0.05));
  g.add(box(0.05, 0.05, 0.26, MATS.polymer, 0, 0.01, -0.38));         // RIS el kundağı
  for (let i = 0; i < 5; i++) g.add(box(0.054, 0.01, 0.02, MATS.dark, 0, 0.01, -0.28 - i * 0.05));
  g.add(cyl(0.011, 0.011, 0.30, MATS.steel, 0, 0.015, -0.62));
  g.add(cyl(0.018, 0.016, 0.07, MATS.dark, 0, 0.015, -0.79));         // alev gizleyen
  g.add(box(0.016, 0.045, 0.02, MATS.dark, 0, 0.075, -0.52));
  const grip = box(0.04, 0.13, 0.05, MATS.polymer, 0, -0.09, 0.02);
  grip.rotation.x = -0.3;
  g.add(grip);
  // teleskopik dipçik
  g.add(cyl(0.022, 0.022, 0.2, MATS.dark, 0, -0.005, 0.2, 'z', 10));
  g.add(box(0.05, 0.095, 0.09, MATS.polymer, 0, -0.02, 0.31));
  g.add(box(0.03, 0.012, 0.09, MATS.steel, 0, -0.055, -0.02));
  const mag = box(0.03, 0.17, 0.07, MATS.polymer, 0, -0.115, -0.06);
  mag.rotation.x = 0.06;
  g.add(mag);
  parts.mag = mag;
  const bolt = box(0.02, 0.018, 0.05, MATS.steel, 0.032, 0.04, 0.03);
  g.add(bolt);
  parts.bolt = bolt;
  parts.muzzleZ = -0.83;
  parts.gripLocal = new THREE.Vector3(0, -0.095, 0.02);
  parts.foreLocal = new THREE.Vector3(0, -0.045, -0.40);
  return { group: g, parts };
}

function buildAWP(scoped = true) {
  const g = new THREE.Group();
  const parts = {};
  g.add(box(0.05, 0.075, 0.42, MATS.dark, 0, 0, -0.10));
  g.add(cyl(0.015, 0.015, 0.62, MATS.steel, 0, 0.015, -0.62, 'z', 14));
  for (let i = 0; i < 5; i++) g.add(cyl(0.019, 0.019, 0.012, MATS.dark, 0, 0.015, -0.45 - i * 0.09, 'z', 12));
  // dürbün
  if (scoped) {
    g.add(cyl(0.03, 0.03, 0.3, MATS.dark, 0, 0.085, -0.15, 'z', 14));
    g.add(cyl(0.036, 0.036, 0.05, MATS.dark, 0, 0.085, -0.28, 'z', 14));
    g.add(cyl(0.033, 0.033, 0.04, MATS.dark, 0, 0.085, -0.02, 'z', 14));
    g.add(cyl(0.026, 0.026, 0.01, MATS.glass, 0, 0.085, -0.305, 'z', 14));
    g.add(box(0.02, 0.04, 0.02, MATS.steel, 0, 0.055, -0.05));
    g.add(box(0.02, 0.04, 0.02, MATS.steel, 0, 0.055, -0.26));
  }
  // sürgü
  const bolt = new THREE.Group();
  bolt.add(cyl(0.012, 0.012, 0.12, MATS.steel, 0.03, 0.02, 0.02, 'z', 10));
  const knob = new THREE.Mesh(new THREE.SphereGeometry(0.018, 10, 8), MATS.steel);
  knob.position.set(0.058, 0.012, 0.07);
  bolt.add(knob);
  g.add(bolt);
  parts.bolt = bolt;
  const grip = box(0.042, 0.13, 0.06, MATS.polymer, 0, -0.085, 0.06);
  grip.rotation.x = -0.2;
  g.add(grip);
  g.add(box(0.05, 0.1, 0.3, MATS.polymer, 0, -0.02, 0.28));      // dipçik
  g.add(box(0.05, 0.05, 0.16, MATS.polymer, 0, 0.05, 0.2));      // yanak dayama
  const mag = box(0.032, 0.07, 0.1, MATS.dark, 0, -0.07, -0.09);
  g.add(mag);
  parts.mag = mag;
  parts.muzzleZ = -0.95;
  parts.gripLocal = new THREE.Vector3(0, -0.09, 0.06);
  parts.foreLocal = new THREE.Vector3(0, -0.04, -0.34);
  return { group: g, parts };
}

function buildSMG(compact) {
  const g = new THREE.Group();
  const parts = {};
  g.add(box(0.05, 0.085, 0.26, MATS.polymer, 0, 0, -0.06));
  g.add(box(0.04, 0.026, 0.24, MATS.dark, 0, 0.055, -0.10));
  g.add(cyl(0.011, 0.011, 0.18, MATS.steel, 0, 0.01, -0.30));
  g.add(cyl(0.016, 0.016, 0.05, MATS.dark, 0, 0.01, -0.40));
  const grip = box(0.04, 0.12, 0.05, MATS.polymer, 0, -0.085, 0.0);
  grip.rotation.x = -0.22;
  g.add(grip);
  const mag = box(0.03, 0.16, 0.06, MATS.polymer, 0, -0.11, compact ? 0.0 : -0.04);
  g.add(mag);
  parts.mag = mag;
  if (!compact) {
    g.add(cyl(0.018, 0.018, 0.14, MATS.dark, 0, 0, 0.17, 'z', 10));
    g.add(box(0.04, 0.07, 0.05, MATS.polymer, 0, -0.01, 0.24));
  } else {
    g.add(box(0.036, 0.05, 0.14, MATS.dark, 0, 0.005, 0.16));
  }
  const bolt = box(0.018, 0.018, 0.05, MATS.steel, 0.03, 0.04, -0.02);
  g.add(bolt);
  parts.bolt = bolt;
  parts.muzzleZ = -0.44;
  parts.gripLocal = new THREE.Vector3(0, -0.09, 0.0);
  parts.foreLocal = new THREE.Vector3(0, -0.05, -0.24);
  return { group: g, parts };
}

function buildPistol(kind) {
  const g = new THREE.Group();
  const parts = {};
  const big = kind === 'deagle';
  const slide = box(big ? 0.042 : 0.036, big ? 0.062 : 0.05, big ? 0.26 : 0.2, MATS.steel, 0, 0.025, -0.05);
  g.add(slide);
  parts.bolt = slide;
  for (let i = 0; i < 6; i++) {
    g.add(box(big ? 0.044 : 0.038, 0.03, 0.006, MATS.dark, 0, 0.025, 0.01 + i * 0.012));
  }
  g.add(box(0.03, 0.05, big ? 0.24 : 0.19, MATS.dark, 0, -0.012, -0.05));   // gövde
  const grip = box(0.036, 0.13, 0.055, MATS.polymer, 0, -0.085, 0.03);
  grip.rotation.x = -0.22;
  g.add(grip);
  const mag = box(0.03, 0.11, 0.045, MATS.dark, 0, -0.085, 0.032);
  mag.rotation.x = -0.22;
  g.add(mag);
  parts.mag = mag;
  g.add(box(0.024, 0.01, 0.06, MATS.steel, 0, -0.035, -0.01));             // tetik korkuluğu
  g.add(box(0.012, 0.014, 0.012, MATS.dark, 0, 0.055, -0.14));             // arpacık
  g.add(box(0.026, 0.014, 0.014, MATS.dark, 0, 0.055, 0.04));             // gez
  if (kind === 'usp') {
    g.add(cyl(0.021, 0.021, 0.16, MATS.dark, 0, 0.025, -0.22, 'z', 12));   // susturucu
    parts.muzzleZ = -0.31;
  } else {
    parts.muzzleZ = big ? -0.2 : -0.16;
  }
  parts.gripLocal = new THREE.Vector3(0, -0.085, 0.03);
  parts.foreLocal = null;
  return { group: g, parts };
}

function buildKnife() {
  const g = new THREE.Group();
  const parts = {};
  const blade = box(0.018, 0.042, 0.24, mat('blade', { color: 0xc7ccd4, roughness: 0.18, metalness: 1 }), 0, 0.01, -0.14);
  g.add(blade);
  const tip = box(0.016, 0.03, 0.06, mat('blade', {}), 0, 0.004, -0.28);
  tip.rotation.x = 0.2;
  g.add(tip);
  g.add(box(0.03, 0.05, 0.1, MATS.polymer, 0, 0, 0.02));
  for (let i = 0; i < 3; i++) g.add(box(0.034, 0.012, 0.012, MATS.dark, 0, 0, -0.01 + i * 0.025));
  parts.muzzleZ = null;
  parts.gripLocal = new THREE.Vector3(0, 0, 0.02);
  parts.foreLocal = null;
  return { group: g, parts };
}

function buildGrenade() {
  const g = new THREE.Group();
  const parts = {};
  const body = new THREE.Mesh(
    new THREE.SphereGeometry(0.055, 14, 12),
    mat('nade', { color: 0x3f5a34, roughness: 0.8, metalness: 0.15 }),
  );
  body.scale.set(1, 1.15, 1);
  g.add(body);
  g.add(cyl(0.016, 0.016, 0.03, MATS.steel, 0, 0.07, 0, 'y', 10));
  g.add(box(0.012, 0.07, 0.012, MATS.steel, 0.03, 0.04, 0));
  const ring = new THREE.Mesh(new THREE.TorusGeometry(0.016, 0.004, 6, 12), MATS.steel);
  ring.position.set(-0.03, 0.07, 0);
  ring.rotation.y = Math.PI / 2;
  g.add(ring);
  parts.muzzleZ = null;
  parts.gripLocal = new THREE.Vector3(0, -0.02, 0.03);
  parts.foreLocal = null;
  return { group: g, parts };
}

function buildWeapon(id) {
  switch (id) {
    case 'ak47': return buildAK();
    case 'galil': return buildAK();
    case 'm4a4': return buildM4();
    case 'famas': return buildM4();
    case 'awp': return buildAWP(true);
    case 'ssg08': return buildAWP(true);
    case 'mp9': return buildSMG(false);
    case 'mac10': return buildSMG(true);
    case 'deagle': return buildPistol('deagle');
    case 'p250': return buildPistol('p250');
    case 'glock': return buildPistol('glock');
    case 'usp': return buildPistol('usp');
    case 'he': return buildGrenade();
    case 'knife':
    default: return buildKnife();
  }
}

function flashTexture() {
  const c = document.createElement('canvas');
  c.width = c.height = 64;
  const ctx = c.getContext('2d');
  const grad = ctx.createRadialGradient(32, 32, 0, 32, 32, 32);
  grad.addColorStop(0, 'rgba(255,246,214,1)');
  grad.addColorStop(0.35, 'rgba(255,186,72,0.8)');
  grad.addColorStop(1, 'rgba(255,120,0,0)');
  ctx.fillStyle = grad;
  ctx.fillRect(0, 0, 64, 64);
  const tex = new THREE.CanvasTexture(c);
  tex.colorSpace = THREE.SRGBColorSpace;
  return tex;
}

export class ViewModel {
  constructor(mainCamera) {
    this.mainCamera = mainCamera;

    // Ayrı sahne + dar FOV kamera (silah duvara girmesin, perspektif bozulmasın)
    this.scene = new THREE.Scene();
    this.camera = new THREE.PerspectiveCamera(62, 1, 0.01, 5);
    this.scene.add(this.camera);

    const key = new THREE.DirectionalLight(0xfff0d8, 2.4);
    key.position.set(0.6, 1.2, 0.4);
    this.scene.add(key);
    const rim = new THREE.DirectionalLight(0x9fbcda, 1.1);
    rim.position.set(-0.8, 0.2, -0.9);
    this.scene.add(rim);
    this.scene.add(new THREE.AmbientLight(0xb9c8d6, 0.55));

    this.root = new THREE.Group();
    this.root.scale.setScalar(0.72);
    this.root.rotation.y = -0.035;
    this.scene.add(this.root);

    this.basePos = new THREE.Vector3(0.165, -0.135, -0.56);
    this.pos = this.basePos.clone();
    this.kick = 0;
    this.kickRot = 0;
    this.bobPhase = 0;
    this.swayX = 0;
    this.swayY = 0;
    this.reloadT = 0;
    this.reloadDuration = 1;
    this.hidden = false;
    this.currentId = null;
    this.parts = null;
    this.weaponGroup = null;
    this.boltRecoil = 0;

    this.flash = new THREE.Sprite(new THREE.SpriteMaterial({
      map: flashTexture(), transparent: true, depthWrite: false, blending: THREE.AdditiveBlending,
    }));
    this.flash.scale.setScalar(0.3);
    this.flash.visible = false;
    this.root.add(this.flash);
    this.flashLife = 0;

    this.flashLight = new THREE.PointLight(0xffcc88, 0, 2.5, 2);
    this.root.add(this.flashLight);

    this.hands = { right: hand(0), left: hand(0) };
    this.root.add(this.hands.right, this.hands.left);
  }

  setWeapon(id) {
    if (this.currentId === id) return;
    if (this.weaponGroup) this.root.remove(this.weaponGroup);
    const built = buildWeapon(id);
    this.weaponGroup = built.group;
    this.parts = built.parts;
    this.currentId = id;
    this.root.add(this.weaponGroup);

    // Elleri kabza ve ön el konumuna yerleştir
    const g = this.parts.gripLocal;
    this.hands.right.position.set(g.x + 0.005, g.y + 0.03, g.z + 0.02);
    this.hands.right.rotation.set(0.35, 0, 0.15);
    if (this.parts.foreLocal) {
      this.hands.left.visible = true;
      this.hands.left.position.set(this.parts.foreLocal.x - 0.01, this.parts.foreLocal.y + 0.02, this.parts.foreLocal.z);
      this.hands.left.rotation.set(0.2, 0, -0.5);
    } else {
      this.hands.left.visible = id === 'knife' ? false : true;
      this.hands.left.position.set(-0.05, g.y + 0.01, g.z + 0.03);
      this.hands.left.rotation.set(0.3, 0, -0.6);
    }
    this.magHome = this.parts.mag ? this.parts.mag.position.clone() : null;
    this.boltHome = this.parts.bolt ? this.parts.bolt.position.clone() : null;
  }

  fireKick(weapon) {
    const strength = ({ sniper: 1.6, rifle: 1.0, smg: 0.65, pistol: 0.8, knife: 0.4, grenade: 0.3 })[weapon.type] || 1;
    this.kick = Math.min(0.1, this.kick + 0.035 * strength);
    this.kickRot = Math.min(0.2, this.kickRot + 0.06 * strength);
    this.boltRecoil = 1;
    if (weapon.type !== 'knife' && weapon.type !== 'grenade' && this.parts && this.parts.muzzleZ !== null) {
      this.flash.position.set(0, 0.014, this.parts.muzzleZ + 0.02);
      this.flash.material.rotation = Math.random() * Math.PI;
      this.flash.scale.setScalar(0.22 + Math.random() * 0.16);
      this.flash.visible = true;
      this.flashLife = 0.045;
      this.flashLight.position.copy(this.flash.position);
      this.flashLight.intensity = 6;
    }
  }

  startReload(duration) {
    this.reloadT = duration;
    this.reloadDuration = duration;
  }

  update(dt, opts) {
    const { speed, onGround, zoom, alive } = opts;
    this.root.visible = alive && !this.hidden && zoom === 0;
    if (!this.root.visible) return;

    const moving = speed > 0.6 && onGround;
    this.bobPhase += dt * (moving ? 6 + speed * 1.4 : 0);
    const bobAmount = moving ? clamp(speed / 5, 0, 1) * 0.013 : 0;
    const bobX = Math.cos(this.bobPhase) * bobAmount;
    const bobY = Math.abs(Math.sin(this.bobPhase)) * bobAmount * 0.9;

    this.swayX = damp(this.swayX, clamp(-opts.mouseDX * 0.0014, -0.045, 0.045), 9, dt);
    this.swayY = damp(this.swayY, clamp(-opts.mouseDY * 0.0014, -0.045, 0.045), 9, dt);

    this.kick = damp(this.kick, 0, 11, dt);
    this.kickRot = damp(this.kickRot, 0, 10, dt);
    this.boltRecoil = damp(this.boltRecoil, 0, 22, dt);

    // Şarjör değiştirme zaman çizelgesi
    let reloadRot = 0;
    let reloadDrop = 0;
    if (this.reloadT > 0) {
      this.reloadT = Math.max(0, this.reloadT - dt);
      const k = 1 - this.reloadT / this.reloadDuration;      // 0..1
      const curve = Math.sin(clamp(k, 0, 1) * Math.PI);
      reloadRot = curve * 0.55;
      reloadDrop = curve * 0.1;
      if (this.parts && this.parts.mag && this.magHome) {
        const mag = this.parts.mag;
        if (k < 0.35) {
          // şarjör düşüyor
          const t = k / 0.35;
          mag.position.set(this.magHome.x, this.magHome.y - t * 0.32, this.magHome.z);
          mag.rotation.z = t * 0.6;
          mag.visible = true;
        } else if (k < 0.6) {
          mag.visible = false;
        } else {
          const t = clamp((k - 0.6) / 0.3, 0, 1);
          mag.visible = true;
          mag.position.set(this.magHome.x, this.magHome.y - (1 - t) * 0.28, this.magHome.z);
          mag.rotation.z = (1 - t) * 0.4;
        }
      }
      if (this.parts && this.parts.bolt && this.boltHome && k > 0.85) {
        const t = (k - 0.85) / 0.15;
        const pull = Math.sin(t * Math.PI) * 0.05;
        this.parts.bolt.position.z = this.boltHome.z + pull;
      }
    } else if (this.parts && this.parts.mag && this.magHome) {
      this.parts.mag.visible = true;
      this.parts.mag.position.copy(this.magHome);
      this.parts.mag.rotation.z = 0;
    }

    // Ateş sırasında sürgü/kapak geri gider
    if (this.parts && this.parts.bolt && this.boltHome && this.reloadT <= 0) {
      this.parts.bolt.position.z = this.boltHome.z + this.boltRecoil * 0.045;
    }

    const target = this.basePos;
    this.pos.x = damp(this.pos.x, target.x + bobX + this.swayX, 14, dt);
    this.pos.y = damp(this.pos.y, target.y + bobY + this.swayY - reloadDrop, 14, dt);
    this.pos.z = damp(this.pos.z, target.z + this.kick, 16, dt);
    this.root.position.copy(this.pos);
    this.root.rotation.set(
      this.kickRot * -1.0 + reloadRot,
      -0.035 + this.swayX * 1.5,
      this.swayX * 2.0 + reloadRot * 0.3,
    );

    if (this.flashLife > 0) {
      this.flashLife -= dt;
      this.flashLight.intensity *= Math.max(0, 1 - dt * 18);
      if (this.flashLife <= 0) {
        this.flash.visible = false;
        this.flashLight.intensity = 0;
      }
    }
  }

  setAspect(aspect) {
    this.camera.aspect = aspect;
    this.camera.updateProjectionMatrix();
  }
}
