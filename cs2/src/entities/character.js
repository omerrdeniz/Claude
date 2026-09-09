// Prosedürel karakter modeli: eklem hiyerarşisi, teçhizat ve yürüyüş/nişan/ölüm animasyonu.
// Harici model dosyası yoktur; her parça three.js primitifleriyle üretilir.

import * as THREE from 'three';
import { damp, clamp } from '../core/math.js';

const GEO = {};
const MATS = {};

function geo(key, build) {
  if (!GEO[key]) GEO[key] = build();
  return GEO[key];
}

function mat(key, params) {
  if (!MATS[key]) MATS[key] = new THREE.MeshStandardMaterial(params);
  return MATS[key];
}

const PALETTE = {
  CT: {
    suit: 0x2b3442,        // koyu lacivert taktik üniforma
    vest: 0x1d2530,
    pads: 0x39445a,
    helmet: 0x323d4c,
    glass: 0x121820,
    skin: 0xb98a63,
    gloves: 0x22282f,
    boots: 0x1a1e24,
    accent: 0x5b8bd0,
  },
  T: {
    suit: 0x7d6136,        // kum rengi
    vest: 0x4a3a20,
    pads: 0x8b6f3f,
    helmet: 0x2c2620,      // kar maskesi
    glass: 0x14100c,
    skin: 0xa9784f,
    gloves: 0x2a2118,
    boots: 0x241d16,
    accent: 0xd9a441,
  },
};

function limb(radius, length, material) {
  const g = geo(`cap${radius}_${length}`, () => new THREE.CapsuleGeometry(radius, length, 4, 10));
  const m = new THREE.Mesh(g, material);
  m.castShadow = true;
  return m;
}

function boxMesh(w, h, d, material, key) {
  const g = geo(key || `box${w}_${h}_${d}`, () => new THREE.BoxGeometry(w, h, d));
  const m = new THREE.Mesh(g, material);
  m.castShadow = true;
  return m;
}

// Elde tutulan basit silah silueti (üçüncü şahıs görünümü)
function handWeapon(type, palette) {
  const g = new THREE.Group();
  const body = mat('tp-gun', { color: 0x24262a, roughness: 0.55, metalness: 0.65 });
  const wood = mat('tp-wood', { color: 0x6b4526, roughness: 0.75, metalness: 0.05 });
  if (type === 'knife') {
    const blade = boxMesh(0.02, 0.05, 0.26, mat('tp-blade', { color: 0xc9ced6, roughness: 0.25, metalness: 0.95 }));
    blade.position.set(0, 0, -0.16);
    const grip = boxMesh(0.035, 0.05, 0.11, body);
    g.add(blade, grip);
    return g;
  }
  if (type === 'pistol') {
    const slide = boxMesh(0.045, 0.075, 0.24, body);
    slide.position.set(0, 0.02, -0.06);
    const grip = boxMesh(0.045, 0.13, 0.07, body);
    grip.position.set(0, -0.07, 0.03);
    grip.rotation.x = -0.22;
    g.add(slide, grip);
    return g;
  }
  const isSniper = type === 'sniper';
  const receiver = boxMesh(0.055, 0.09, isSniper ? 0.5 : 0.4, body);
  receiver.position.set(0, 0, -0.06);
  const barrel = new THREE.Mesh(
    geo('tp-barrel', () => new THREE.CylinderGeometry(0.017, 0.017, 1, 8)),
    body,
  );
  barrel.castShadow = true;
  barrel.rotation.x = Math.PI / 2;
  barrel.scale.y = isSniper ? 0.62 : 0.42;
  barrel.position.set(0, 0.012, isSniper ? -0.55 : -0.44);
  const magazine = boxMesh(0.03, 0.16, 0.07, body);
  magazine.position.set(0, -0.11, -0.02);
  magazine.rotation.x = 0.18;
  const stock = boxMesh(0.05, 0.075, 0.22, type === 'rifle' ? wood : body);
  stock.position.set(0, -0.02, 0.2);
  g.add(receiver, barrel, magazine, stock);
  if (isSniper) {
    const scope = new THREE.Mesh(
      geo('tp-scope', () => new THREE.CylinderGeometry(0.028, 0.028, 0.24, 10)),
      body,
    );
    scope.rotation.x = Math.PI / 2;
    scope.position.set(0, 0.08, -0.1);
    g.add(scope);
  }
  void palette;
  return g;
}

export function createCharacter(team) {
  const p = PALETTE[team] || PALETTE.CT;
  const suit = mat(`suit${team}`, { color: p.suit, roughness: 0.85, metalness: 0.04 });
  const vest = mat(`vest${team}`, { color: p.vest, roughness: 0.7, metalness: 0.12 });
  const pads = mat(`pads${team}`, { color: p.pads, roughness: 0.8, metalness: 0.05 });
  const helmetMat = mat(`helm${team}`, { color: p.helmet, roughness: 0.55, metalness: 0.2 });
  const glassMat = mat(`glass${team}`, { color: p.glass, roughness: 0.15, metalness: 0.7 });
  const skinMat = mat(`skin${team}`, { color: p.skin, roughness: 0.9, metalness: 0 });
  const gloveMat = mat(`glove${team}`, { color: p.gloves, roughness: 0.85, metalness: 0.05 });
  const bootMat = mat(`boot${team}`, { color: p.boots, roughness: 0.8, metalness: 0.1 });
  const accentMat = mat(`accent${team}`, { color: p.accent, roughness: 0.6, metalness: 0.1 });

  const root = new THREE.Group();

  // --- Kalça ve gövde -----------------------------------------------
  const hips = new THREE.Group();
  hips.position.y = 0.92;
  root.add(hips);

  const pelvis = boxMesh(0.32, 0.2, 0.22, suit);
  pelvis.position.y = 0.02;
  hips.add(pelvis);

  const torso = new THREE.Group();
  hips.add(torso);

  const chest = boxMesh(0.4, 0.46, 0.24, suit);
  chest.position.y = 0.29;
  torso.add(chest);

  const vestMesh = boxMesh(0.43, 0.36, 0.28, vest);
  vestMesh.position.set(0, 0.3, 0);
  torso.add(vestMesh);

  // omuz pedleri
  for (const sx of [-1, 1]) {
    const pad = limb(0.075, 0.06, pads);
    pad.rotation.z = Math.PI / 2;
    pad.position.set(sx * 0.22, 0.44, 0);
    torso.add(pad);
  }
  // sırt çantası / fişeklik
  const pack = boxMesh(0.3, 0.26, 0.12, vest);
  pack.position.set(0, 0.3, 0.19);
  torso.add(pack);
  const beltPouch = boxMesh(0.12, 0.09, 0.08, pads);
  beltPouch.position.set(0.14, 0.06, -0.12);
  torso.add(beltPouch);
  // takım rengi bandı
  const band = boxMesh(0.44, 0.05, 0.29, accentMat);
  band.position.set(0, 0.15, 0);
  torso.add(band);

  // --- Boyun ve kafa -------------------------------------------------
  const neck = new THREE.Group();
  neck.position.y = 0.52;
  torso.add(neck);

  const head = new THREE.Mesh(
    geo('head', () => new THREE.SphereGeometry(0.115, 14, 12)),
    team === 'T' ? helmetMat : skinMat,
  );
  head.castShadow = true;
  head.scale.set(0.92, 1.05, 1);
  head.position.y = 0.11;
  neck.add(head);

  const jaw = boxMesh(0.16, 0.1, 0.14, team === 'T' ? helmetMat : skinMat);
  jaw.position.set(0, 0.06, -0.04);
  neck.add(jaw);

  // kask (CT) / bere (T)
  const helmet = new THREE.Mesh(
    geo('helmet', () => new THREE.SphereGeometry(0.128, 14, 10, 0, Math.PI * 2, 0, Math.PI * 0.55)),
    helmetMat,
  );
  helmet.castShadow = true;
  helmet.position.y = 0.115;
  neck.add(helmet);

  // gözlük / vizör
  const visor = boxMesh(0.2, 0.05, 0.03, glassMat);
  visor.position.set(0, 0.12, -0.1);
  neck.add(visor);

  // kulaklık
  for (const sx of [-1, 1]) {
    const cup = new THREE.Mesh(
      geo('earcup', () => new THREE.CylinderGeometry(0.042, 0.042, 0.04, 10)),
      helmetMat,
    );
    cup.rotation.z = Math.PI / 2;
    cup.position.set(sx * 0.115, 0.11, 0);
    neck.add(cup);
  }

  // --- Kollar ---------------------------------------------------------
  const arms = {};
  for (const side of ['L', 'R']) {
    const sx = side === 'L' ? -1 : 1;
    const shoulder = new THREE.Group();
    shoulder.position.set(sx * 0.21, 0.42, 0);
    torso.add(shoulder);

    const upper = limb(0.062, 0.2, suit);
    upper.position.y = -0.13;
    shoulder.add(upper);

    const elbow = new THREE.Group();
    elbow.position.y = -0.25;
    shoulder.add(elbow);

    const fore = limb(0.055, 0.18, suit);
    fore.position.y = -0.12;
    elbow.add(fore);

    const hand = limb(0.05, 0.05, gloveMat);
    hand.position.y = -0.24;
    elbow.add(hand);

    arms[side] = { shoulder, elbow, upper, fore, hand };
  }

  // --- Bacaklar --------------------------------------------------------
  const legs = {};
  for (const side of ['L', 'R']) {
    const sx = side === 'L' ? -1 : 1;
    const hip = new THREE.Group();
    hip.position.set(sx * 0.105, -0.02, 0);
    hips.add(hip);

    const thigh = limb(0.082, 0.26, suit);
    thigh.position.y = -0.19;
    hip.add(thigh);

    const knee = new THREE.Group();
    knee.position.y = -0.38;
    hip.add(knee);

    const shin = limb(0.068, 0.24, suit);
    shin.position.y = -0.18;
    knee.add(shin);

    const boot = boxMesh(0.12, 0.1, 0.24, bootMat);
    boot.position.set(0, -0.36, -0.04);
    knee.add(boot);

    legs[side] = { hip, knee, thigh, shin, boot };
  }

  // --- Silah -----------------------------------------------------------
  const weaponMount = new THREE.Group();
  weaponMount.position.set(0.16, 0.24, -0.24);
  torso.add(weaponMount);

  const group = new THREE.Group();
  group.add(root);
  group.userData = {
    root, hips, torso, neck, head, helmet, arms, legs, weaponMount,
    weaponType: null, weaponMesh: null, team,
    deathTilt: (Math.random() - 0.5) * 0.6,
  };
  return group;
}

// Elindeki silahı tipe göre değiştirir.
function syncWeapon(model, type) {
  const u = model.userData;
  if (u.weaponType === type) return;
  if (u.weaponMesh) u.weaponMount.remove(u.weaponMesh);
  u.weaponMesh = handWeapon(type, PALETTE[u.team]);
  u.weaponType = type;
  u.weaponMount.add(u.weaponMesh);
}

export function updateCharacter(actor, dt) {
  const model = actor.model;
  if (!model) return;
  const u = model.userData;

  model.position.set(actor.pos.x, actor.pos.y, actor.pos.z);

  if (!actor.alive) {
    // Çöküş: dizler bükülür, gövde yana devrilir
    u.root.rotation.x = damp(u.root.rotation.x, -Math.PI / 2 + 0.12, 5, dt);
    u.root.rotation.z = damp(u.root.rotation.z, u.deathTilt, 4, dt);
    u.root.position.y = damp(u.root.position.y, -0.72, 5, dt);
    for (const side of ['L', 'R']) {
      u.legs[side].hip.rotation.x = damp(u.legs[side].hip.rotation.x, 0.5, 4, dt);
      u.legs[side].knee.rotation.x = damp(u.legs[side].knee.rotation.x, -0.9, 4, dt);
      u.arms[side].shoulder.rotation.x = damp(u.arms[side].shoulder.rotation.x, 0.6, 4, dt);
      u.arms[side].elbow.rotation.x = damp(u.arms[side].elbow.rotation.x, -0.4, 4, dt);
    }
    model.rotation.y = actor.yaw;
    return;
  }

  u.root.rotation.set(0, 0, 0);
  model.rotation.y = actor.yaw;

  const weapon = actor.weapon();
  syncWeapon(model, weapon.type === 'grenade' ? 'pistol' : weapon.type);

  const speed = Math.hypot(actor.vel.x, actor.vel.z);
  const moving = speed > 0.4 && actor.onGround;
  const crouch = clamp((1.8 - actor.height) / 0.55, 0, 1);
  const phase = actor.walkPhase * 2;
  const amp = Math.min(0.62, speed * 0.13);

  // Gövde duruşu
  const lean = clamp(actor.pitch * 0.35, -0.35, 0.35);
  u.torso.rotation.x = damp(u.torso.rotation.x, lean + crouch * 0.3, 12, dt);
  u.neck.rotation.x = damp(u.neck.rotation.x, actor.pitch * 0.45 - crouch * 0.15, 12, dt);
  u.hips.position.y = damp(u.hips.position.y, 0.92 - crouch * 0.42, 12, dt);

  // Bacaklar
  for (const side of ['L', 'R']) {
    const s = side === 'L' ? 1 : -1;
    const leg = u.legs[side];
    let hipRot;
    let kneeRot;
    if (!actor.onGround) {
      hipRot = 0.55 * s + 0.2;
      kneeRot = -0.85;
    } else if (moving) {
      hipRot = Math.sin(phase) * amp * s;
      kneeRot = -Math.max(0, Math.sin(phase + 0.9) * s) * amp * 1.7 - 0.05;
    } else {
      hipRot = crouch * 0.95;
      kneeRot = -crouch * 1.7 - 0.05;
    }
    leg.hip.rotation.x = damp(leg.hip.rotation.x, hipRot + crouch * 0.7, 14, dt);
    leg.knee.rotation.x = damp(leg.knee.rotation.x, kneeRot - crouch * 1.1, 14, dt);
  }

  // Kollar: silah tutuş pozu (sağ el tetik, sol el ön kabza)
  const sway = moving ? Math.sin(phase) * 0.06 : 0;
  const aim = actor.pitch * 0.5;
  const rArm = u.arms.R;
  rArm.shoulder.rotation.set(-0.95 - aim, 0.18, -0.22);
  rArm.elbow.rotation.x = damp(rArm.elbow.rotation.x, -1.0, 12, dt);
  const lArm = u.arms.L;
  lArm.shoulder.rotation.set(-1.05 - aim + sway, -0.3, 0.3);
  lArm.elbow.rotation.x = damp(lArm.elbow.rotation.x, -0.95, 12, dt);

  // Silahın konumu ve nişan açısı
  u.weaponMount.position.set(0.13, 0.26 + sway * 0.1, -0.3);
  u.weaponMount.rotation.set(-aim * 1.2, 0.06, 0);

  // Yürürken hafif yukarı-aşağı
  u.root.position.y = moving ? Math.abs(Math.sin(phase)) * 0.028 : damp(u.root.position.y, 0, 8, dt);
}
