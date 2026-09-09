// Tur akışı: donma süresi, canlı tur, bomba kurma/imha, ekonomi, skor ve devre arası.

import * as THREE from 'three';
import { ROUND, ECONOMY, TEAM } from '../config.js';
import { WEAPONS, KEVLAR_PRICE, HELMET_PRICE, DEFUSE_KIT_PRICE } from '../weapons.js';
import { clamp, pick } from '../core/math.js';

export const STATE = { FREEZE: 'freeze', LIVE: 'live', ENDED: 'ended', MATCH_END: 'matchend' };

export class Round {
  constructor(game) {
    this.game = game;
    this.number = 0;
    this.state = STATE.FREEZE;
    this.timer = ROUND.freezeTime;
    this.scores = { CT: 0, T: 0 };
    this.lossStreak = { CT: 0, T: 0 };
    this.targetSite = 'A';
    this.bombPlanted = false;
    this.bombTimer = 0;
    this.bombPos = new THREE.Vector3();
    this.bombCarrier = null;
    this.bombMesh = null;
    this.defuser = null;
    this.lastBeep = 0;
    this.winner = null;
    this.winReason = '';
    this.switchedSides = false;
    this.matchOver = false;
  }

  get frozen() { return this.state === STATE.FREEZE; }
  get buyTimeLeft() {
    if (this.state === STATE.FREEZE) return this.timer + 8;
    if (this.state === STATE.LIVE) return Math.max(0, 8 - (ROUND.roundTime - this.timer));
    return 0;
  }
  get canBuy() { return this.buyTimeLeft > 0; }

  // --- Tur başlangıcı -------------------------------------------------
  startRound() {
    const game = this.game;
    this.number++;
    this.state = STATE.FREEZE;
    this.timer = ROUND.freezeTime;
    this.bombPlanted = false;
    this.bombTimer = 0;
    this.defuser = null;
    this.winner = null;
    this.winReason = '';
    this.removeBombMesh();
    game.grenades.clear();

    this.targetSite = Math.random() < 0.5 ? 'A' : 'B';

    const spawns = { CT: [...game.world.spawns.CT], T: [...game.world.spawns.T] };
    const used = { CT: 0, T: 0 };

    for (const actor of game.actors) {
      const survived = actor.alive;
      const spawnList = spawns[actor.team];
      const spawn = spawnList[used[actor.team] % spawnList.length];
      used[actor.team]++;
      actor.respawn(spawn);
      actor.hasBomb = false;
      actor.kit = actor.team === 'CT' ? actor.kit : false;
      if (!survived) {
        actor.dropAll();
        actor.armor = 0;
        actor.helmet = false;
        actor.kit = false;
      }
      // Varsayılan tabanca ve bıçak
      if (!actor.inventory.secondary) {
        actor.giveWeapon(actor.team === 'CT' ? 'usp' : 'glock');
      }
      actor.refillAmmo();
      actor.slot = actor.inventory.primary ? 'primary' : 'secondary';
      actor.deployEnd = 0;
      if (actor.isBot) this.assignBotRole(actor);
    }

    // Bombayı bir teröriste ver
    const ts = game.actors.filter((a) => a.team === 'T');
    if (ts.length) {
      const carrier = pick(ts);
      carrier.hasBomb = true;
      this.bombCarrier = carrier;
      if (carrier.isBot) carrier.assignedSite = this.targetSite;
    }

    // Botlar alışverişini yapsın
    for (const actor of game.actors) {
      if (actor.isBot) this.botBuy(actor);
    }

    game.onRoundStart();
  }

  assignBotRole(bot) {
    const game = this.game;
    if (bot.team === 'CT') {
      const cts = game.actors.filter((a) => a.team === 'CT');
      const idx = cts.indexOf(bot);
      bot.assignedSite = idx % 2 === 0 ? 'A' : 'B';
    } else {
      bot.assignedSite = this.targetSite;
    }
    bot.holdPos = null;
    bot.target = null;
    bot.path = null;
    bot.goalNode = -1;
    bot.heardPos = null;
  }

  botBuy(bot) {
    const money = bot.money;
    const team = bot.team;
    const buy = (id) => {
      const def = WEAPONS[id];
      if (!def || bot.money < def.price) return false;
      bot.money -= def.price;
      bot.giveWeapon(id);
      return true;
    };
    // Zırh önce
    if (!bot.inventory.primary) {
      if (money >= 4000) {
        if (Math.random() < 0.18) buy('awp');
        else buy(team === 'CT' ? 'm4a4' : 'ak47');
      } else if (money >= 2700) {
        buy(team === 'CT' ? 'famas' : 'ak47');
      } else if (money >= 2000) {
        buy(team === 'CT' ? 'famas' : 'galil');
      } else if (money >= 1300) {
        buy(team === 'CT' ? 'mp9' : 'mac10');
      } else if (money >= 700 && Math.random() < 0.5) {
        buy('deagle');
      }
    }
    if (bot.armor <= 0 && bot.money >= HELMET_PRICE && bot.inventory.primary) {
      bot.money -= HELMET_PRICE;
      bot.armor = 100;
      bot.helmet = true;
    } else if (bot.armor <= 0 && bot.money >= KEVLAR_PRICE) {
      bot.money -= KEVLAR_PRICE;
      bot.armor = 100;
    }
    // El bombaları
    const nadeOptions = [['he', 300, 0.55], ['flash', 200, 0.35], ['smoke', 300, 0.3]];
    for (const [id, price, chance] of nadeOptions) {
      if (bot.money >= price + 700 && Math.random() < chance) {
        if (bot.giveGrenade(id)) bot.money -= price;
      }
    }
    if (team === 'CT' && !bot.kit && bot.money >= DEFUSE_KIT_PRICE && Math.random() < 0.5) {
      bot.money -= DEFUSE_KIT_PRICE;
      bot.kit = true;
    }
    bot.refillAmmo();
    bot.slot = bot.inventory.primary ? 'primary' : 'secondary';
  }

  // --- Bomba ----------------------------------------------------------
  createBombMesh(pos) {
    const game = this.game;
    const group = new THREE.Group();
    const body = new THREE.Mesh(
      new THREE.BoxGeometry(0.34, 0.18, 0.24),
      new THREE.MeshLambertMaterial({ color: 0x2a2a2a }),
    );
    body.castShadow = true;
    const light = new THREE.Mesh(
      new THREE.BoxGeometry(0.07, 0.05, 0.05),
      new THREE.MeshBasicMaterial({ color: 0xff2222 }),
    );
    light.position.set(0, 0.12, 0);
    group.add(body, light);
    group.position.copy(pos);
    group.position.y += 0.09;
    game.scene.add(group);
    this.bombMesh = group;
    this.bombLight = light;
  }

  removeBombMesh() {
    if (this.bombMesh) {
      this.game.scene.remove(this.bombMesh);
      this.bombMesh = null;
      this.bombLight = null;
    }
  }

  plantBomb(actor) {
    const game = this.game;
    this.bombPlanted = true;
    this.bombTimer = ROUND.bombTime;
    this.bombPos.set(actor.pos.x, actor.pos.y, actor.pos.z);
    actor.hasBomb = false;
    actor.plantProgress = 0;
    this.bombCarrier = null;
    this.createBombMesh(this.bombPos);
    actor.money = Math.min(ECONOMY.max, actor.money + ECONOMY.plantBonus);
    actor.score += 2;
    this.timer = Math.max(this.timer, 0);
    game.onBombPlanted(actor);
  }

  defuseBomb(actor) {
    const game = this.game;
    this.bombPlanted = false;
    actor.money = Math.min(ECONOMY.max, actor.money + ECONOMY.defuseBonus);
    actor.score += 2;
    this.removeBombMesh();
    game.onBombDefused(actor);
    this.endRound(TEAM.CT, 'Bomba imha edildi');
  }

  explodeBomb() {
    const game = this.game;
    game.effects.explosion(this.bombPos);
    game.audio.play('explosion', { pos: this.bombPos, volume: 1.2, maxDist: 200 });
    game.shake(1.4);
    for (const a of game.actors) {
      if (!a.alive) continue;
      const d = a.pos.distanceTo(this.bombPos);
      if (d > 22) continue;
      const dmg = 500 * Math.max(0, 1 - d / 22) ** 1.4;
      a.takeDamage(dmg, 'chest', null, game, 0.6);
    }
    this.bombPlanted = false;
    this.removeBombMesh();
    this.endRound(TEAM.T, 'Bomba patladı');
  }

  // --- Kullanma tuşu (E) ile kurma/imha -------------------------------
  updateUse(dt) {
    const game = this.game;
    for (const actor of game.actors) {
      if (!actor.alive) continue;
      const holding = actor.cmd.use;
      const moving = Math.hypot(actor.vel.x, actor.vel.z) > 1.2;

      if (actor.team === 'T' && actor.hasBomb && !this.bombPlanted) {
        const site = game.world.siteAt(actor.pos.x, actor.pos.z);
        if (holding && site && actor.onGround && !moving && this.state === STATE.LIVE) {
          actor.plantProgress += dt;
          if (actor.plantProgress === dt) game.onPlantStart(actor);
          if (actor.plantProgress >= ROUND.plantTime) this.plantBomb(actor);
        } else if (actor.plantProgress > 0) {
          actor.plantProgress = 0;
          game.onPlantCancel(actor);
        }
      }

      if (actor.team === 'CT' && this.bombPlanted) {
        const dist = Math.hypot(actor.pos.x - this.bombPos.x, actor.pos.z - this.bombPos.z);
        if (holding && dist < 1.8 && actor.onGround && !moving) {
          actor.defuseProgress += dt;
          this.defuser = actor;
          const need = actor.kit ? ROUND.defuseTimeKit : ROUND.defuseTime;
          if (actor.defuseProgress >= need) this.defuseBomb(actor);
        } else if (actor.defuseProgress > 0) {
          actor.defuseProgress = 0;
          if (this.defuser === actor) this.defuser = null;
        }
      }
    }
  }

  // --- Kazanma koşulları ----------------------------------------------
  checkWinConditions() {
    if (this.state !== STATE.LIVE) return;
    const game = this.game;
    const aliveCT = game.actors.filter((a) => a.team === 'CT' && a.alive).length;
    const aliveT = game.actors.filter((a) => a.team === 'T' && a.alive).length;

    if (aliveCT === 0 && aliveT === 0) {
      this.endRound(this.bombPlanted ? TEAM.T : TEAM.CT, 'Karşılıklı imha');
      return;
    }
    if (aliveCT === 0) {
      this.endRound(TEAM.T, 'Karşı takım imha edildi');
      return;
    }
    if (aliveT === 0 && !this.bombPlanted) {
      this.endRound(TEAM.CT, 'Karşı takım imha edildi');
    }
  }

  endRound(winner, reason) {
    if (this.state === STATE.ENDED || this.state === STATE.MATCH_END) return;
    const game = this.game;
    this.state = STATE.ENDED;
    this.timer = ROUND.endTime;
    this.winner = winner;
    this.winReason = reason;
    this.scores[winner]++;
    const loser = winner === TEAM.CT ? TEAM.T : TEAM.CT;
    this.lossStreak[loser] = Math.min(4, this.lossStreak[loser] + 1);
    this.lossStreak[winner] = 0;

    // Ekonomi
    let winReward = ECONOMY.winRound;
    if (winner === TEAM.CT && reason === 'Bomba imha edildi') winReward = ECONOMY.winDefuse;
    const lossReward = clamp(
      ECONOMY.lossBase + (this.lossStreak[loser] - 1) * ECONOMY.lossStep,
      ECONOMY.lossBase, ECONOMY.lossMax,
    );
    for (const a of game.actors) {
      const reward = a.team === winner ? winReward : lossReward;
      let extra = 0;
      if (a.team === TEAM.T && this.bombWasPlantedThisRound) extra = ECONOMY.winBombPlant;
      a.money = Math.min(ECONOMY.max, a.money + reward + extra);
    }

    game.onRoundEnd(winner, reason);

    // Maç / devre kontrolü
    const total = this.scores.CT + this.scores.T;
    if (this.scores[winner] >= ROUND.winScore || total >= ROUND.maxRounds) {
      this.matchOver = true;
      this.state = STATE.MATCH_END;
      this.timer = 12;
      game.onMatchEnd(this.scores.CT === this.scores.T ? null : (this.scores.CT > this.scores.T ? TEAM.CT : TEAM.T));
    } else if (total === ROUND.halfTime && !this.switchedSides) {
      this.switchedSides = true;
      this.pendingSwap = true;
    }
  }

  update(dt) {
    const game = this.game;
    this.timer -= dt;

    if (this.state === STATE.FREEZE) {
      if (this.timer <= 0) {
        this.state = STATE.LIVE;
        this.timer = ROUND.roundTime;
        game.onRoundLive();
      }
      return;
    }

    if (this.state === STATE.LIVE) {
      this.updateUse(dt);
      if (this.bombPlanted) {
        this.bombTimer -= dt;
        this.bombWasPlantedThisRound = true;
        // Bip sesi hızlanır
        const interval = clamp(this.bombTimer / 22, 0.14, 1.0);
        if (game.time - this.lastBeep > interval) {
          this.lastBeep = game.time;
          game.audio.play('beep', { pos: this.bombPos, volume: 0.7, maxDist: 45 });
          if (this.bombLight) this.bombLight.visible = true;
        } else if (this.bombLight && game.time - this.lastBeep > interval * 0.4) {
          this.bombLight.visible = false;
        }
        if (this.bombTimer <= 0) this.explodeBomb();
      } else if (this.timer <= 0) {
        this.endRound(TEAM.CT, 'Süre doldu');
      }
      this.checkWinConditions();
      return;
    }

    if (this.state === STATE.ENDED) {
      if (this.timer <= 0) {
        if (this.pendingSwap) {
          this.pendingSwap = false;
          game.swapTeams();
          const tmp = this.scores.CT;
          this.scores.CT = this.scores.T;
          this.scores.T = tmp;
          const tmp2 = this.lossStreak.CT;
          this.lossStreak.CT = this.lossStreak.T;
          this.lossStreak.T = tmp2;
          for (const a of game.actors) {
            a.money = ECONOMY.start;
            a.dropAll();
            a.armor = 0;
            a.helmet = false;
            a.kit = false;
            a.alive = false;   // yeni devrede sıfırdan başla
          }
        }
        this.bombWasPlantedThisRound = false;
        this.startRound();
      }
      return;
    }

    if (this.state === STATE.MATCH_END) {
      if (this.timer <= 0) game.restartMatch();
    }
  }
}
