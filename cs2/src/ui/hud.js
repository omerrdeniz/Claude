// DOM tabanlı HUD: sağlık, cephane, skor, killfeed, satın alma menüsü, skor tablosu.

import { WEAPONS, weaponsForTeam, KEVLAR_PRICE, HELMET_PRICE, DEFUSE_KIT_PRICE } from '../weapons.js';
import { STATE } from '../systems/round.js';

const $ = (id) => document.getElementById(id);

function fmtTime(sec) {
  const s = Math.max(0, Math.ceil(sec));
  return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`;
}

export class Hud {
  constructor() {
    this.el = {
      crosshair: $('crosshair'),
      hitmarker: $('hitmarker'),
      scope: $('scope'),
      damage: $('damage-flash'),
      scoreCT: $('score-ct'),
      scoreT: $('score-t'),
      aliveCT: $('alive-ct'),
      aliveT: $('alive-t'),
      timer: $('timer'),
      roundLabel: $('round-label'),
      killfeed: $('killfeed'),
      centerMsg: $('center-msg'),
      hint: $('hint'),
      progress: $('progress'),
      progressBar: $('progress-bar'),
      progressLabel: $('progress-label'),
      health: $('health'),
      armor: $('armor'),
      money: $('money'),
      weaponName: $('weapon-name'),
      ammoBox: $('ammo'),
      ammoMag: $('ammo-mag'),
      ammoReserve: $('ammo-reserve'),
      items: $('items'),
      bombStatus: $('bomb-status'),
      buyMenu: $('buy-menu'),
      buyList: $('buy-list'),
      buyMoney: $('buy-money'),
      scoreboard: $('scoreboard'),
      sbCT: $('sb-ct'),
      sbT: $('sb-t'),
      sbTitle: $('sb-title'),
      fps: $('fps'),
    };
    this.hitmarkerUntil = 0;
    this.centerUntil = 0;
    this.hintUntil = 0;
    this.killRows = [];
    this.buyOpen = false;
    this.scoreboardOpen = false;
    this.lastMoney = null;
  }

  // --- Anlık geri bildirimler -----------------------------------------
  showHitmarker(time, kill = false) {
    this.el.hitmarker.classList.add('show');
    this.el.hitmarker.classList.toggle('kill', kill);
    this.hitmarkerUntil = time + 0.14;
  }

  damageFlash() {
    const el = this.el.damage;
    el.classList.add('on');
    // reflow tetikle, sonra söndür
    void el.offsetWidth;
    el.classList.remove('on');
  }

  centerMessage(time, text, sub = '', duration = 3) {
    this.el.centerMsg.innerHTML = sub ? `${text}<span class="small">${sub}</span>` : text;
    this.el.centerMsg.classList.add('show');
    this.centerUntil = time + duration;
  }

  hint(time, text, duration = 1.2) {
    this.el.hint.textContent = text;
    this.el.hint.classList.add('show');
    this.hintUntil = time + duration;
  }

  addKill(killer, victim, weaponName, headshot, playerTeam) {
    const row = document.createElement('div');
    row.className = 'kf-row';
    const kClass = killer ? (killer.team === 'CT' ? 'kf-ct' : 'kf-t') : '';
    const vClass = victim.team === 'CT' ? 'kf-ct' : 'kf-t';
    row.innerHTML = `${killer ? `<span class="${kClass}">${killer.name}</span>` : '<span>·</span>'}` +
      `<span class="kf-weapon">${weaponName}</span>` +
      `${headshot ? '<span class="kf-hs">HS</span>' : ''}` +
      `<span class="${vClass}">${victim.name}</span>`;
    this.el.killfeed.appendChild(row);
    this.killRows.push({ el: row, until: performance.now() / 1000 + 6 });
    while (this.killRows.length > 5) {
      const old = this.killRows.shift();
      old.el.remove();
    }
    void playerTeam;
  }

  // --- Satın alma menüsü ----------------------------------------------
  toggleBuy(open) {
    this.buyOpen = open;
    this.el.buyMenu.classList.toggle('hidden', !open);
  }

  renderBuy(player) {
    const rows = [];
    for (const entry of weaponsForTeam(player.team)) {
      let name;
      let price;
      let owned = false;
      if (entry.kind === 'weapon') {
        const def = WEAPONS[entry.id];
        name = def.name;
        price = def.price;
        owned = player.hasWeapon(entry.id);
      } else if (entry.kind === 'armor') {
        name = 'Kevlar';
        price = KEVLAR_PRICE;
        owned = player.armor > 0 && !player.helmet;
      } else if (entry.kind === 'helmet') {
        name = 'Kevlar + Kask';
        price = HELMET_PRICE;
        owned = player.armor > 0 && player.helmet;
      } else if (entry.kind === 'kit') {
        name = 'İmha Kiti';
        price = DEFUSE_KIT_PRICE;
        owned = player.kit;
      } else if (entry.kind === 'grenade') {
        name = WEAPONS[entry.id].name;
        price = WEAPONS[entry.id].price;
        owned = !!player.inventory.grenade;
      }
      const afford = player.money >= price;
      rows.push(`<div class="buy-row ${owned ? 'owned' : (afford ? '' : 'cant')}">
        <span class="key">${entry.key.toUpperCase()}</span>
        <span class="name">${name}</span>
        <span class="price">${owned ? 'sende' : `$${price}`}</span>
      </div>`);
    }
    this.el.buyList.innerHTML = rows.join('');
    this.el.buyMoney.textContent = `$${player.money}`;
  }

  // --- Skor tablosu ----------------------------------------------------
  toggleScoreboard(open) {
    this.scoreboardOpen = open;
    this.el.scoreboard.classList.toggle('hidden', !open);
  }

  renderScoreboard(game) {
    const build = (team) => game.actors
      .filter((a) => a.team === team)
      .sort((a, b) => b.score - a.score || b.kills - a.kills)
      .map((a) => `<tr class="${a.alive ? '' : 'dead'} ${a === game.player ? 'you' : ''}">
        <td>${a.name}${a.hasBomb ? ' &#9679;' : ''}</td>
        <td>${a.kills}</td><td>${a.deaths}</td><td>${a.score}</td><td>$${a.money}</td>
      </tr>`).join('');
    this.el.sbCT.innerHTML = build('CT');
    this.el.sbT.innerHTML = build('T');
    this.el.sbTitle.textContent =
      `Skor Tablosu — CT ${game.round.scores.CT} : ${game.round.scores.T} T (Raunt ${game.round.number})`;
  }

  // --- Kare güncellemesi ----------------------------------------------
  update(game) {
    const el = this.el;
    const player = game.player;
    const round = game.round;
    const time = game.time;

    if (this.hitmarkerUntil && time > this.hitmarkerUntil) {
      el.hitmarker.classList.remove('show');
      this.hitmarkerUntil = 0;
    }
    if (this.centerUntil && time > this.centerUntil) {
      el.centerMsg.classList.remove('show');
      this.centerUntil = 0;
    }
    if (this.hintUntil && time > this.hintUntil) {
      el.hint.classList.remove('show');
      this.hintUntil = 0;
    }
    const now = performance.now() / 1000;
    while (this.killRows.length && this.killRows[0].until < now) {
      this.killRows.shift().el.remove();
    }

    // Üst bar
    el.scoreCT.textContent = round.scores.CT;
    el.scoreT.textContent = round.scores.T;
    const aliveCT = game.actors.filter((a) => a.team === 'CT' && a.alive).length;
    const aliveT = game.actors.filter((a) => a.team === 'T' && a.alive).length;
    el.aliveCT.textContent = '●'.repeat(aliveCT) + '○'.repeat(Math.max(0, game.teamSize - aliveCT));
    el.aliveT.textContent = '○'.repeat(Math.max(0, game.teamSize - aliveT)) + '●'.repeat(aliveT);

    let timeText;
    if (round.state === STATE.FREEZE) timeText = fmtTime(round.timer);
    else if (round.state === STATE.LIVE) timeText = round.bombPlanted ? fmtTime(round.bombTimer) : fmtTime(round.timer);
    else timeText = '0:00';
    el.timer.textContent = timeText;
    el.timer.classList.toggle('urgent', round.bombPlanted || (round.state === STATE.LIVE && round.timer < 20));
    el.roundLabel.textContent = round.state === STATE.FREEZE
      ? `Raunt ${round.number} — hazırlık`
      : `Raunt ${round.number}`;

    // Bomba durumu
    if (round.bombPlanted) {
      el.bombStatus.classList.add('show');
      el.bombStatus.textContent = `BOMBA KURULDU — ${round.bombTimer.toFixed(1)} sn`;
    } else {
      el.bombStatus.classList.remove('show');
    }

    if (!player) return;

    // Sağlık / para
    el.health.textContent = Math.max(0, Math.round(player.health));
    el.armor.textContent = Math.round(player.armor);
    el.money.textContent = `$${player.money}`;
    if (this.lastMoney !== null && player.money !== this.lastMoney) {
      el.money.classList.add('flash');
      setTimeout(() => el.money.classList.remove('flash'), 250);
    }
    this.lastMoney = player.money;

    // Silah / cephane
    const weapon = player.weapon();
    const st = player.weaponState();
    el.weaponName.textContent = weapon.name;
    if (st && weapon.mag > 0) {
      el.ammoMag.textContent = st.ammo;
      el.ammoReserve.textContent = `/ ${st.reserve}`;
      el.ammoBox.classList.toggle('low', st.ammo <= Math.max(1, weapon.mag * 0.2));
      el.ammoBox.style.visibility = 'visible';
    } else {
      el.ammoBox.style.visibility = 'hidden';
    }

    const items = [];
    if (player.armor > 0) items.push(player.helmet ? 'Kevlar+Kask' : 'Kevlar');
    if (player.kit) items.push('İmha kiti');
    if (player.inventory.grenade) items.push('HE');
    if (player.hasBomb) items.push('C4');
    el.items.textContent = items.join(' · ');

    // Nişangâh açıklığı
    const inaccuracy = player.currentInaccuracy();
    const gap = Math.min(46, 4 + inaccuracy * 7.5);
    el.crosshair.style.setProperty('--gap', `${gap.toFixed(1)}px`);
    el.crosshair.classList.toggle('hidden', !player.alive || player.zoomLevel > 0);
    el.scope.classList.toggle('on', player.alive && player.zoomLevel > 0);

    // İlerleme çubuğu (kurma / imha)
    let progress = 0;
    let label = '';
    if (player.plantProgress > 0) {
      progress = player.plantProgress / 3.2;
      label = 'Bomba kuruluyor';
    } else if (player.defuseProgress > 0) {
      progress = player.defuseProgress / (player.kit ? 5 : 10);
      label = player.kit ? 'İmha ediliyor (kit)' : 'İmha ediliyor';
    }
    if (progress > 0) {
      el.progress.classList.add('show');
      el.progressBar.style.width = `${Math.min(100, progress * 100)}%`;
      el.progressLabel.textContent = label;
    } else {
      el.progress.classList.remove('show');
    }

    if (this.buyOpen) this.renderBuy(player);
    if (this.scoreboardOpen) this.renderScoreboard(game);
  }
}
