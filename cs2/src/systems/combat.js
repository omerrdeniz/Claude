// Mermi/bıçak vuruş çözümü, duvar delme (wallbang) ve hasar uygulaması.

import * as THREE from 'three';
import { rayBox, raycastBoxes, gauss, DEG, clamp } from '../core/math.js';

const MAX_RANGE = 90;
const MAX_PENETRATIONS = 2;

export class Combat {
  constructor(game) {
    this.game = game;
    this._o = new THREE.Vector3();
    this._d = new THREE.Vector3();
    this._p = new THREE.Vector3();
    this._n = new THREE.Vector3();
  }

  // Belirli bir ışının aktörlerle kesişimi (en yakın).
  traceActors(ox, oy, oz, dx, dy, dz, maxT, ignore) {
    let best = null;
    for (const a of this.game.actors) {
      if (a === ignore || !a.alive) continue;
      for (const hb of a.hitboxes()) {
        const hit = rayBox(ox, oy, oz, dx, dy, dz, hb, maxT);
        if (hit && (!best || hit.t < best.t)) {
          best = { t: hit.t, actor: a, part: hb.part, mul: hb.mul, nx: hit.nx, ny: hit.ny, nz: hit.nz };
        }
      }
    }
    return best;
  }

  // Kutudan çıkış noktasına kadar olan kalınlık (duvar delme için).
  thicknessThrough(box, ox, oy, oz, dx, dy, dz, entryT, maxThickness = 1.0) {
    const step = 0.04;
    for (let d = step; d <= maxThickness; d += step) {
      const t = entryT + d;
      const px = ox + dx * t;
      const py = oy + dy * t;
      const pz = oz + dz * t;
      if (px < box.minX || px > box.maxX || py < box.minY || py > box.maxY || pz < box.minZ || pz > box.maxZ) {
        return d;
      }
    }
    return Infinity;
  }

  aimDirection(actor, weapon, out) {
    const inaccuracy = actor.currentInaccuracy();
    const yaw = actor.aimYaw();
    const pitch = actor.aimPitch();
    const spreadYaw = gauss() * inaccuracy * DEG * 0.5;
    const spreadPitch = gauss() * inaccuracy * DEG * 0.5;
    const y = yaw + spreadYaw;
    const p = clamp(pitch + spreadPitch, -89.9 * DEG, 89.9 * DEG);
    const cp = Math.cos(p);
    return out.set(-Math.sin(y) * cp, Math.sin(p), -Math.cos(y) * cp);
  }

  fireBullet(shooter, weapon) {
    const game = this.game;
    const origin = shooter.eyePos(this._o);
    const dir = this.aimDirection(shooter, weapon, this._d);

    game.audio.play('shot', {
      pos: origin,
      kind: weapon.silenced ? 'silenced' : weapon.type,
      volume: shooter === game.player ? 0.85 : 1,
      maxDist: weapon.type === 'sniper' ? 90 : 70,
    });
    game.notifyNoise(shooter, origin, weapon.silenced ? 22 : 45);

    if (shooter !== game.player) {
      const fwd = shooter.forwardVector(new THREE.Vector3());
      const muzzle = new THREE.Vector3(
        shooter.pos.x + fwd.x * 0.5,
        shooter.pos.y + shooter.eyeHeight() - 0.12 + fwd.y * 0.5,
        shooter.pos.z + fwd.z * 0.5,
      );
      game.effects.muzzleFlash(muzzle, fwd);
    }

    let ox = origin.x, oy = origin.y, oz = origin.z;
    const dx = dir.x, dy = dir.y, dz = dir.z;
    let damageScale = 1;
    let traveled = 0;
    const tracerStart = new THREE.Vector3(
      shooter === game.player ? origin.x + dir.x * 0.6 : ox,
      shooter === game.player ? origin.y + dir.y * 0.6 - 0.08 : oy,
      shooter === game.player ? origin.z + dir.z * 0.6 : oz,
    );
    let hitSomething = false;

    for (let pass = 0; pass <= MAX_PENETRATIONS; pass++) {
      const remaining = MAX_RANGE - traveled;
      if (remaining <= 0) break;
      const worldHit = raycastBoxes(ox, oy, oz, dx, dy, dz, remaining, game.world.colliders);
      const actorHit = this.traceActors(ox, oy, oz, dx, dy, dz, worldHit ? worldHit.t : remaining, shooter);

      if (actorHit) {
        const point = new THREE.Vector3(ox + dx * actorHit.t, oy + dy * actorHit.t, oz + dz * actorHit.t);
        const dist = traveled + actorHit.t;
        hitSomething = true;
        game.effects.tracer(tracerStart, point);
        game.effects.blood(point, new THREE.Vector3(-dx, 0.3, -dz).normalize());
        game.audio.play('impact', { pos: point, mat: 'flesh', volume: 0.9 });

        const victim = actorHit.actor;
        const friendly = victim.team === shooter.team;
        if (!friendly) {
          const base = weapon.damage * Math.pow(weapon.falloff, dist) * actorHit.mul * damageScale;
          const dealt = victim.takeDamage(base, actorHit.part, shooter, game);
          game.onDamage(victim, shooter, dealt, actorHit.part);
        }
        return;
      }

      if (!worldHit) break;

      const point = new THREE.Vector3(ox + dx * worldHit.t, oy + dy * worldHit.t, oz + dz * worldHit.t);
      const normal = new THREE.Vector3(worldHit.nx, worldHit.ny, worldHit.nz);
      const mat = worldHit.box.mat || 'wall';
      hitSomething = true;
      game.effects.tracer(tracerStart, point);
      game.effects.impact(point, normal, game.world.materialInfo[mat]?.sound || 'concrete');
      game.audio.play('impact', {
        pos: point,
        mat: game.world.materialInfo[mat]?.sound || 'concrete',
        volume: 0.8,
      });

      // Duvar delme denemesi
      if (pass === MAX_PENETRATIONS || weapon.penetration <= 0) return;
      const thickness = this.thicknessThrough(worldHit.box, ox, oy, oz, dx, dy, dz, worldHit.t, 1.2);
      const cost = thickness * (worldHit.box.pen ?? 1);
      const power = weapon.penetration * 1.4;
      if (!isFinite(cost) || cost > power) return;
      damageScale *= Math.max(0.25, 1 - cost / power) * 0.75;
      traveled += worldHit.t + thickness + 0.02;
      ox = ox + dx * (worldHit.t + thickness + 0.02);
      oy = oy + dy * (worldHit.t + thickness + 0.02);
      oz = oz + dz * (worldHit.t + thickness + 0.02);
    }

    if (!hitSomething) {
      const end = new THREE.Vector3(ox + dx * MAX_RANGE, oy + dy * MAX_RANGE, oz + dz * MAX_RANGE);
      game.effects.tracer(tracerStart, end);
    }
  }

  knifeAttack(attacker) {
    const game = this.game;
    const weapon = attacker.weapon();
    const origin = attacker.eyePos(this._o);
    const dir = attacker.forwardVector(this._d);
    game.audio.play('knife', { pos: origin, volume: 0.8 });

    const range = weapon.range || 1.6;
    const worldHit = raycastBoxes(origin.x, origin.y, origin.z, dir.x, dir.y, dir.z, range, game.world.colliders);
    const actorHit = this.traceActors(
      origin.x, origin.y, origin.z, dir.x, dir.y, dir.z,
      worldHit ? Math.min(worldHit.t, range) : range, attacker,
    );
    if (!actorHit) return;
    const victim = actorHit.actor;
    if (victim.team === attacker.team) return;

    // Arkadan vuruş kontrolü
    const toVictim = new THREE.Vector3(victim.pos.x - attacker.pos.x, 0, victim.pos.z - attacker.pos.z).normalize();
    const victimFwd = new THREE.Vector3(-Math.sin(victim.yaw), 0, -Math.cos(victim.yaw));
    const back = toVictim.dot(victimFwd) > 0.55;
    const base = back ? weapon.backstab : weapon.damage * actorHit.mul;
    const point = new THREE.Vector3(
      origin.x + dir.x * actorHit.t, origin.y + dir.y * actorHit.t, origin.z + dir.z * actorHit.t,
    );
    game.effects.blood(point, new THREE.Vector3(-dir.x, 0.3, -dir.z).normalize());
    const dealt = victim.takeDamage(base, back ? 'chest' : actorHit.part, attacker, game);
    game.onDamage(victim, attacker, dealt, back ? 'chest' : actorHit.part);
  }

  // Bot görüşü: kaynak aktörden hedefe engelsiz hat var mı?
  canSee(from, target) {
    const eye = from.eyePos(this._o);
    const points = [
      { x: target.pos.x, y: target.pos.y + target.height * 0.55, z: target.pos.z },
      { x: target.pos.x, y: target.pos.y + target.height - 0.2, z: target.pos.z },
      { x: target.pos.x, y: target.pos.y + 0.35, z: target.pos.z },
    ];
    for (const p of points) {
      const dx = p.x - eye.x;
      const dy = p.y - eye.y;
      const dz = p.z - eye.z;
      const len = Math.hypot(dx, dy, dz);
      if (len < 0.01) return true;
      const hit = raycastBoxes(eye.x, eye.y, eye.z, dx / len, dy / len, dz / len, len - 0.05, this.game.world.colliders);
      if (!hit) return true;
    }
    return false;
  }
}
