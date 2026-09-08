// Birinci şahıs silah modeli: prosedürel geometri + sallanma, sekme ve şarjör animasyonu.

import * as THREE from 'three';
import { damp, clamp } from '../core/math.js';

const MATS = {
  body: new THREE.MeshLambertMaterial({ color: 0x33363b }),
  dark: new THREE.MeshLambertMaterial({ color: 0x1d1f22 }),
  wood: new THREE.MeshLambertMaterial({ color: 0x6d4a25 }),
  metal: new THREE.MeshLambertMaterial({ color: 0x6a6d72 }),
  hand: new THREE.MeshLambertMaterial({ color: 0x9a7550 }),
};

function box(w, h, d, mat, x, y, z) {
  const m = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), mat);
  m.position.set(x, y, z);
  return m;
}

function buildWeapon(id, type) {
  const g = new THREE.Group();
  switch (id) {
    case 'ak47':
      g.add(box(0.07, 0.10, 0.62, MATS.body, 0, 0, -0.18));
      g.add(box(0.05, 0.05, 0.42, MATS.dark, 0, 0.03, -0.52));
      g.add(box(0.06, 0.16, 0.10, MATS.wood, 0, -0.11, -0.10));
      g.add(box(0.07, 0.09, 0.22, MATS.wood, 0, -0.01, 0.20));
      g.add(box(0.05, 0.06, 0.10, MATS.dark, 0, 0.07, -0.34));
      break;
    case 'm4a4':
    case 'famas':
    case 'galil':
      g.add(box(0.07, 0.10, 0.58, MATS.body, 0, 0, -0.16));
      g.add(box(0.045, 0.045, 0.40, MATS.dark, 0, 0.02, -0.50));
      g.add(box(0.06, 0.15, 0.09, MATS.dark, 0, -0.10, -0.08));
      g.add(box(0.07, 0.09, 0.24, MATS.body, 0, 0.0, 0.22));
      g.add(box(0.03, 0.05, 0.20, MATS.dark, 0, 0.08, -0.20));
      break;
    case 'awp':
    case 'ssg08':
      g.add(box(0.07, 0.09, 0.75, MATS.body, 0, 0, -0.20));
      g.add(box(0.04, 0.04, 0.55, MATS.dark, 0, 0.01, -0.66));
      g.add(box(0.06, 0.14, 0.09, MATS.dark, 0, -0.09, -0.02));
      g.add(box(0.07, 0.11, 0.30, MATS.body, 0, -0.01, 0.26));
      g.add(box(0.06, 0.06, 0.26, MATS.metal, 0, 0.09, -0.22));   // dürbün
      break;
    case 'mp9':
    case 'mac10':
      g.add(box(0.07, 0.11, 0.34, MATS.body, 0, 0, -0.10));
      g.add(box(0.04, 0.04, 0.22, MATS.dark, 0, 0.02, -0.33));
      g.add(box(0.05, 0.16, 0.08, MATS.dark, 0, -0.10, -0.02));
      g.add(box(0.05, 0.05, 0.18, MATS.dark, 0, 0.02, 0.16));
      break;
    case 'deagle':
    case 'p250':
    case 'glock':
    case 'usp':
      g.add(box(0.055, 0.09, 0.26, MATS.body, 0, 0, -0.06));
      g.add(box(0.05, 0.13, 0.07, MATS.dark, 0, -0.10, 0.04));
      if (id === 'usp') g.add(box(0.05, 0.05, 0.16, MATS.dark, 0, 0.005, -0.26));
      if (id === 'deagle') g.add(box(0.06, 0.10, 0.30, MATS.metal, 0, 0.01, -0.10));
      break;
    case 'he':
      g.add(new THREE.Mesh(new THREE.SphereGeometry(0.075, 12, 10), new THREE.MeshLambertMaterial({ color: 0x3f6b3a })));
      g.add(box(0.03, 0.06, 0.03, MATS.metal, 0, 0.08, 0));
      break;
    case 'knife':
    default:
      g.add(box(0.02, 0.05, 0.30, MATS.metal, 0, 0, -0.14));
      g.add(box(0.035, 0.06, 0.12, MATS.dark, 0, -0.01, 0.08));
      break;
  }
  // Eller
  const gripY = type === 'knife' ? -0.02 : -0.09;
  g.add(box(0.075, 0.10, 0.11, MATS.hand, 0.005, gripY - 0.03, type === 'pistol' ? 0.03 : -0.06));
  if (type !== 'pistol' && type !== 'knife' && type !== 'grenade') {
    g.add(box(0.08, 0.09, 0.12, MATS.hand, 0, -0.07, -0.34));
  }
  for (const c of g.children) c.castShadow = false;
  return g;
}

export class ViewModel {
  constructor(camera) {
    this.camera = camera;
    this.root = new THREE.Group();
    this.root.name = 'viewmodel';
    this.root.scale.setScalar(0.5);   // ekranı kaplamasın diye küçültülmüş model
    camera.add(this.root);
    this.current = null;
    this.currentId = null;

    this.basePos = new THREE.Vector3(0.21, -0.16, -0.56);
    this.pos = this.basePos.clone();
    this.rot = new THREE.Euler(0, 0, 0);
    this.kick = 0;
    this.kickRot = 0;
    this.bobPhase = 0;
    this.swayX = 0;
    this.swayY = 0;
    this.reloadT = 0;
    this.reloadDuration = 1;
    this.aimBlend = 0;
    this.hidden = false;

    // Namlu alevi
    const canvas = document.createElement('canvas');
    canvas.width = canvas.height = 64;
    const ctx = canvas.getContext('2d');
    const grad = ctx.createRadialGradient(32, 32, 0, 32, 32, 32);
    grad.addColorStop(0, 'rgba(255,240,190,1)');
    grad.addColorStop(0.4, 'rgba(255,180,60,0.75)');
    grad.addColorStop(1, 'rgba(255,120,0,0)');
    ctx.fillStyle = grad;
    ctx.fillRect(0, 0, 64, 64);
    const tex = new THREE.CanvasTexture(canvas);
    tex.colorSpace = THREE.SRGBColorSpace;
    this.flash = new THREE.Sprite(new THREE.SpriteMaterial({
      map: tex, transparent: true, depthWrite: false, blending: THREE.AdditiveBlending,
    }));
    this.flash.scale.setScalar(0.35);
    this.flash.visible = false;
    this.root.add(this.flash);
    this.flashLife = 0;
  }

  setWeapon(id, type) {
    if (this.currentId === id) return;
    if (this.current) this.root.remove(this.current);
    this.current = buildWeapon(id, type);
    this.currentId = id;
    this.root.add(this.current);
    this.muzzleZ = ({
      ak47: -0.78, m4a4: -0.74, famas: -0.72, galil: -0.74,
      awp: -0.98, ssg08: -0.98, mp9: -0.46, mac10: -0.46,
      deagle: -0.28, p250: -0.22, glock: -0.22, usp: -0.36,
    })[id] || -0.3;
  }

  fireKick(weapon) {
    const strength = ({ sniper: 1.5, rifle: 1.0, smg: 0.7, pistol: 0.8, knife: 0.4, grenade: 0.3 })[weapon.type] || 1;
    this.kick = Math.min(0.13, this.kick + 0.045 * strength);
    this.kickRot = Math.min(0.22, this.kickRot + 0.07 * strength);
    if (weapon.type !== 'knife' && weapon.type !== 'grenade') {
      this.flash.position.set(0, 0.01, this.muzzleZ);
      this.flash.material.rotation = Math.random() * Math.PI;
      this.flash.scale.setScalar(0.28 + Math.random() * 0.16);
      this.flash.visible = true;
      this.flashLife = 0.04;
    }
  }

  startReload(duration) {
    this.reloadT = duration;
    this.reloadDuration = duration;
  }

  update(dt, opts) {
    const { speed, onGround, zoom, alive } = opts;
    this.root.visible = alive && !this.hidden && zoom === 0;

    // Yürüyüş sallanması
    const moving = speed > 0.6 && onGround;
    this.bobPhase += dt * (moving ? 6 + speed * 1.4 : 0);
    const bobAmount = moving ? clamp(speed / 5, 0, 1) * 0.014 : 0;
    const bobX = Math.cos(this.bobPhase) * bobAmount;
    const bobY = Math.abs(Math.sin(this.bobPhase)) * bobAmount * 0.9;

    // Fare sallanması (sway)
    this.swayX = damp(this.swayX, clamp(-opts.mouseDX * 0.0016, -0.05, 0.05), 9, dt);
    this.swayY = damp(this.swayY, clamp(-opts.mouseDY * 0.0016, -0.05, 0.05), 9, dt);

    // Sekme toparlanması
    this.kick = damp(this.kick, 0, 11, dt);
    this.kickRot = damp(this.kickRot, 0, 10, dt);

    // Şarjör animasyonu
    let reloadRot = 0;
    let reloadDrop = 0;
    if (this.reloadT > 0) {
      this.reloadT = Math.max(0, this.reloadT - dt);
      const k = 1 - this.reloadT / this.reloadDuration;
      const curve = Math.sin(clamp(k, 0, 1) * Math.PI);
      reloadRot = curve * 0.85;
      reloadDrop = curve * 0.14;
    }

    const target = this.basePos;
    this.pos.x = damp(this.pos.x, target.x + bobX + this.swayX, 14, dt);
    this.pos.y = damp(this.pos.y, target.y + bobY + this.swayY - reloadDrop, 14, dt);
    this.pos.z = damp(this.pos.z, target.z + this.kick, 16, dt);
    this.root.position.copy(this.pos);
    this.root.rotation.set(
      this.kickRot * -1.1 + reloadRot,
      this.swayX * 1.6,
      this.swayX * 2.2 + reloadRot * 0.25,
    );

    if (this.flashLife > 0) {
      this.flashLife -= dt;
      if (this.flashLife <= 0) this.flash.visible = false;
    }
  }
}
