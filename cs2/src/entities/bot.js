// Bot yapay zekası: algı, nişan alma, ateş disiplini, yol takibi ve tur hedefleri.

import * as THREE from 'three';
import { Actor } from './actor.js';
import { clamp, damp, randRange, angleDiff, DEG, gauss } from '../core/math.js';
import { walkClear } from '../world/nav.js';

const SKILL_LEVELS = [0.32, 0.55, 0.76, 0.93];

export class Bot extends Actor {
  constructor(opts) {
    super({ ...opts, isBot: true });
    this.skill = SKILL_LEVELS[clamp(opts.difficulty ?? 2, 0, 3)];
    this.target = null;
    this.targetVisible = false;
    this.firstSeen = -99;
    this.lastSeenTime = -99;
    this.lastSeenPos = new THREE.Vector3();
    this.heardPos = null;
    this.heardTime = -99;

    this.path = null;
    this.pathIndex = 0;
    this.goalNode = -1;
    this.goalPos = new THREE.Vector3();
    this.repathAt = 0;
    this.perceptionAt = 0;
    this.strafeDir = 0;
    this.strafeUntil = 0;
    this.pauseFireUntil = 0;
    this.burstLength = 4;
    this.aimError = new THREE.Vector3();
    this.aimErrorAt = 0;
    this.stuckPos = new THREE.Vector3();
    this.stuckCheckAt = 0;
    this.jumpUntil = 0;
    this.assignedSite = 'A';
    this.role = 'attack';
    this.holdPos = null;
    this.wanderAt = 0;
  }

  reactionTime() {
    return 0.42 - this.skill * 0.30 + Math.random() * 0.08;
  }

  aimSpeed() {
    return 5.5 + this.skill * 9;
  }

  // --- Algı -----------------------------------------------------------
  perceive(game) {
    // Flaşlanmışsa hiçbir şey göremez
    if (game.time < this.blindUntil) {
      this.targetVisible = false;
      return;
    }
    const enemies = game.actors.filter((a) => a.alive && a.team !== this.team);
    let best = null;
    let bestScore = Infinity;
    const eye = this.eyePos(new THREE.Vector3());
    const fwd = this.forwardVector(new THREE.Vector3(), false);
    for (const e of enemies) {
      const dx = e.pos.x - this.pos.x;
      const dz = e.pos.z - this.pos.z;
      const dist = Math.hypot(dx, dz);
      if (dist > 70) continue;
      const dot = (dx * fwd.x + dz * fwd.z) / (dist || 1);
      const fov = dist < 4 ? -0.5 : -0.15;   // yakında neredeyse çepeçevre farkındalık
      if (dot < fov) continue;
      if (!game.combat.canSee(this, e)) continue;
      const score = dist * (1 - dot * 0.35);
      if (score < bestScore) { bestScore = score; best = e; }
    }

    if (best) {
      if (this.target !== best || game.time - this.lastSeenTime > 1.2) {
        this.firstSeen = game.time + this.reactionTime();
        this.aimError.set(gauss(), gauss() * 0.5, gauss()).multiplyScalar((1 - this.skill) * 0.55);
      }
      this.target = best;
      this.targetVisible = true;
      this.lastSeenTime = game.time;
      this.lastSeenPos.copy(best.pos);
    } else {
      this.targetVisible = false;
      if (this.target && (!this.target.alive || game.time - this.lastSeenTime > 6)) this.target = null;
    }
    void eye;
  }

  hearNoise(pos, strength, game) {
    const dist = Math.hypot(pos.x - this.pos.x, pos.z - this.pos.z);
    if (dist > strength) return;
    if (game.time - this.lastSeenTime < 1.5) return;
    this.heardPos = new THREE.Vector3(pos.x, pos.y, pos.z);
    this.heardTime = game.time;
  }

  // --- Yol bulma ------------------------------------------------------
  setGoal(x, z, game, force = false) {
    const nav = game.nav;
    const node = nav.nearest(x, z);
    if (node === this.goalNode && !force && this.path) return;
    this.goalNode = node;
    this.goalPos.set(x, 0, z);
    this.repath(game);
  }

  repath(game) {
    const nav = game.nav;
    const start = nav.nearest(this.pos.x, this.pos.z, true, this.pos.y);
    const rest = nav.path(start, this.goalNode);
    // Başlangıç düğümü de yola dahil edilir: bot yolun üstünde olmayabilir,
    // önce ulaşabildiği düğüme gider, sonra kenarları takip eder.
    this.path = start >= 0 ? [start, ...(rest || [])] : [];
    this.pathIndex = 0;
    this._steer = null;
    this.repathAt = game.time + 1.5 + Math.random();
  }

  // Yol üzerindeki hedef noktayı verir.
  steerPoint(game) {
    const nav = game.nav;
    // Yol hesabı pahalı: kısa süre önbelleğe al
    if (this._steer && game.time < this._steerAt) {
      const d = Math.hypot(this._steer.x - this.pos.x, this._steer.z - this.pos.z);
      if (d > 1.4) return this._steer;
    }
    if (!this.path || this.pathIndex >= this.path.length) {
      const res = { x: this.goalPos.x, z: this.goalPos.z, final: true };
      this._steer = res;
      this._steerAt = game.time + 0.25;
      return res;
    }
    // Görünen en ileri düğüme kestirme yap
    let idx = this.pathIndex;
    let clear = false;
    for (let i = Math.min(this.path.length - 1, this.pathIndex + 3); i >= this.pathIndex; i--) {
      const n = nav.nodes[this.path[i]];
      if (walkClear(this.pos.x, this.pos.z, n.x, n.z, game.world.navColliders, this.pos.y)) { idx = i; clear = true; break; }
    }
    this.pathIndex = idx;
    // Hiçbir düğüme doğrudan gidemiyorsak yol bayatlamıştır: yeniden hesapla.
    if (!clear && game.time > (this._forceRepathAt || 0)) {
      this._forceRepathAt = game.time + 0.7;
      this.repath(game);
      idx = 0;
      if (!this.path.length || nav.nodes[this.path[0]] === undefined) {
        const res = { x: this.goalPos.x, z: this.goalPos.z, final: true };
        this._steer = res;
        this._steerAt = game.time + 0.25;
        return res;
      }
    }
    const node = nav.nodes[this.path[idx]];
    const d = Math.hypot(node.x - this.pos.x, node.z - this.pos.z);
    let res;
    if (d < 1.6) {
      this.pathIndex++;
      if (this.pathIndex >= this.path.length) {
        res = { x: this.goalPos.x, z: this.goalPos.z, final: true };
      } else {
        const nx = nav.nodes[this.path[this.pathIndex]];
        res = { x: nx.x, z: nx.z, final: false };
      }
    } else {
      res = { x: node.x, z: node.z, final: false };
    }
    this._steer = res;
    this._steerAt = game.time + 0.25;
    return res;
  }

  moveToward(x, z, speedMode = 'run') {
    const dx = x - this.pos.x;
    const dz = z - this.pos.z;
    const len = Math.hypot(dx, dz);
    if (len < 0.15) { this.cmd.forward = 0; this.cmd.side = 0; return 0; }
    const wx = dx / len;
    const wz = dz / len;
    const sin = Math.sin(this.yaw);
    const cos = Math.cos(this.yaw);
    this.cmd.forward = -sin * wx - cos * wz;
    this.cmd.side = cos * wx - sin * wz;
    this.cmd.walk = speedMode === 'walk';
    return len;
  }

  faceDirection(x, z, dt, speedMul = 1) {
    const desired = Math.atan2(-(x - this.pos.x), -(z - this.pos.z));
    const diff = angleDiff(desired, this.yaw);
    this.yaw += clamp(diff, -this.aimSpeed() * speedMul * dt, this.aimSpeed() * speedMul * dt);
    this.pitch += clamp(-this.pitch, -2 * dt, 2 * dt);
  }

  // --- Savaş ----------------------------------------------------------
  aimAt(target, dt, game) {
    const eye = this.eyePos(new THREE.Vector3());
    // Hedefin göğsüne nişan al, düşük yetenekte hata payı ekle
    if (game.time - this.aimErrorAt > 0.35) {
      this.aimErrorAt = game.time;
      const decay = this.targetVisible ? clamp((game.time - this.lastSeenTime + 0.4) * 2, 0.3, 1) : 1;
      this.aimError.set(gauss(), gauss() * 0.45, gauss())
        .multiplyScalar((1 - this.skill) * 0.5 * decay);
    }
    const lead = this.skill * 0.09;
    const px = target.pos.x + target.vel.x * lead + this.aimError.x;
    const py = target.pos.y + target.height * (this.skill > 0.7 ? 0.82 : 0.6) + this.aimError.y;
    const pz = target.pos.z + target.vel.z * lead + this.aimError.z;

    const dx = px - eye.x;
    const dy = py - eye.y;
    const dz = pz - eye.z;
    const distXZ = Math.hypot(dx, dz);
    const desiredYaw = Math.atan2(-dx, -dz);
    const desiredPitch = Math.atan2(dy, distXZ);

    const rate = this.aimSpeed() * dt;
    const dYaw = angleDiff(desiredYaw, this.yaw);
    const dPitch = desiredPitch - this.pitch;
    this.yaw += clamp(dYaw, -rate, rate);
    this.pitch += clamp(dPitch, -rate, rate);
    this.pitch = clamp(this.pitch, -80 * DEG, 80 * DEG);
    return Math.hypot(dYaw, dPitch);
  }

  friendlyInLine(game) {
    const eye = this.eyePos(new THREE.Vector3());
    const dir = this.forwardVector(new THREE.Vector3());
    const hit = game.combat.traceActors(eye.x, eye.y, eye.z, dir.x, dir.y, dir.z, 60, this);
    return !!hit && hit.actor.team === this.team;
  }

  combatBehaviour(dt, game) {
    const target = this.target;
    const dist = Math.hypot(target.pos.x - this.pos.x, target.pos.z - this.pos.z);
    const error = this.aimAt(target, dt, game);

    // El bombası atma anı
    if (this.slot === 'grenade' && this.nadeTarget) {
      this.cmd.forward = 0;
      this.cmd.side = 0;
      this.faceDirection(this.nadeTarget.x, this.nadeTarget.z, dt, 1.2);
      this.pitch = damp(this.pitch, -0.22, 6, dt);
      if (game.time >= (this.nadeUntil || 0)) {
        this.cmd.attack = true;
        this.cmd.attackPressed = true;
        this.nadeTarget = null;
        this.nadeUntil = 0;
      }
      return;
    }
    if (this.tryGrenade(game, target, dist)) return;

    const weapon = this.weapon();

    // Silah seçimi: uzun menzilde ana silah, cephane bitince tabanca
    this.pickWeapon(game);

    // Hareket: yakında saldır, uzakta dur ve nişan al
    const wantHold = dist < 32 && this.skill > 0.4;
    if (game.time > this.strafeUntil) {
      this.strafeUntil = game.time + randRange(0.4, 1.1);
      this.strafeDir = Math.random() < 0.5 ? -1 : (Math.random() < 0.5 ? 1 : 0);
    }
    if (dist > 14 && !this.targetVisible) {
      const p = this.steerPoint(game);
      this.moveToward(p.x, p.z);
    } else if (wantHold && this.targetVisible) {
      // Ateş ederken dur (isabet için), aralarda yan adım at
      const strafing = this.strafeDir !== 0 && (game.time - this.lastShot > 0.35);
      this.cmd.forward = dist > 12 ? 0.35 : (dist < 4 ? -0.6 : 0);
      this.cmd.side = strafing ? this.strafeDir * 0.9 : 0;
      this.cmd.walk = !strafing;
    } else {
      this.moveToward(target.pos.x, target.pos.z);
    }
    this.cmd.crouch = this.targetVisible && dist > 8 && dist < 30 && this.skill > 0.6 && Math.sin(game.time * 0.7 + this.id) > 0.55;

    // Ateş kararı
    const ready = game.time > this.firstSeen && this.targetVisible && !this.reloading
      && game.time > this.blindUntil;
    const errorLimit = (weapon.type === 'sniper' ? 1.2 : 2.6 + dist * 0.05) * DEG;
    const canShoot = ready && error < errorLimit && game.time > this.pauseFireUntil && !this.friendlyInLine(game);

    if (canShoot) {
      const st = this.weaponState();
      if (weapon.type === 'knife' || (st && st.ammo > 0)) {
        this.cmd.attack = true;
        this.cmd.attackPressed = true;
        // Seri (burst) kontrolü
        if (weapon.auto && this.recoilIndex >= this.burstLength) {
          this.pauseFireUntil = game.time + randRange(0.18, 0.42) * (1.4 - this.skill);
          this.burstLength = Math.round(randRange(3, 3 + this.skill * 7));
          this.recoilIndex = 0;
        }
      }
    }

    // Şarjör yönetimi
    const st = this.weaponState();
    if (st && st.ammo === 0 && !this.reloading) this.cmd.reload = true;
    else if (st && !this.targetVisible && st.ammo < WEAPON_LOW(weapon) && st.reserve > 0) this.cmd.reload = true;
  }

  // El bombası atma denemesi (yalnız HE, uzak mesafede)
  tryGrenade(game, target, dist) {
    if (this.skill < 0.5) return false;
    if (game.time < (this.nadeCooldown || 0)) return false;
    if (!this.grenadeBag.includes('he')) return false;
    if (dist < 11 || dist > 30) return false;
    if (this.friendlyInLine(game)) return false;
    this.nadeCooldown = game.time + 18 + Math.random() * 12;
    this.inventory.grenade = { id: 'he', ammo: 1, reserve: 0 };
    this.switchSlot('grenade', game.time);
    this.nadeUntil = game.time + 0.75;
    this.nadeTarget = { x: target.pos.x, z: target.pos.z };
    return true;
  }

  pickWeapon(game) {
    // Atış hazırlığı sürerken silah değiştirme
    if (this.slot === 'grenade' && game.time < (this.nadeUntil || 0)) return;
    const cur = this.weaponState();
    const primary = this.inventory.primary;
    const secondary = this.inventory.secondary;
    const hasAmmo = (s) => s && (s.ammo > 0 || s.reserve > 0);
    if (this.slot === 'grenade') {
      this.switchSlot(primary ? 'primary' : (secondary ? 'secondary' : 'melee'), game.time);
      return;
    }
    if (hasAmmo(primary)) {
      if (this.slot !== 'primary') this.switchSlot('primary', game.time);
    } else if (hasAmmo(secondary)) {
      if (this.slot !== 'secondary') this.switchSlot('secondary', game.time);
    } else if (this.slot !== 'melee' && !hasAmmo(cur)) {
      this.switchSlot('melee', game.time);
    }
  }

  // --- Hedefler -------------------------------------------------------
  objectiveBehaviour(dt, game) {
    const round = game.round;
    this.pickWeapon(game);

    let goal = null;
    let mode = 'run';

    if (this.team === 'T') {
      if (round.bombPlanted) {
        // Bombayı koru: bombanın yakınında bir noktada bekle
        const b = round.bombPos;
        goal = this.holdSpot(game, b.x, b.z, 9);
      } else if (this.hasBomb) {
        const site = game.world.sites[round.targetSite];
        goal = { x: site.center.x, z: site.center.z };
        const inSite = game.world.siteAt(this.pos.x, this.pos.z);
        if (inSite && Math.hypot(this.pos.x - site.center.x, this.pos.z - site.center.z) < 6) {
          this.cmd.use = true;   // bomba kur
          this.cmd.forward = 0;
          this.cmd.side = 0;
          this.faceDirection(site.center.x, site.center.z + 2, dt);
          return;
        }
      } else {
        const site = game.world.sites[round.targetSite];
        goal = this.holdSpot(game, site.center.x, site.center.z, 8);
      }
    } else {
      if (round.bombPlanted) {
        const b = round.bombPos;
        const dist = Math.hypot(this.pos.x - b.x, this.pos.z - b.z);
        goal = { x: b.x, z: b.z };
        if (dist < 1.6) {
          // İmha et
          const enemiesNear = game.actors.some((a) => a.alive && a.team === 'T'
            && Math.hypot(a.pos.x - this.pos.x, a.pos.z - this.pos.z) < 12 && game.combat.canSee(this, a));
          if (!enemiesNear || round.bombTimer < 8) {
            this.cmd.use = true;
            this.cmd.forward = 0;
            this.cmd.side = 0;
            this.cmd.crouch = true;
            this.faceDirection(b.x, b.z, dt);
            return;
          }
        }
      } else if (game.time - this.heardTime < 6 && this.heardPos) {
        goal = { x: this.heardPos.x, z: this.heardPos.z };
        mode = 'walk';
      } else {
        const site = game.world.sites[this.assignedSite];
        goal = this.holdSpot(game, site.center.x, site.center.z, 7);
        mode = 'walk';
      }
    }

    // Son görülen düşmana doğru arama
    if (this.target && game.time - this.lastSeenTime < 4 && !round.bombPlanted) {
      goal = { x: this.lastSeenPos.x, z: this.lastSeenPos.z };
    }

    if (goal) {
      this.setGoal(goal.x, goal.z, game);
      if (game.time > this.repathAt) this.repath(game);
      // Sıkışma kurtarma: kısa süreliğine yol grafını yok say
      const p = game.time < (this.directUntil || 0)
        ? { x: goal.x, z: goal.z, final: true }
        : this.steerPoint(game);
      const dist = this.moveToward(p.x, p.z, mode);
      if (dist < 0.8 && p.final) { this.cmd.forward = 0; this.cmd.side = 0; }
      const lookX = p.x + (p.x - this.pos.x);
      const lookZ = p.z + (p.z - this.pos.z);
      this.faceDirection(lookX, lookZ, dt, 0.6);
    }
  }

  // Hedef çevresinde bota özel sabit bir bekleme noktası üretir.
  holdSpot(game, cx, cz, radius) {
    if (!this.holdPos || this.holdCenterX !== cx || this.holdCenterZ !== cz) {
      const angle = (this.id * 2.399) % (Math.PI * 2);
      const r = radius * (0.35 + ((this.id * 37) % 100) / 150);
      this.holdCenterX = cx;
      this.holdCenterZ = cz;
      this.holdPos = { x: cx + Math.cos(angle) * r, z: cz + Math.sin(angle) * r };
    }
    return this.holdPos;
  }

  checkStuck(game) {
    if (game.time < this.stuckCheckAt) return;
    this.stuckCheckAt = game.time + 0.6;
    const moved = Math.hypot(this.pos.x - this.stuckPos.x, this.pos.z - this.stuckPos.z);
    const wantsMove = Math.abs(this.cmd.forward) + Math.abs(this.cmd.side) > 0.2;
    if (wantsMove && moved < 0.25) {
      this.stuckCount = (this.stuckCount || 0) + 1;
      this.jumpUntil = game.time + 0.25;
      this.strafeUntil = game.time + 0.7;
      this.strafeDir = Math.random() < 0.5 ? -1 : 1;
      this.unstuckUntil = game.time + 0.6;
      this._steer = null;
      this.repath(game);
      // Israrla sıkışıyorsa yol grafını bırak, doğrudan hedefe yönel
      if (this.stuckCount > 2) {
        this.directUntil = game.time + 2.5;
      }
      if (this.stuckCount > 4) {
        this.stuckCount = 0;
        this.goalNode = -1;
        this.holdPos = null;
      }
    } else {
      this.stuckCount = 0;
    }
    this.stuckPos.copy(this.pos);
  }

  think(dt, game) {
    const cmd = this.cmd;
    cmd.forward = 0; cmd.side = 0; cmd.jump = false; cmd.crouch = false;
    cmd.walk = false; cmd.attack = false; cmd.attackPressed = false;
    cmd.reload = false; cmd.use = false;

    if (!this.alive) return;

    // Ateşin içindeyse hemen dışarı kaç
    const fire = game.grenades.fireAt(this.pos.x, this.pos.z);
    if (fire) {
      const away = Math.atan2(this.pos.x - fire.pos.x, this.pos.z - fire.pos.z);
      const tx = fire.pos.x + Math.sin(away) * (fire.radius + 2.5);
      const tz = fire.pos.z + Math.cos(away) * (fire.radius + 2.5);
      this.moveToward(tx, tz);
      cmd.walk = false;
      this.faceDirection(tx, tz, dt, 0.8);
      this.checkStuck(game);
      return;
    }

    if (game.round.frozen) {
      // Donma süresinde sadece etrafa bak
      this.yaw += Math.sin(game.time * 0.6 + this.id) * dt * 0.4;
      return;
    }

    if (game.time > this.perceptionAt) {
      this.perceptionAt = game.time + 0.08 + Math.random() * 0.05;
      this.perceive(game);
    }

    if (this.target && this.targetVisible && this.target.alive) {
      this.combatBehaviour(dt, game);
    } else {
      this.objectiveBehaviour(dt, game);
    }

    this.checkStuck(game);
    if (game.time < this.jumpUntil) cmd.jump = true;
    if (game.time < (this.unstuckUntil || 0)) {
      // Duvara sıkışmayı kırmak için yana bas
      cmd.side = this.strafeDir * 0.9;
      cmd.walk = false;
    }
    if (this.strafeDir !== 0 && game.time < this.strafeUntil && Math.abs(cmd.side) < 0.1 && this.targetVisible) {
      cmd.side = this.strafeDir * 0.6;
    }
  }
}

function WEAPON_LOW(weapon) {
  return Math.max(2, Math.floor(weapon.mag * 0.25));
}
