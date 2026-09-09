// Oyunun çekirdeği: sahne kurulumu, aktörler, giriş işleme, tur olayları ve ana döngü adımı.

import * as THREE from 'three';
import { EffectComposer } from 'three/addons/postprocessing/EffectComposer.js';
import { RenderPass } from 'three/addons/postprocessing/RenderPass.js';
import { UnrealBloomPass } from 'three/addons/postprocessing/UnrealBloomPass.js';
import { OutputPass } from 'three/addons/postprocessing/OutputPass.js';
import { PHYS, DEFAULT_SETTINGS, ROUND, ECONOMY, COLORS } from './config.js';
import { WEAPONS, KEVLAR_PRICE, HELMET_PRICE, DEFUSE_KIT_PRICE, weaponsForTeam } from './weapons.js';
import { clamp, damp, DEG } from './core/math.js';
import { Input } from './core/input.js';
import { AudioEngine } from './core/audio.js';
import { buildMap } from './world/map.js';
import { buildNav } from './world/nav.js';
import { Actor, createActorModel, updateActorModel } from './entities/actor.js';
import { Bot } from './entities/bot.js';
import { ViewModel } from './entities/viewmodel.js';
import { Effects } from './systems/effects.js';
import { Combat } from './systems/combat.js';
import { Grenades } from './systems/grenades.js';
import { Round, STATE } from './systems/round.js';
import { Hud } from './ui/hud.js';
import { Radar } from './ui/radar.js';

const BOT_NAMES = [
  'Cyril', 'Adrian', 'Vitaliy', 'Numeric', 'Zane', 'Wade', 'Otto', 'Quinn',
  'Rip', 'Seth', 'Trace', 'Ulric', 'Vance', 'Yuri', 'Brett', 'Cliff',
];

const FIXED_DT = 1 / 64;

export class Game {
  constructor(canvas, settings = {}) {
    this.canvas = canvas;
    this.settings = { ...DEFAULT_SETTINGS, ...settings };
    this.time = 0;
    this.running = false;
    this.paused = true;
    this.accumulator = 0;
    this.teamSize = ROUND.teamSize;
    this.actors = [];
    this.player = null;
    this.spotted = new Set();
    this.spottedAt = 0;
    this.shakeAmount = 0;
    this._lastShotSeen = -1;
    this.spectateTarget = null;
    this.matchWinner = null;
    this.onMenuRequest = null;

    this._initRenderer();
    this._initScene();

    this.input = new Input(canvas);
    this.audio = new AudioEngine(this.settings.volume);
    this.effects = new Effects(this.scene);
    this.combat = new Combat(this);
    this.grenades = new Grenades(this);
    this.round = new Round(this);
    this.hud = new Hud();
    this.radar = new Radar(document.getElementById('radar'), this.world);
    this.viewmodel = new ViewModel(this.camera);
    this._initComposer();

    this._bindInput();
    window.addEventListener('resize', () => this.resize());
    this.resize();
  }

  // --- Kurulum ---------------------------------------------------------
  _initRenderer() {
    this.renderer = new THREE.WebGLRenderer({
      canvas: this.canvas,
      antialias: true,
      powerPreference: 'high-performance',
    });
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
    this.renderer.shadowMap.enabled = this.settings.shadows;
    this.renderer.shadowMap.type = THREE.PCFSoftShadowMap;
    this.renderer.toneMapping = THREE.ACESFilmicToneMapping;
    this.renderer.toneMappingExposure = 1.0;
    this.renderer.outputColorSpace = THREE.SRGBColorSpace;
  }

  // Post-processing zinciri: MSAA hedefi + hafif bloom + tone mapping çıkışı
  _initComposer() {
    const size = this.renderer.getDrawingBufferSize(new THREE.Vector2());
    const target = new THREE.WebGLRenderTarget(size.x, size.y, {
      type: THREE.HalfFloatType,
      samples: 4,
    });
    this.composer = new EffectComposer(this.renderer, target);
    this.composer.addPass(new RenderPass(this.scene, this.camera));
    // Silah ayrı sahnede, derinlik temizlenerek üstüne çizilir
    const vmPass = new RenderPass(this.viewmodel.scene, this.viewmodel.camera);
    vmPass.clear = false;
    vmPass.clearDepth = true;
    this.composer.addPass(vmPass);
    this.bloomPass = new UnrealBloomPass(
      new THREE.Vector2(size.x / 2, size.y / 2), 0.32, 0.7, 0.92,
    );
    this.composer.addPass(this.bloomPass);
    this.composer.addPass(new OutputPass());
  }

  _initScene() {
    this.scene = new THREE.Scene();
    this.scene.fog = new THREE.Fog(0xc9d9e8, 70, 210);

    this.camera = new THREE.PerspectiveCamera(this.settings.fov, 1, 0.02, 500);
    this.camera.rotation.order = 'YXZ';
    this.scene.add(this.camera);

    // Gökyüzü + ortam yansıması (PMREM)
    const skyTex = gradientSkyTexture();
    const sky = new THREE.Mesh(
      new THREE.SphereGeometry(300, 32, 20),
      new THREE.MeshBasicMaterial({ map: skyTex, side: THREE.BackSide, fog: false, depthWrite: false }),
    );
    sky.renderOrder = -1;
    this.scene.add(sky);

    const pmrem = new THREE.PMREMGenerator(this.renderer);
    pmrem.compileEquirectangularShader();
    const envScene = new THREE.Scene();
    const envSky = new THREE.Mesh(
      new THREE.SphereGeometry(20, 24, 16),
      new THREE.MeshBasicMaterial({ map: skyTex.clone(), side: THREE.BackSide }),
    );
    envScene.add(envSky);
    const sunQuad = new THREE.Mesh(
      new THREE.SphereGeometry(2.2, 12, 8),
      new THREE.MeshBasicMaterial({ color: 0xfff2cc }),
    );
    sunQuad.position.set(8, 14, 6);
    envScene.add(sunQuad);
    const envRT = pmrem.fromScene(envScene, 0.04);
    this.scene.environment = envRT.texture;
    pmrem.dispose();

    // Işıklar
    this.scene.add(new THREE.HemisphereLight(0xbcc9d2, 0x8a7550, 0.55));
    this.scene.add(new THREE.AmbientLight(0x7a6a50, 0.28));

    const sun = new THREE.DirectionalLight(0xffeccb, 2.9);
    sun.position.set(38, 62, 26);
    sun.castShadow = true;
    sun.shadow.mapSize.set(2048, 2048);
    sun.shadow.camera.left = -42;
    sun.shadow.camera.right = 42;
    sun.shadow.camera.top = 46;
    sun.shadow.camera.bottom = -46;
    sun.shadow.camera.near = 1;
    sun.shadow.camera.far = 190;
    sun.shadow.bias = -0.0004;
    sun.shadow.normalBias = 0.035;
    this.scene.add(sun);
    this.scene.add(sun.target);
    this.sun = sun;

    // Karşı yönden hafif dolgu ışığı (gölgeler tamamen kararmasın)
    const fill = new THREE.DirectionalLight(0xa9c3de, 0.22);
    fill.position.set(-30, 24, -18);
    this.scene.add(fill);

    this.world = buildMap(this.scene);
    this.nav = buildNav(this.world);
  }

  resize() {
    const w = window.innerWidth;
    const h = window.innerHeight;
    this.renderer.setSize(w, h, false);
    this.camera.aspect = w / h;
    this.camera.updateProjectionMatrix();
    if (this.viewmodel) this.viewmodel.setAspect(w / h);
    if (this.composer) {
      const size = this.renderer.getDrawingBufferSize(new THREE.Vector2());
      this.composer.setSize(size.x, size.y);
      if (this.bloomPass) this.bloomPass.setSize(size.x / 2, size.y / 2);
    }
  }

  applySettings(settings) {
    Object.assign(this.settings, settings);
    this.audio.setVolume(this.settings.volume);
    this.renderer.shadowMap.enabled = this.settings.shadows;
    this.sun.castShadow = this.settings.shadows;
    if (this.bloomPass) this.bloomPass.enabled = this.settings.postfx !== false;
    this.camera.fov = this.settings.fov;
    this.camera.updateProjectionMatrix();
    this.hud.el.fps.classList.toggle('hidden', !this.settings.showFps);
  }

  // --- Aktörler --------------------------------------------------------
  createMatch({ team = 'CT', teamSize = 5, difficulty = 2 } = {}) {
    for (const a of this.actors) if (a.model) this.scene.remove(a.model);
    this.actors.length = 0;
    this.teamSize = teamSize;
    this.settings.botDifficulty = difficulty;

    const names = [...BOT_NAMES].sort(() => Math.random() - 0.5);
    this.player = new Actor({ team, name: 'Sen' });
    this.player.money = ECONOMY.start;
    this.actors.push(this.player);

    let n = 0;
    for (const t of ['CT', 'T']) {
      const count = teamSize - (t === team ? 1 : 0);
      for (let i = 0; i < count; i++) {
        const bot = new Bot({ team: t, name: names[n++ % names.length], difficulty });
        bot.money = ECONOMY.start;
        this.actors.push(bot);
      }
    }

    for (const a of this.actors) {
      if (a === this.player) continue;
      a.model = createActorModel(a.team);
      this.scene.add(a.model);
    }

    this.round = new Round(this);
    this.matchWinner = null;
    this.round.startRound();
    this.hud.centerMessage(this.time, 'MAÇ BAŞLIYOR', 'İlk 13 raundu kazanan maçı alır', 3);
  }

  swapTeams() {
    for (const a of this.actors) {
      a.team = a.team === 'CT' ? 'T' : 'CT';
      if (a.model) {
        this.scene.remove(a.model);
        a.model = createActorModel(a.team);
        this.scene.add(a.model);
      }
    }
    this.hud.centerMessage(this.time, 'DEVRE ARASI', 'Taraflar değişti', 4);
  }

  restartMatch() {
    this.createMatch({
      team: this.player ? this.player.team : 'CT',
      teamSize: this.teamSize,
      difficulty: this.settings.botDifficulty,
    });
  }

  // --- Giriş -----------------------------------------------------------
  _bindInput() {
    this.input.onLockChange = (locked) => {
      if (!locked && this.running && !this.round.matchOver) {
        this.paused = true;
        if (this.onMenuRequest) this.onMenuRequest();
      }
    };

    this.input.onKeyPress = (e) => {
      if (!this.running || this.paused) return;
      const player = this.player;
      if (!player) return;

      if (e.code === 'KeyB') {
        this.hud.toggleBuy(!this.hud.buyOpen);
        this.audio.play('ui', { freq: 520, volume: 0.5 });
        return;
      }
      if (this.hud.buyOpen) {
        const key = e.key.toLowerCase();
        const entry = weaponsForTeam(player.team).find((x) => x.key === key);
        if (entry) this.tryBuy(entry);
        return;
      }
      const slotKeys = { Digit1: 'primary', Digit2: 'secondary', Digit3: 'melee', Digit4: 'grenade' };
      if (e.code === 'Digit4') {
        if (player.slot === 'grenade' && player.grenadeBag.length > 1) {
          player.cycleGrenade();
          player.deployEnd = this.time + 0.35;
          this.audio.play('reload', { volume: 0.4 });
        } else if (player.grenadeBag.length && player.switchSlot('grenade', this.time)) {
          this.audio.play('reload', { volume: 0.4 });
        }
        return;
      }
      if (slotKeys[e.code]) {
        if (player.switchSlot(slotKeys[e.code], this.time)) {
          this.audio.play('reload', { volume: 0.4 });
        }
      }
    };
  }

  tryBuy(entry) {
    const player = this.player;
    const round = this.round;
    if (!player.alive) { this.hud.hint(this.time, 'Ölüyken satın alamazsın'); return; }
    if (!round.canBuy) { this.hud.hint(this.time, 'Satın alma süresi doldu'); return; }
    if (!this.world.inBuyZone(player.team, player.pos.x, player.pos.z)) {
      this.hud.hint(this.time, 'Satın alma bölgesinde değilsin');
      return;
    }

    const buyWeapon = (id) => {
      const def = WEAPONS[id];
      if (player.money < def.price) return this.hud.hint(this.time, 'Yeterli paran yok');
      player.money -= def.price;
      const st = player.giveWeapon(id);
      if (def.slot === 'primary' || def.slot === 'secondary') player.switchSlot(def.slot, this.time);
      else if (def.slot === 'grenade') { /* el bombası envanterde bekler */ }
      this.audio.play('ui', { freq: 760, volume: 0.6 });
      this.hud.hint(this.time, `${def.name} alındı`);
      void st;
    };

    if (entry.kind === 'weapon') {
      buyWeapon(entry.id);
    } else if (entry.kind === 'grenade') {
      const def = WEAPONS[entry.id];
      if (player.grenadeBag.includes(entry.id)) return this.hud.hint(this.time, `${def.name} zaten var`);
      if (player.grenadeBag.length >= 3) return this.hud.hint(this.time, 'En fazla 3 el bombası taşınır');
      if (player.money < def.price) return this.hud.hint(this.time, 'Yeterli paran yok');
      player.money -= def.price;
      player.giveGrenade(entry.id);
      this.audio.play('ui', { freq: 760, volume: 0.6 });
      this.hud.hint(this.time, `${def.name} alındı`);
    } else if (entry.kind === 'armor') {
      if (player.armor > 0 && !player.helmet) return this.hud.hint(this.time, 'Zırhın zaten var');
      if (player.money < KEVLAR_PRICE) return this.hud.hint(this.time, 'Yeterli paran yok');
      player.money -= KEVLAR_PRICE;
      player.armor = 100;
      this.audio.play('ui', { freq: 700, volume: 0.6 });
    } else if (entry.kind === 'helmet') {
      if (player.armor > 0 && player.helmet) return this.hud.hint(this.time, 'Kask ve zırhın zaten var');
      if (player.money < HELMET_PRICE) return this.hud.hint(this.time, 'Yeterli paran yok');
      player.money -= HELMET_PRICE;
      player.armor = 100;
      player.helmet = true;
      this.audio.play('ui', { freq: 700, volume: 0.6 });
    } else if (entry.kind === 'kit') {
      if (player.team !== 'CT') return;
      if (player.kit) return this.hud.hint(this.time, 'İmha kitin zaten var');
      if (player.money < DEFUSE_KIT_PRICE) return this.hud.hint(this.time, 'Yeterli paran yok');
      player.money -= DEFUSE_KIT_PRICE;
      player.kit = true;
      this.audio.play('ui', { freq: 700, volume: 0.6 });
    }
    return undefined;
  }

  updatePlayerCommand(dt) {
    const player = this.player;
    const input = this.input;
    const cmd = player.cmd;
    cmd.forward = 0; cmd.side = 0; cmd.jump = false; cmd.crouch = false;
    cmd.walk = false; cmd.attack = false; cmd.attackPressed = false;
    cmd.reload = false; cmd.use = false;

    if (!this.input.locked || this.paused) return;
    if (!player.alive) return;
    if (this.hud.buyOpen) return;

    if (input.isDown('KeyW')) cmd.forward += 1;
    if (input.isDown('KeyS')) cmd.forward -= 1;
    if (input.isDown('KeyD')) cmd.side += 1;
    if (input.isDown('KeyA')) cmd.side -= 1;
    cmd.jump = input.isDown('Space');
    cmd.crouch = input.isDown('ControlLeft') || input.isDown('ControlRight') || input.isDown('KeyC');
    cmd.walk = input.isDown('ShiftLeft') || input.isDown('ShiftRight');
    cmd.attack = input.mouse.left;
    cmd.attackPressed = input.mouse.leftPressed;
    cmd.reload = input.isDown('KeyR');
    cmd.use = input.isDown('KeyE');

    void dt;
  }

  // Fare bakışı, tekerlek ve dürbün: fizik adımından bağımsız, kare başına bir kez.
  handleFrameInput() {
    const player = this.player;
    const input = this.input;
    if (!player) return;
    if (!input.locked || this.paused) return;

    const sens = this.settings.sensitivity * 0.022 * DEG;
    const zoomMul = player.zoomLevel > 0 ? 0.5 / player.zoomLevel : 1;
    player.yaw -= input.mouse.dx * sens * zoomMul;
    player.pitch -= input.mouse.dy * sens * zoomMul;
    player.pitch = clamp(player.pitch, -89 * DEG, 89 * DEG);

    this.hud.toggleScoreboard(input.isDown('Tab'));
    if (!player.alive || this.hud.buyOpen) return;

    const weapon = player.weapon();
    if (input.mouse.rightPressed) {
      if (weapon.zoom) {
        player.zoomLevel = (player.zoomLevel + 1) % (weapon.zoom.length + 1);
        this.audio.play('ui', { freq: 900, volume: 0.35 });
      } else {
        player.zoomLevel = 0;
      }
    }
    if (!weapon.zoom) player.zoomLevel = 0;

    if (input.mouse.wheel !== 0) {
      player.nextSlot(this.time, input.mouse.wheel > 0 ? 1 : -1);
    }
  }

  // --- Olay geri çağrıları ---------------------------------------------
  onJump(actor) {
    if (actor === this.player) this.viewmodel.bobPhase = 0;
    this.audio.play('footstep', { pos: actor.pos, volume: 0.5 });
    this.notifyNoise(actor, actor.pos, 14);
  }

  onFootstep(actor) {
    this.audio.play('footstep', {
      pos: actor.pos,
      volume: actor === this.player ? 0.45 : 0.9,
      maxDist: 26,
    });
    this.notifyNoise(actor, actor.pos, 16);
  }

  onReload(actor) {
    const w = actor.weapon();
    this.audio.play('reload', { pos: actor.pos, volume: 0.8 });
    if (actor === this.player) this.viewmodel.startReload(w.reloadTime);
    setTimeout(() => this.audio.play('reload', { pos: actor.pos, volume: 0.7 }), w.reloadTime * 500);
  }

  onFallDamage(actor, dmg) {
    if (actor === this.player) {
      this.hud.damageFlash();
      this.shake(0.3);
    }
    void dmg;
  }

  onDamage(victim, attacker, dmg, part, explosion = false) {
    if (dmg <= 0) return;
    if (attacker) attacker.damageDealt += dmg;
    if (attacker === this.player && victim.team !== this.player.team) {
      this.hud.showHitmarker(this.time, !victim.alive);
      this.audio.play(part === 'head' ? 'headshot' : 'hitmarker', { volume: 0.7 });
    }
    if (victim === this.player) {
      this.hud.damageFlash();
      this.shake(Math.min(0.8, dmg / 45));
    }
    void explosion;
  }

  onActorDeath(victim, attacker, part) {
    const weaponName = attacker && attacker.weapon ? attacker.weapon().name : 'dünya';
    if (attacker && attacker !== victim && attacker.team !== victim.team) {
      attacker.kills++;
      attacker.score += 2;
      const reward = attacker.weapon().killReward;
      attacker.money = Math.min(ECONOMY.max, attacker.money + reward);
    } else if (attacker && attacker.team === victim.team && attacker !== victim) {
      attacker.kills--;
      attacker.score -= 2;
    }
    this.hud.addKill(attacker, victim, weaponName, part === 'head', this.player.team);
    this.audio.play('impact', { pos: victim.pos, mat: 'flesh', volume: 1 });

    // Bomba taşıyıcısı ölürse bomba düşer -> hayatta kalan bir teröriste geçer
    if (victim.hasBomb) {
      victim.hasBomb = false;
      const alive = this.actors.filter((a) => a.team === 'T' && a.alive);
      if (alive.length) {
        const next = alive.reduce((best, a) => {
          const d = a.pos.distanceTo(victim.pos);
          return !best || d < best.d ? { a, d } : best;
        }, null);
        next.a.hasBomb = true;
        this.round.bombCarrier = next.a;
        if (next.a === this.player) this.hud.centerMessage(this.time, 'BOMBA SENDE', 'Bombasahasında E ile kur', 2.5);
      } else {
        this.round.bombCarrier = null;
      }
    }

    if (victim === this.player) {
      this.hud.centerMessage(this.time, 'ÖLDÜN', attacker ? `${attacker.name} · ${weaponName}` : '', 3);
      this.viewmodel.hidden = true;
      this.pickSpectateTarget();
    }
    if (victim.model) victim.model.rotation.x = -0.05;
  }

  pickSpectateTarget() {
    const mates = this.actors.filter((a) => a.alive && a.team === this.player.team && a !== this.player);
    this.spectateTarget = mates.length ? mates[0] : null;
  }

  onRoundStart() {
    this.viewmodel.hidden = false;
    this.spectateTarget = null;
    this.hud.toggleBuy(false);
    this.audio.play('roundstart', { volume: 0.8 });
    const site = this.round.targetSite;
    const msg = this.player.team === 'T'
      ? `HEDEF: ${site} BÖLGESİ`
      : 'BOMBASAHALARINI SAVUN';
    this.hud.centerMessage(this.time, `RAUNT ${this.round.number}`, msg, 3);
    if (this.player.hasBomb) this.hud.centerMessage(this.time, 'BOMBA SENDE', 'Bombasahasında E ile kur', 3);
  }

  onRoundLive() {
    this.hud.hint(this.time, 'Tur başladı!', 1.2);
  }

  onRoundEnd(winner, reason) {
    const win = winner === this.player.team;
    this.hud.centerMessage(this.time, win ? 'TUR KAZANILDI' : 'TUR KAYBEDİLDİ', reason, ROUND.endTime);
    this.audio.play('ui', { freq: win ? 880 : 300, volume: 0.8 });
  }

  onMatchEnd(winner) {
    this.matchWinner = winner;
    const text = winner === this.player.team ? 'MAÇI KAZANDIN!' : 'MAÇI KAYBETTİN';
    this.hud.centerMessage(this.time, text,
      `${this.round.scores.CT} - ${this.round.scores.T}`, 12);
  }

  onBombPlanted(actor) {
    this.audio.play('beep', { pos: this.round.bombPos, volume: 1, freq: 1200 });
    const mine = actor.team === this.player.team;
    this.hud.centerMessage(this.time, 'BOMBA KURULDU',
      mine ? 'Savun!' : 'İmha et!', 3);
    for (const a of this.actors) {
      if (a.isBot) { a.holdPos = null; a.path = null; a.goalNode = -1; }
    }
  }

  onBombDefused(actor) {
    void actor;
    this.audio.play('ui', { freq: 1000, volume: 0.9 });
  }

  onPlantStart(actor) {
    if (actor === this.player) this.hud.hint(this.time, 'Bomba kuruluyor... hareket etme', 3.5);
  }

  onPlantCancel(actor) {
    void actor;
  }

  notifyNoise(source, pos, strength) {
    for (const a of this.actors) {
      if (!a.isBot || !a.alive || a === source) continue;
      if (source && a.team === source.team) continue;
      a.hearNoise(pos, strength, this);
    }
  }

  // Oyuncu flaşlandığında beyaz perde
  onPlayerFlashed(duration, strength) {
    this.hud.flash(duration, strength);
    this.audio.play('beep', { freq: 2400, volume: 0.5 });
  }

  shake(amount) {
    this.shakeAmount = Math.min(1.6, this.shakeAmount + amount);
  }

  // --- Döngü -----------------------------------------------------------
  step(dt) {
    this.time += dt;
    const player = this.player;
    if (!player) return;

    this.updatePlayerCommand(dt);

    for (const a of this.actors) {
      if (a.isBot) a.think(dt, this);
    }
    for (const a of this.actors) {
      a.update(dt, this);
    }
    this.resolveActorOverlap();
    this.grenades.update(dt);
    this.round.update(dt);

    // Görülen düşmanlar (mini harita için)
    if (this.time - this.spottedAt > 0.2) {
      this.spottedAt = this.time;
      const seen = new Set();
      const friends = this.actors.filter((a) => a.alive && a.team === player.team);
      for (const enemy of this.actors) {
        if (!enemy.alive || enemy.team === player.team) continue;
        for (const f of friends) {
          if (this.combat.canSee(f, enemy)) { seen.add(enemy.id); break; }
        }
      }
      this.spotted = seen;
    }

    if (player.alive) this.spectateTarget = null;
    else if (!this.spectateTarget || !this.spectateTarget.alive) this.pickSpectateTarget();
  }

  // Aktörler birbirinin içine girmesin (yumuşak itme).
  resolveActorOverlap() {
    const r = PHYS.radius * 1.7;
    for (let i = 0; i < this.actors.length; i++) {
      const a = this.actors[i];
      if (!a.alive) continue;
      for (let j = i + 1; j < this.actors.length; j++) {
        const b = this.actors[j];
        if (!b.alive) continue;
        const dx = b.pos.x - a.pos.x;
        const dz = b.pos.z - a.pos.z;
        const distSq = dx * dx + dz * dz;
        if (distSq > r * r || distSq < 1e-6) continue;
        const dist = Math.sqrt(distSq);
        const push = (r - dist) / 2;
        const nx = dx / dist;
        const nz = dz / dist;
        // Dikey olarak birbirinin üstündeyse itme
        if (Math.abs(a.pos.y - b.pos.y) > Math.max(a.height, b.height) * 0.8) continue;
        a.pos.x -= nx * push; a.pos.z -= nz * push;
        b.pos.x += nx * push; b.pos.z += nz * push;
      }
    }
  }

  updateCamera(dt) {
    const player = this.player;
    const view = player.alive ? player : (this.spectateTarget || player);
    const eye = view.eyePos(new THREE.Vector3());

    this.camera.position.copy(eye);
    if (view === player) {
      this.camera.rotation.set(player.aimPitch(), player.aimYaw(), 0, 'YXZ');
    } else {
      this.camera.rotation.set(view.pitch, view.yaw, 0, 'YXZ');
    }

    // Sarsıntı
    if (this.shakeAmount > 0.001) {
      const s = this.shakeAmount;
      this.camera.position.x += (Math.random() - 0.5) * s * 0.14;
      this.camera.position.y += (Math.random() - 0.5) * s * 0.14;
      this.camera.position.z += (Math.random() - 0.5) * s * 0.14;
      this.camera.rotation.z += (Math.random() - 0.5) * s * 0.03;
      this.shakeAmount = damp(this.shakeAmount, 0, 6, dt);
    }

    // Dürbün / FOV
    const weapon = player.weapon();
    let targetFov = this.settings.fov;
    if (player.alive && player.zoomLevel > 0 && weapon.zoom) {
      targetFov = weapon.zoom[player.zoomLevel - 1];
    }
    if (Math.abs(this.camera.fov - targetFov) > 0.01) {
      this.camera.fov = damp(this.camera.fov, targetFov, 22, dt);
      this.camera.updateProjectionMatrix();
    }

    this.audio.setListener(this.camera.position, player.alive ? player.yaw : view.yaw);

    // Güneş gölge kamerasını oyuncunun etrafında tut
    this.sun.position.set(view.pos.x + 38, 62, view.pos.z + 26);
    this.sun.target.position.set(view.pos.x, 0, view.pos.z);
    this.sun.target.updateMatrixWorld();
  }

  // Maç başlamadan önce menü arkasında haritayı gezdiren kamera.
  menuCamera(dt) {
    this.menuAngle = (this.menuAngle || 0) + dt * 0.06;
    const r = 52;
    this.camera.position.set(Math.cos(this.menuAngle) * r, 30, Math.sin(this.menuAngle) * r);
    this.camera.rotation.set(0, 0, 0);
    this.camera.lookAt(0, 2, -4);
    this.sun.position.set(38, 62, 26);
    this.sun.target.position.set(0, 0, 0);
    this.sun.target.updateMatrixWorld();
  }

  render(dt) {
    const player = this.player;
    if (!player) {
      this.effects.update(dt);
      this.menuCamera(dt);
      this.hud.update(this);
      this.present();
      return;
    }
    for (const a of this.actors) {
      if (a.model) updateActorModel(a, dt);
    }
    this.effects.update(dt);
    this.updateCamera(dt);

    // Viewmodel
    const weapon = player.weapon();
    this.viewmodel.setWeapon(player.weaponState() ? player.weaponState().id : 'knife');
    if (player.alive && player.lastShot > this._lastShotSeen) {
      this._lastShotSeen = player.lastShot;
      this.viewmodel.fireKick(weapon);
    }
    this.viewmodel.update(dt, {
      speed: Math.hypot(player.vel.x, player.vel.z),
      onGround: player.onGround,
      zoom: player.zoomLevel,
      alive: player.alive,
      mouseDX: this.input.mouse.dx,
      mouseDY: this.input.mouse.dy,
    });

    this.hud.update(this);
    this.radar.draw(this);
    this.present();
  }

  // Ayara göre post-processing ile veya doğrudan çizer.
  present() {
    if (this.settings.postfx !== false && this.composer) {
      this.composer.render();
      return;
    }
    this.renderer.render(this.scene, this.camera);
    if (this.viewmodel && this.viewmodel.root.visible) {
      this.renderer.autoClear = false;
      this.renderer.clearDepth();
      this.renderer.render(this.viewmodel.scene, this.viewmodel.camera);
      this.renderer.autoClear = true;
    }
  }

  frame(rawDt) {
    const dt = Math.min(0.1, rawDt);
    this.handleFrameInput();
    if (!this.paused) {
      this.accumulator += dt;
      let steps = 0;
      while (this.accumulator >= FIXED_DT && steps < 8) {
        this.step(FIXED_DT);
        this.accumulator -= FIXED_DT;
        steps++;
      }
      if (steps === 8) this.accumulator = 0;
    }
    this.render(dt);
    this.input.endFrame();
  }
}

// Dikey gradyanlı gökyüzü dokusu (küre iç yüzeyine sarılır)
function gradientSkyTexture() {
  const c = document.createElement('canvas');
  c.width = 16;
  c.height = 256;
  const ctx = c.getContext('2d');
  const g = ctx.createLinearGradient(0, 0, 0, 256);
  g.addColorStop(0.0, '#2f6fb5');
  g.addColorStop(0.35, '#79a9d8');
  g.addColorStop(0.55, '#bcd2e4');
  g.addColorStop(0.72, '#e2dcc8');
  g.addColorStop(1.0, '#cbb894');
  ctx.fillStyle = g;
  ctx.fillRect(0, 0, 16, 256);
  const tex = new THREE.CanvasTexture(c);
  tex.colorSpace = THREE.SRGBColorSpace;
  tex.wrapS = THREE.RepeatWrapping;
  tex.wrapT = THREE.ClampToEdgeWrapping;
  return tex;
}

export { STATE };
