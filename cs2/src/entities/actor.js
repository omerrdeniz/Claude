// Oyuncu ve botların ortak tabanı: CS tarzı hareket fiziği, envanter, ateş durumu ve hitbox'lar.

import * as THREE from 'three';
import { PHYS, HITBOX } from '../config.js';
import { WEAPONS, cycleTime } from '../weapons.js';
import { clamp, damp, DEG } from '../core/math.js';

let nextActorId = 1;

export function emptyCommand() {
  return {
    forward: 0, side: 0, jump: false, crouch: false, walk: false,
    attack: false, attackPressed: false, reload: false, use: false,
    yaw: 0, pitch: 0,
  };
}

export class Actor {
  constructor(opts) {
    this.id = nextActorId++;
    this.name = opts.name || 'Oyuncu';
    this.team = opts.team;
    this.isBot = !!opts.isBot;
    this.skill = opts.skill ?? 0.6;

    this.pos = new THREE.Vector3(0, 0, 0);
    this.vel = new THREE.Vector3(0, 0, 0);
    this.yaw = 0;
    this.pitch = 0;
    this.height = PHYS.standHeight;
    this.crouching = false;
    this.onGround = false;
    this.wasOnGround = false;
    this.steppedUp = false;

    this.alive = true;
    this.health = 100;
    this.armor = 0;
    this.helmet = false;
    this.kit = false;
    this.money = 800;
    this.kills = 0;
    this.deaths = 0;
    this.assists = 0;
    this.score = 0;
    this.damageDealt = 0;

    this.inventory = { primary: null, secondary: null, melee: { id: 'knife' }, grenade: null };
    this.grenadeBag = [];      // taşınan el bombası kimlikleri (en fazla 3)
    this.slot = 'melee';
    this.nextFire = 0;
    this.reloading = false;
    this.reloadEnd = 0;
    this.deployEnd = 0;
    this.recoilIndex = 0;
    this.lastShot = -99;
    this.punchYaw = 0;
    this.punchPitch = 0;
    this.bloom = 0;
    this.zoomLevel = 0;

    this.hasBomb = false;
    this.plantProgress = 0;
    this.defuseProgress = 0;
    this.lastFootstep = 0;
    this.walkPhase = 0;
    this.deathTime = -99;
    this.lastAttacker = null;
    this.lastDamageTime = -99;
    this.blindUntil = 0;
    this.blindStrength = 0;
    this.nextBurnTick = 0;

    this.cmd = emptyCommand();
    this.model = null;
  }

  // --- Envanter -------------------------------------------------------
  weapon() {
    const entry = this.inventory[this.slot];
    return entry ? WEAPONS[entry.id] : WEAPONS.knife;
  }

  weaponState() {
    return this.inventory[this.slot];
  }

  giveWeapon(id, ammoFull = true) {
    const def = WEAPONS[id];
    if (!def) return null;
    const state = {
      id,
      ammo: def.mag > 0 ? def.mag : -1,
      reserve: def.reserve > 0 ? def.reserve : 0,
    };
    if (!ammoFull) { state.ammo = 0; state.reserve = 0; }
    const slot = def.slot === 'melee' ? 'melee' : def.slot;
    this.inventory[slot] = state;
    return state;
  }

  hasWeapon(id) {
    if (this.grenadeBag.includes(id)) return true;
    return Object.values(this.inventory).some((w) => w && w.id === id);
  }

  // El bombası çantasına ekler (aynı türden bir tane, toplam üç tane).
  giveGrenade(id) {
    if (this.grenadeBag.length >= 3 || this.grenadeBag.includes(id)) return false;
    this.grenadeBag.push(id);
    if (!this.inventory.grenade) this.inventory.grenade = { id, ammo: 1, reserve: 0 };
    return true;
  }

  // Çantadaki bir sonraki el bombasına geçer.
  cycleGrenade() {
    if (this.grenadeBag.length === 0) return false;
    const cur = this.inventory.grenade ? this.grenadeBag.indexOf(this.inventory.grenade.id) : -1;
    const next = this.grenadeBag[(cur + 1) % this.grenadeBag.length];
    this.inventory.grenade = { id: next, ammo: 1, reserve: 0 };
    return true;
  }

  switchSlot(slot, time) {
    if (slot === this.slot) return false;
    const entry = this.inventory[slot];
    if (!entry) return false;
    this.slot = slot;
    this.reloading = false;
    this.zoomLevel = 0;
    this.recoilIndex = 0;
    this.deployEnd = time + WEAPONS[entry.id].deployTime;
    this.nextFire = Math.max(this.nextFire, this.deployEnd);
    return true;
  }

  nextSlot(time, dir = 1) {
    const order = ['primary', 'secondary', 'melee', 'grenade'];
    const start = order.indexOf(this.slot);
    for (let i = 1; i <= order.length; i++) {
      const idx = (start + dir * i + order.length * 2) % order.length;
      if (this.inventory[order[idx]]) return this.switchSlot(order[idx], time);
    }
    return false;
  }

  dropAll() {
    this.inventory.primary = null;
    this.inventory.secondary = null;
    this.inventory.grenade = null;
    this.grenadeBag.length = 0;
    this.slot = 'melee';
  }

  speedMultiplier() {
    const w = this.weapon();
    const zoomMul = this.zoomLevel > 0 ? 0.45 : 1;
    return w.speedMul * zoomMul;
  }

  // --- Konum ve hitbox ------------------------------------------------
  eyeHeight() {
    return this.height - 0.18;
  }

  eyePos(out = new THREE.Vector3()) {
    return out.set(this.pos.x, this.pos.y + this.eyeHeight(), this.pos.z);
  }

  aimYaw() { return this.yaw + this.punchYaw; }
  aimPitch() { return clamp(this.pitch + this.punchPitch, -89 * DEG, 89 * DEG); }

  forwardVector(out = new THREE.Vector3(), usePunch = true) {
    const yaw = usePunch ? this.aimYaw() : this.yaw;
    const pitch = usePunch ? this.aimPitch() : this.pitch;
    const cp = Math.cos(pitch);
    return out.set(-Math.sin(yaw) * cp, Math.sin(pitch), -Math.cos(yaw) * cp);
  }

  hitboxes() {
    const h = this.height;
    const x = this.pos.x;
    const y = this.pos.y;
    const z = this.pos.z;
    const hw = 0.27;      // gövde yarı genişliği
    const hd = 0.18;      // gövde yarı derinliği
    const headSize = 0.15;
    const headY = y + h - 0.15;
    const chestTop = y + h - 0.30;
    const chestBottom = y + h - 0.62;
    const stomachBottom = y + h - 0.92;
    return [
      {
        part: 'head', mul: HITBOX.head,
        minX: x - headSize, maxX: x + headSize,
        minY: headY - headSize, maxY: headY + headSize,
        minZ: z - headSize, maxZ: z + headSize,
      },
      {
        part: 'chest', mul: HITBOX.chest,
        minX: x - hw, maxX: x + hw,
        minY: chestBottom, maxY: chestTop,
        minZ: z - hd, maxZ: z + hd,
      },
      {
        part: 'stomach', mul: HITBOX.stomach,
        minX: x - hw * 0.95, maxX: x + hw * 0.95,
        minY: stomachBottom, maxY: chestBottom,
        minZ: z - hd, maxZ: z + hd,
      },
      {
        part: 'legs', mul: HITBOX.legs,
        minX: x - hw * 0.9, maxX: x + hw * 0.9,
        minY: y, maxY: stomachBottom,
        minZ: z - hd * 0.9, maxZ: z + hd * 0.9,
      },
    ];
  }

  center(out = new THREE.Vector3()) {
    return out.set(this.pos.x, this.pos.y + this.height * 0.62, this.pos.z);
  }

  // --- Hasar ----------------------------------------------------------
  takeDamage(amount, part, attacker, game, armorPenOverride = null) {
    if (!this.alive) return 0;
    let dmg = amount;
    const armorWorks = this.armor > 0 && (part !== 'legs') && (part !== 'head' || this.helmet);
    if (armorWorks) {
      const weapon = attacker && attacker.weapon ? attacker.weapon() : null;
      const pen = armorPenOverride ?? (weapon ? weapon.armorPen : 0.7);
      const newDmg = dmg * pen;
      const armorLoss = Math.min(this.armor, (dmg - newDmg) * 0.5);
      this.armor = Math.max(0, this.armor - armorLoss);
      if (this.armor === 0) this.helmet = false;
      dmg = newDmg;
    }
    dmg = Math.round(dmg);
    this.health -= dmg;
    this.lastAttacker = attacker || null;
    this.lastDamageTime = game ? game.time : 0;
    if (this.health <= 0) {
      this.health = 0;
      this.die(attacker, part, game);
    }
    return dmg;
  }

  die(attacker, part, game) {
    if (!this.alive) return;
    this.alive = false;
    this.deaths++;
    this.deathTime = game ? game.time : 0;
    this.vel.set(0, 0, 0);
    this.zoomLevel = 0;
    if (game) game.onActorDeath(this, attacker, part);
  }

  respawn(spawn) {
    this.alive = true;
    this.health = 100;
    this.pos.set(spawn.x, 0.05, spawn.z);
    this.vel.set(0, 0, 0);
    this.yaw = spawn.yaw;
    this.pitch = 0;
    this.punchYaw = 0;
    this.punchPitch = 0;
    this.bloom = 0;
    this.height = PHYS.standHeight;
    this.crouching = false;
    this.reloading = false;
    this.recoilIndex = 0;
    this.plantProgress = 0;
    this.defuseProgress = 0;
    this.zoomLevel = 0;
    this.slot = this.inventory.primary ? 'primary' : (this.inventory.secondary ? 'secondary' : 'melee');
    this.deployEnd = 0;
    this.nextFire = 0;
    if (this.model) {
      this.model.visible = true;
      this.model.rotation.set(0, 0, 0);
    }
  }

  refillAmmo() {
    for (const slot of ['primary', 'secondary']) {
      const st = this.inventory[slot];
      if (!st) continue;
      const def = WEAPONS[st.id];
      st.ammo = def.mag;
      st.reserve = def.reserve;
    }
  }

  // --- Hareket --------------------------------------------------------
  playerBox(y = this.pos.y, h = this.height, r = PHYS.radius) {
    return {
      minX: this.pos.x - r, maxX: this.pos.x + r,
      minY: y + 0.002, maxY: y + h - 0.002,
      minZ: this.pos.z - r, maxZ: this.pos.z + r,
    };
  }

  overlapsWorld(world, y = this.pos.y, h = this.height) {
    const b = this.playerBox(y, h);
    const list = world.colliders;
    for (let i = 0; i < list.length; i++) {
      const o = list[i];
      if (b.minX < o.maxX && b.maxX > o.minX &&
          b.minY < o.maxY && b.maxY > o.minY &&
          b.minZ < o.maxZ && b.maxZ > o.minZ) return o;
    }
    return null;
  }

  groundBelow(world, maxDrop) {
    const r = PHYS.radius;
    const minX = this.pos.x - r;
    const maxX = this.pos.x + r;
    const minZ = this.pos.z - r;
    const maxZ = this.pos.z + r;
    let best = -Infinity;
    for (const o of world.colliders) {
      if (minX >= o.maxX || maxX <= o.minX || minZ >= o.maxZ || maxZ <= o.minZ) continue;
      if (o.maxY <= this.pos.y + 0.02 && o.maxY >= this.pos.y - maxDrop) {
        if (o.maxY > best) best = o.maxY;
      }
    }
    return best === -Infinity ? null : best;
  }

  moveAxis(world, axis, delta) {
    if (delta === 0) return;
    const old = this.pos[axis];
    this.pos[axis] = old + delta;
    if (!this.overlapsWorld(world)) return;

    // Basamak çıkma denemesi (kasa kenarı, eşik vb.)
    if (this.wasOnGround) {
      const oldY = this.pos.y;
      this.pos.y = oldY + PHYS.stepHeight;
      if (!this.overlapsWorld(world)) {
        this.steppedUp = true;
        return;
      }
      this.pos.y = oldY;
    }

    // Engellendi: duvara mümkün olduğunca yaklaş
    let lo = 0;
    let hi = delta;
    for (let i = 0; i < 4; i++) {
      const mid = (lo + hi) / 2;
      this.pos[axis] = old + mid;
      if (this.overlapsWorld(world)) hi = mid; else lo = mid;
    }
    this.pos[axis] = old + lo;
    this.vel[axis] = 0;
  }

  moveVertical(world, dy, game) {
    if (dy === 0) return;
    this.pos.y += dy;
    const hit = this.overlapsWorld(world);
    if (!hit) return;
    if (dy < 0) {
      // Zemine oturt
      let top = -Infinity;
      const b = this.playerBox();
      for (const o of world.colliders) {
        if (b.minX >= o.maxX || b.maxX <= o.minX || b.minZ >= o.maxZ || b.maxZ <= o.minZ) continue;
        if (o.maxY <= this.pos.y + this.height * 0.5 && o.maxY > top) top = o.maxY;
      }
      if (top > -Infinity) this.pos.y = top;
      this.land(game);
    } else {
      let bottom = Infinity;
      const b = this.playerBox();
      for (const o of world.colliders) {
        if (b.minX >= o.maxX || b.maxX <= o.minX || b.minZ >= o.maxZ || b.maxZ <= o.minZ) continue;
        if (o.minY >= this.pos.y && o.minY < bottom) bottom = o.minY;
      }
      if (bottom < Infinity) this.pos.y = bottom - this.height - 0.01;
      this.vel.y = 0;
    }
  }

  land(game) {
    const impact = -this.vel.y;
    this.vel.y = 0;
    this.onGround = true;
    if (impact > PHYS.fallSafeSpeed && this.alive) {
      const dmg = Math.round((impact - PHYS.fallSafeSpeed) * PHYS.fallDamageScale);
      if (dmg > 0) {
        this.takeDamage(dmg, 'legs', null, game);
        if (game) game.onFallDamage(this, dmg);
      }
    }
  }

  applyFriction(dt) {
    const speed = Math.hypot(this.vel.x, this.vel.z);
    if (speed < 0.02) { this.vel.x = 0; this.vel.z = 0; return; }
    const control = Math.max(speed, PHYS.stopSpeed);
    const drop = control * PHYS.friction * dt;
    const newSpeed = Math.max(0, speed - drop) / speed;
    this.vel.x *= newSpeed;
    this.vel.z *= newSpeed;
  }

  accelerate(wishX, wishZ, wishSpeed, accel, dt) {
    const current = this.vel.x * wishX + this.vel.z * wishZ;
    const add = wishSpeed - current;
    if (add <= 0) return;
    let accelSpeed = accel * wishSpeed * dt;
    if (accelSpeed > add) accelSpeed = add;
    this.vel.x += accelSpeed * wishX;
    this.vel.z += accelSpeed * wishZ;
  }

  updateMovement(dt, game) {
    const world = game.world;
    const cmd = this.cmd;
    this.wasOnGround = this.onGround;
    this.steppedUp = false;

    // Çömelme / kalkma
    const wantCrouch = cmd.crouch;
    if (wantCrouch) {
      this.crouching = true;
    } else if (this.crouching) {
      const savedHeight = this.height;
      this.height = PHYS.standHeight;
      if (this.overlapsWorld(world)) {
        this.height = savedHeight;   // üstte yer yok, çömelik kal
      } else {
        this.height = savedHeight;
        this.crouching = false;
      }
    }
    const targetHeight = this.crouching ? PHYS.crouchHeight : PHYS.standHeight;
    const prevHeight = this.height;
    this.height = damp(this.height, targetHeight, PHYS.crouchSpeedLerp * 2, dt);
    if (Math.abs(this.height - targetHeight) < 0.005) this.height = targetHeight;
    // Havadayken çömelince ayaklar yukarı çekilir (CS'teki crouch-jump).
    if (!this.onGround) {
      const delta = prevHeight - this.height;
      if (delta !== 0) {
        const oldY = this.pos.y;
        this.pos.y += delta;
        if (this.overlapsWorld(world)) this.pos.y = oldY;
      }
    }

    // İstenen yön (yaw'a göre)
    const sin = Math.sin(this.yaw);
    const cos = Math.cos(this.yaw);
    let wx = -sin * cmd.forward + cos * cmd.side;
    let wz = -cos * cmd.forward - sin * cmd.side;
    const wishLen = Math.hypot(wx, wz);
    if (wishLen > 1e-4) { wx /= wishLen; wz /= wishLen; } else { wx = 0; wz = 0; }

    let maxSpeed = PHYS.runSpeed * this.speedMultiplier();
    if (this.crouching) maxSpeed = PHYS.crouchSpeed * this.speedMultiplier();
    else if (cmd.walk) maxSpeed = Math.min(maxSpeed, PHYS.walkSpeed);
    const wishSpeed = Math.min(wishLen, 1) * maxSpeed;

    if (this.onGround) {
      this.applyFriction(dt);
      this.accelerate(wx, wz, wishSpeed, PHYS.accelerate, dt);
      if (cmd.jump && this.alive) {
        this.vel.y = PHYS.jumpSpeed;
        this.onGround = false;
        game.onJump(this);
      }
    } else {
      const airWish = Math.min(wishSpeed, PHYS.airWishSpeed);
      this.accelerate(wx, wz, airWish, PHYS.airAccelerate, dt);
      this.vel.y -= PHYS.gravity * dt;
      if (this.vel.y < -PHYS.maxFallSpeed) this.vel.y = -PHYS.maxFallSpeed;
    }

    // Adımlara bölerek hareket (tünelleme olmasın)
    const dist = Math.hypot(this.vel.x, this.vel.y, this.vel.z) * dt;
    const steps = Math.max(1, Math.min(8, Math.ceil(dist / 0.2)));
    const sdt = dt / steps;
    for (let i = 0; i < steps; i++) {
      this.moveAxis(world, 'x', this.vel.x * sdt);
      this.moveAxis(world, 'z', this.vel.z * sdt);
      this.onGround = false;
      this.moveVertical(world, this.vel.y * sdt, game);
    }

    // Yere yapış (basamak inişi / çıkışı)
    if (!this.onGround && this.vel.y <= 0 && (this.wasOnGround || this.steppedUp)) {
      const g = this.groundBelow(world, PHYS.stepHeight + 0.05);
      if (g !== null && this.pos.y - g < PHYS.stepHeight + 0.05) {
        this.pos.y = g;
        this.onGround = true;
        this.vel.y = 0;
      }
    }
    if (!this.onGround && this.vel.y <= 0) {
      const g = this.groundBelow(world, 0.06);
      if (g !== null) { this.pos.y = g; this.onGround = true; this.vel.y = 0; }
    }

    // Harita sınırları (güvenlik ağı)
    this.pos.x = clamp(this.pos.x, world.bounds.minX - 2, world.bounds.maxX + 2);
    this.pos.z = clamp(this.pos.z, world.bounds.minZ - 2, world.bounds.maxZ + 2);
    if (this.pos.y < -5) { this.pos.y = 0.2; this.vel.set(0, 0, 0); }

    // Ayak sesi
    const horizontal = Math.hypot(this.vel.x, this.vel.z);
    if (this.onGround && horizontal > 1.2 && !cmd.walk) {
      this.walkPhase += horizontal * dt * 1.7;
      if (this.walkPhase > Math.PI) {
        this.walkPhase -= Math.PI;
        game.onFootstep(this);
      }
    } else if (horizontal < 0.2) {
      this.walkPhase = 0;
    }
  }

  // --- Silah durumu ---------------------------------------------------
  currentInaccuracy() {
    const w = this.weapon();
    const s = w.spread;
    let value = s.stand;
    const speed = Math.hypot(this.vel.x, this.vel.z);
    const speedRatio = clamp(speed / PHYS.runSpeed, 0, 1);
    value += s.move * speedRatio * speedRatio;
    if (!this.onGround) value += s.air;
    if (this.crouching) value *= s.crouchMul;
    if (this.zoomLevel > 0) value *= 0.35;
    value += this.bloom;
    return value;
  }

  updateWeapon(dt, game) {
    const time = game.time;
    const w = this.weapon();
    const st = this.weaponState();

    // Geri tepme toparlanması
    const rec = w.recoilRecovery;
    this.punchPitch = damp(this.punchPitch, 0, rec, dt);
    this.punchYaw = damp(this.punchYaw, 0, rec, dt);
    this.bloom = Math.max(0, damp(this.bloom, 0, 6, dt));

    // Sprey sayacı sıfırlama
    if (time - this.lastShot > 0.45) this.recoilIndex = 0;

    if (this.reloading) {
      if (time >= this.reloadEnd) {
        this.reloading = false;
        if (st) {
          const def = WEAPONS[st.id];
          const need = def.mag - st.ammo;
          const take = Math.min(need, st.reserve);
          st.ammo += take;
          st.reserve -= take;
        }
      }
      return;
    }

    if (this.cmd.reload) this.startReload(game);

    const wantFire = w.auto ? this.cmd.attack : this.cmd.attackPressed;
    if (wantFire && this.canFire(game)) this.fire(game);
  }

  canFire(game) {
    const time = game.time;
    if (!this.alive || this.reloading) return false;
    if (time < this.nextFire || time < this.deployEnd) return false;
    const w = this.weapon();
    if (w.type === 'knife' || w.type === 'grenade') return true;
    const st = this.weaponState();
    return !!st && st.ammo > 0;
  }

  fire(game) {
    const w = this.weapon();
    const st = this.weaponState();
    const time = game.time;
    this.nextFire = time + cycleTime(w);
    this.lastShot = time;

    if (w.type === 'grenade') {
      const id = this.inventory.grenade ? this.inventory.grenade.id : 'he';
      game.grenades.throwFrom(this, id);
      const at = this.grenadeBag.indexOf(id);
      if (at >= 0) this.grenadeBag.splice(at, 1);
      this.inventory.grenade = this.grenadeBag.length
        ? { id: this.grenadeBag[0], ammo: 1, reserve: 0 }
        : null;
      if (!this.inventory.grenade) this.nextSlot(time, -1);
      else this.deployEnd = time + 0.5;
      return;
    }

    if (w.type === 'knife') {
      game.combat.knifeAttack(this);
      return;
    }

    st.ammo--;
    this.applyRecoil(w);
    game.combat.fireBullet(this, w);
    if (st.ammo === 0) this.startReload(game);
  }

  applyRecoil(w) {
    const pattern = w.pattern;
    const idx = Math.min(this.recoilIndex, (pattern ? pattern.length : 1) - 1);
    const step = pattern ? pattern[idx] : [0, 1.4];
    const scale = w.recoilScale * (this.crouching ? 0.8 : 1);
    this.punchPitch += step[1] * DEG * scale;
    this.punchYaw += step[0] * DEG * scale;
    this.bloom = Math.min(w.spread.bloomMax, this.bloom + w.spread.bloom);
    this.recoilIndex++;
    if (this.zoomLevel > 0 && (w.type === 'sniper')) this.zoomLevel = 0;
  }

  startReload(game) {
    const w = this.weapon();
    const st = this.weaponState();
    if (!st || w.mag <= 0) return false;
    if (this.reloading || st.ammo >= w.mag || st.reserve <= 0) return false;
    if (game.time < this.deployEnd) return false;
    this.reloading = true;
    this.reloadEnd = game.time + w.reloadTime;
    this.zoomLevel = 0;
    this.recoilIndex = 0;
    game.onReload(this);
    return true;
  }

  update(dt, game) {
    if (!this.alive) return;
    this.updateMovement(dt, game);
    this.updateWeapon(dt, game);
  }
}

// Karakter modeli ve animasyonu character.js'te üretilir.
export { createCharacter as createActorModel, updateCharacter as updateActorModel } from './character.js';
