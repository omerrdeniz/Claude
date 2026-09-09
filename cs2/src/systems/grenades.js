// El bombaları: HE, flaş, sis ve molotof/yangın.
// Fizik sekmeli, patlama etkileri tür bazlı. Sis görüşü engeller, ateş alan hasarı verir.

import * as THREE from 'three';
import { WEAPONS } from '../weapons.js';
import { segmentClear, clamp } from '../core/math.js';

const RADIUS = 0.09;
const GRAVITY = 15.24;
const RESTITUTION = 0.42;

function puffTexture(inner, outer) {
  const c = document.createElement('canvas');
  c.width = c.height = 64;
  const ctx = c.getContext('2d');
  const g = ctx.createRadialGradient(32, 32, 2, 32, 32, 31);
  g.addColorStop(0, inner);
  g.addColorStop(0.55, outer);
  g.addColorStop(1, 'rgba(0,0,0,0)');
  ctx.fillStyle = g;
  ctx.fillRect(0, 0, 64, 64);
  const tex = new THREE.CanvasTexture(c);
  tex.colorSpace = THREE.SRGBColorSpace;
  return tex;
}

export class Grenades {
  constructor(game) {
    this.game = game;
    this.list = [];
    this.smokes = [];
    this.fires = [];
    this.geo = new THREE.SphereGeometry(RADIUS, 10, 8);
    this.mats = {
      he: new THREE.MeshStandardMaterial({ color: 0x3f5a34, roughness: 0.7, metalness: 0.2 }),
      flash: new THREE.MeshStandardMaterial({ color: 0x9aa3ad, roughness: 0.4, metalness: 0.7 }),
      smoke: new THREE.MeshStandardMaterial({ color: 0x4a5a66, roughness: 0.6, metalness: 0.3 }),
      fire: new THREE.MeshStandardMaterial({ color: 0x7a4a22, roughness: 0.5, metalness: 0.1 }),
    };
    this.smokeTex = puffTexture('rgba(238,240,243,0.98)', 'rgba(205,210,216,0.75)');
    this.fireTex = puffTexture('rgba(255,238,170,0.98)', 'rgba(238,110,25,0.6)');
  }

  throwFrom(actor, id = 'he') {
    const game = this.game;
    const def = WEAPONS[id] || WEAPONS.he;
    const kind = def.kind || 'he';
    const eye = actor.eyePos(new THREE.Vector3());
    const dir = actor.forwardVector(new THREE.Vector3());
    const mesh = new THREE.Mesh(this.geo, this.mats[kind] || this.mats.he);
    mesh.castShadow = true;
    game.scene.add(mesh);

    const speed = 14.5;
    const g = {
      id, kind, def, mesh,
      pos: new THREE.Vector3(eye.x + dir.x * 0.5, eye.y + dir.y * 0.5, eye.z + dir.z * 0.5),
      vel: new THREE.Vector3(
        dir.x * speed + actor.vel.x * 0.5,
        dir.y * speed + 2.2 + actor.vel.y * 0.3,
        dir.z * speed + actor.vel.z * 0.5,
      ),
      fuse: def.fuse ?? 1.7,
      impact: !!def.impact,
      bounced: 0,
      owner: actor,
    };
    mesh.position.copy(g.pos);
    this.list.push(g);
    game.audio.play('ui', { freq: 360, volume: 0.35 });
    return g;
  }

  _collide(g, dt) {
    const world = this.game.world;
    const steps = Math.max(1, Math.ceil(g.vel.length() * dt / 0.15));
    const sdt = dt / steps;
    for (let s = 0; s < steps; s++) {
      g.vel.y -= GRAVITY * sdt;
      for (const axis of ['x', 'y', 'z']) {
        const old = g.pos[axis];
        g.pos[axis] += g.vel[axis] * sdt;
        const b = {
          minX: g.pos.x - RADIUS, maxX: g.pos.x + RADIUS,
          minY: g.pos.y - RADIUS, maxY: g.pos.y + RADIUS,
          minZ: g.pos.z - RADIUS, maxZ: g.pos.z + RADIUS,
        };
        let hit = null;
        for (const o of world.colliders) {
          if (b.minX < o.maxX && b.maxX > o.minX &&
              b.minY < o.maxY && b.maxY > o.minY &&
              b.minZ < o.maxZ && b.maxZ > o.minZ) { hit = o; break; }
        }
        if (hit) {
          g.pos[axis] = old;
          g.vel[axis] = -g.vel[axis] * RESTITUTION;
          const other = axis === 'y' ? ['x', 'z'] : ['y'];
          for (const a of other) g.vel[a] *= 0.85;
          if (Math.abs(g.vel[axis]) < 0.4) g.vel[axis] = 0;
          g.bounced++;
          if (g.bounced === 1) {
            this.game.audio.play('impact', { pos: g.pos, mat: 'metal', volume: 0.35 });
          }
          if (g.impact && g.bounced >= 1) return true;   // molotof ilk temasta patlar
        }
      }
    }
    g.mesh.position.copy(g.pos);
    return false;
  }

  detonate(g) {
    const game = this.game;
    switch (g.kind) {
      case 'flash': this._flash(g); break;
      case 'smoke': this._smoke(g); break;
      case 'fire': this._fire(g); break;
      default: this._he(g); break;
    }
    game.scene.remove(g.mesh);
  }

  _he(g) {
    const game = this.game;
    const def = g.def;
    game.effects.explosion(g.pos);
    game.audio.play('explosion', { pos: g.pos, volume: 1, maxDist: 90 });
    game.notifyNoise(g.owner, g.pos, 60);
    for (const a of game.actors) {
      if (!a.alive) continue;
      const center = a.center(new THREE.Vector3());
      const dist = center.distanceTo(g.pos);
      if (dist > def.radius) continue;
      if (!segmentClear(g.pos.x, g.pos.y, g.pos.z, center.x, center.y, center.z, game.world.colliders)) continue;
      const falloff = Math.max(0, 1 - dist / def.radius) ** 1.5;
      let dmg = def.damage * falloff;
      if (a.team === g.owner.team && a !== g.owner) dmg *= 0.4;
      const dealt = a.takeDamage(dmg, 'chest', g.owner, game, 0.5);
      game.onDamage(a, g.owner, dealt, 'chest', true);
    }
  }

  _flash(g) {
    const game = this.game;
    const def = g.def;
    game.effects.flashBurst(g.pos);
    game.audio.play('explosion', { pos: g.pos, volume: 0.55, maxDist: 70 });
    game.notifyNoise(g.owner, g.pos, 45);
    for (const a of game.actors) {
      if (!a.alive) continue;
      const eye = a.eyePos(new THREE.Vector3());
      const dist = eye.distanceTo(g.pos);
      if (dist > def.radius) continue;
      if (!segmentClear(g.pos.x, g.pos.y, g.pos.z, eye.x, eye.y, eye.z, game.world.colliders)) continue;
      // Bakış yönü ile flaşa olan açı: tam karşıya bakan tam kör olur
      const to = new THREE.Vector3().subVectors(g.pos, eye).normalize();
      const fwd = a.forwardVector(new THREE.Vector3());
      const facing = clamp(to.dot(fwd), -1, 1);
      if (facing < 0.05) continue;                       // arkası dönükse etkilenmez
      const distFactor = 1 - dist / def.radius;
      const strength = clamp(facing * 1.15, 0, 1) * clamp(distFactor * 1.4, 0, 1);
      const duration = def.blindMax * strength;
      if (duration < 0.25) continue;
      a.blindUntil = Math.max(a.blindUntil, game.time + duration);
      a.blindStrength = Math.max(a.blindStrength || 0, strength);
      if (a === game.player) game.onPlayerFlashed(duration, strength);
    }
  }

  _smoke(g) {
    const game = this.game;
    const def = g.def;
    const sprites = [];
    const group = new THREE.Group();
    for (let i = 0; i < 26; i++) {
      const s = new THREE.Sprite(new THREE.SpriteMaterial({
        map: this.smokeTex, transparent: true, depthWrite: false, opacity: 0,
        color: new THREE.Color(0.92, 0.93, 0.95),
      }));
      const a = Math.random() * Math.PI * 2;
      const r = Math.sqrt(Math.random()) * def.radius * 0.85;
      s.userData = {
        base: new THREE.Vector3(Math.cos(a) * r, Math.random() * def.radius * 0.9, Math.sin(a) * r),
        drift: (Math.random() - 0.5) * 0.12,
        size: def.radius * (0.7 + Math.random() * 0.6),
        phase: Math.random() * 6.28,
      };
      s.position.copy(s.userData.base);
      s.scale.setScalar(0.1);
      group.add(s);
      sprites.push(s);
    }
    group.position.copy(g.pos);
    group.position.y = Math.max(g.pos.y, 0.4);
    game.scene.add(group);
    this.smokes.push({
      pos: group.position.clone(),
      radius: def.radius,
      grow: 0,
      life: def.duration,
      maxLife: def.duration,
      group,
      sprites,
    });
    game.audio.play('smoke', { pos: g.pos, volume: 0.8, maxDist: 60 });
    game.notifyNoise(g.owner, g.pos, 25);
  }

  _fire(g) {
    const game = this.game;
    const def = g.def;
    const group = new THREE.Group();
    const flames = [];
    for (let i = 0; i < 18; i++) {
      const s = new THREE.Sprite(new THREE.SpriteMaterial({
        map: this.fireTex, transparent: true, depthWrite: false,
        blending: THREE.AdditiveBlending, opacity: 0.9,
      }));
      const a = Math.random() * Math.PI * 2;
      const r = Math.sqrt(Math.random()) * def.radius;
      s.position.set(Math.cos(a) * r, 0.25 + Math.random() * 0.3, Math.sin(a) * r);
      s.userData = { phase: Math.random() * 6.28, size: 0.9 + Math.random() * 0.9 };
      s.scale.setScalar(s.userData.size);
      group.add(s);
      flames.push(s);
    }
    const light = new THREE.PointLight(0xff8a30, 6, def.radius * 3, 2);
    light.position.y = 1;
    group.add(light);
    group.position.set(g.pos.x, 0.02, g.pos.z);
    game.scene.add(group);
    this.fires.push({
      pos: new THREE.Vector3(g.pos.x, 0, g.pos.z),
      radius: def.radius,
      life: def.duration,
      maxLife: def.duration,
      dps: def.dps,
      owner: g.owner,
      group,
      flames,
      light,
    });
    game.audio.play('fire', { pos: g.pos, volume: 0.8, maxDist: 45 });
  }

  // --- Sorgular -------------------------------------------------------
  // İki nokta arasındaki doğru parçası sisin içinden yeterince geçiyor mu?
  blocksVision(ax, ay, az, bx, by, bz) {
    if (this.smokes.length === 0) return false;
    for (const s of this.smokes) {
      const r = s.radius * Math.min(1, s.grow);
      if (r < 0.8) continue;
      const dx = bx - ax, dy = by - ay, dz = bz - az;
      const len = Math.hypot(dx, dy, dz);
      if (len < 1e-4) continue;
      const ux = dx / len, uy = dy / len, uz = dz / len;
      const cx = s.pos.x - ax, cy = s.pos.y - ay, cz = s.pos.z - az;
      const t = cx * ux + cy * uy + cz * uz;
      const closest = Math.max(0, Math.min(len, t));
      const px = ax + ux * closest - s.pos.x;
      const py = ay + uy * closest - s.pos.y;
      const pz = az + uz * closest - s.pos.z;
      const d2 = px * px + py * py + pz * pz;
      if (d2 >= r * r) continue;
      // sis içinde kalan uzunluk
      const half = Math.sqrt(r * r - d2);
      const t0 = Math.max(0, t - half);
      const t1 = Math.min(len, t + half);
      if (t1 - t0 > 0.9) return true;
    }
    return false;
  }

  fireAt(x, z) {
    for (const f of this.fires) {
      if (Math.hypot(f.pos.x - x, f.pos.z - z) < f.radius) return f;
    }
    return null;
  }

  update(dt) {
    const game = this.game;

    // Uçan bombalar
    for (let i = this.list.length - 1; i >= 0; i--) {
      const g = this.list[i];
      const impacted = this._collide(g, dt);
      g.fuse -= dt;
      if (impacted || g.fuse <= 0) {
        this.detonate(g);
        this.list.splice(i, 1);
      }
    }

    // Sis bulutları
    for (let i = this.smokes.length - 1; i >= 0; i--) {
      const s = this.smokes[i];
      s.grow = Math.min(1, s.grow + dt / 0.9);
      s.life -= dt;
      const fade = s.life < 2.5 ? Math.max(0, s.life / 2.5) : 1;
      for (const sp of s.sprites) {
        const u = sp.userData;
        u.phase += dt * 0.6;
        sp.scale.setScalar(u.size * s.grow * (0.9 + Math.sin(u.phase) * 0.08));
        sp.position.set(
          u.base.x * s.grow + Math.sin(u.phase) * 0.12,
          u.base.y * s.grow + u.drift * (s.maxLife - s.life) * 0.25,
          u.base.z * s.grow + Math.cos(u.phase * 0.8) * 0.12,
        );
        sp.material.opacity = 0.62 * fade * Math.min(1, s.grow * 1.5);
      }
      if (s.life <= 0) {
        game.scene.remove(s.group);
        this.smokes.splice(i, 1);
      }
    }

    // Ateş alanları
    for (let i = this.fires.length - 1; i >= 0; i--) {
      const f = this.fires[i];
      f.life -= dt;
      const fade = f.life < 1.5 ? Math.max(0, f.life / 1.5) : 1;
      for (const fl of f.flames) {
        fl.userData.phase += dt * 8;
        const flick = 0.75 + Math.sin(fl.userData.phase) * 0.25;
        fl.scale.setScalar(fl.userData.size * flick * fade);
        fl.material.opacity = 0.85 * fade * flick;
      }
      f.light.intensity = (5 + Math.sin(game.time * 12) * 2) * fade;

      // Hasar
      for (const a of game.actors) {
        if (!a.alive) continue;
        if (Math.hypot(a.pos.x - f.pos.x, a.pos.z - f.pos.z) > f.radius) continue;
        if (a.pos.y > 2.2) continue;
        if (game.time < (a.nextBurnTick || 0)) continue;
        a.nextBurnTick = game.time + 0.25;
        const dealt = a.takeDamage(f.dps * 0.25, 'legs', f.owner, game, 0.85);
        game.onDamage(a, f.owner, dealt, 'legs', true);
      }

      if (f.life <= 0) {
        game.scene.remove(f.group);
        this.fires.splice(i, 1);
      }
    }
  }

  clear() {
    for (const g of this.list) this.game.scene.remove(g.mesh);
    for (const s of this.smokes) this.game.scene.remove(s.group);
    for (const f of this.fires) this.game.scene.remove(f.group);
    this.list.length = 0;
    this.smokes.length = 0;
    this.fires.length = 0;
  }
}
