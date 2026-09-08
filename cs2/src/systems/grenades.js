// HE bombası: sekmeli fizik + patlama hasarı.

import * as THREE from 'three';
import { WEAPONS } from '../weapons.js';
import { segmentClear } from '../core/math.js';

const RADIUS = 0.09;
const GRAVITY = 15.24;
const RESTITUTION = 0.42;

export class Grenades {
  constructor(game) {
    this.game = game;
    this.list = [];
    this.geo = new THREE.SphereGeometry(RADIUS, 10, 8);
    this.mat = new THREE.MeshLambertMaterial({ color: 0x3f6b3a });
  }

  throwFrom(actor) {
    const game = this.game;
    const eye = actor.eyePos(new THREE.Vector3());
    const dir = actor.forwardVector(new THREE.Vector3());
    const mesh = new THREE.Mesh(this.geo, this.mat);
    mesh.castShadow = true;
    game.scene.add(mesh);

    const speed = 14.5;
    const g = {
      mesh,
      pos: new THREE.Vector3(eye.x + dir.x * 0.5, eye.y + dir.y * 0.5, eye.z + dir.z * 0.5),
      vel: new THREE.Vector3(
        dir.x * speed + actor.vel.x * 0.5,
        dir.y * speed + 2.2 + actor.vel.y * 0.3,
        dir.z * speed + actor.vel.z * 0.5,
      ),
      fuse: WEAPONS.he.fuse,
      owner: actor,
    };
    mesh.position.copy(g.pos);
    this.list.push(g);
    game.audio.play('ui', { freq: 380, volume: 0.4 });
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
        const box = {
          minX: g.pos.x - RADIUS, maxX: g.pos.x + RADIUS,
          minY: g.pos.y - RADIUS, maxY: g.pos.y + RADIUS,
          minZ: g.pos.z - RADIUS, maxZ: g.pos.z + RADIUS,
        };
        let hit = null;
        for (const o of world.colliders) {
          if (box.minX < o.maxX && box.maxX > o.minX &&
              box.minY < o.maxY && box.maxY > o.minY &&
              box.minZ < o.maxZ && box.maxZ > o.minZ) { hit = o; break; }
        }
        if (hit) {
          g.pos[axis] = old;
          g.vel[axis] = -g.vel[axis] * RESTITUTION;
          // sürtünme
          const other = axis === 'y' ? ['x', 'z'] : ['y'];
          for (const a of other) g.vel[a] *= 0.85;
          if (Math.abs(g.vel[axis]) < 0.4) g.vel[axis] = 0;
        }
      }
    }
    g.mesh.position.copy(g.pos);
  }

  explode(g) {
    const game = this.game;
    const def = WEAPONS.he;
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

    game.scene.remove(g.mesh);
  }

  update(dt) {
    for (let i = this.list.length - 1; i >= 0; i--) {
      const g = this.list[i];
      this._collide(g, dt);
      g.fuse -= dt;
      if (g.fuse <= 0) {
        this.explode(g);
        this.list.splice(i, 1);
      }
    }
  }

  clear() {
    for (const g of this.list) this.game.scene.remove(g.mesh);
    this.list.length = 0;
  }
}
