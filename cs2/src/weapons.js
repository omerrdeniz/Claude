// Silah tanımları: hasar, isabet (spread), geri tepme (recoil) desenleri ve ekonomi.
// Değerler CS2'deki dengeye yakın tutuldu, birebir kopya değildir.

// Deterministik sprey deseni üretici: [yatay, dikey] derece cinsinden.
function makePattern(kind, count) {
  const p = [];
  for (let i = 0; i < count; i++) {
    let x = 0;
    let y = 0;
    if (kind === 'ak') {
      y = i < 4 ? 0.95 + i * 0.13 : Math.max(0.30, 1.45 - (i - 4) * 0.07);
      if (i < 5) x = i % 2 ? 0.06 : -0.05;
      else if (i < 11) x = -(0.22 + (i - 5) * 0.09);
      else if (i < 18) x = 0.30 + (i - 11) * 0.07;
      else x = (i % 2 ? 1 : -1) * (0.22 + 0.05 * ((i - 18) % 4));
    } else if (kind === 'm4') {
      y = i < 4 ? 0.80 + i * 0.11 : Math.max(0.26, 1.22 - (i - 4) * 0.06);
      if (i < 5) x = i % 2 ? 0.05 : -0.04;
      else if (i < 12) x = 0.20 + (i - 5) * 0.07;
      else if (i < 19) x = -(0.26 + (i - 12) * 0.06);
      else x = (i % 2 ? -1 : 1) * (0.20 + 0.04 * ((i - 19) % 4));
    } else if (kind === 'smg') {
      y = i < 3 ? 0.55 + i * 0.10 : Math.max(0.20, 0.85 - (i - 3) * 0.035);
      x = (i % 2 ? 1 : -1) * (0.10 + 0.03 * (i % 5));
    } else if (kind === 'pistol') {
      y = 1.05;
      x = (i % 2 ? 1 : -1) * 0.16;
    } else {
      y = 1.6;
      x = (i % 2 ? 1 : -1) * 0.2;
    }
    p.push([x, y]);
  }
  return p;
}

function weapon(def) {
  return {
    type: 'rifle',
    slot: 'primary',
    auto: true,
    price: 0,
    killReward: 300,
    damage: 30,
    armorPen: 0.7,
    rpm: 600,
    mag: 30,
    reserve: 90,
    reloadTime: 2.5,
    deployTime: 1.0,
    falloff: 0.9945,      // hasar = hasar * falloff^mesafe(m)
    penetration: 0.5,     // duvar delme kabiliyeti (0 = yok)
    speedMul: 0.9,
    recoilRecovery: 7.5,
    recoilScale: 1.0,
    zoom: null,
    spread: { stand: 0.035, move: 1.05, air: 5.0, crouchMul: 0.72, bloom: 0.18, bloomMax: 2.4 },
    ...def,
  };
}

export const WEAPONS = {
  knife: weapon({
    id: 'knife', name: 'Bıçak', type: 'knife', slot: 'melee', auto: false,
    damage: 42, backstab: 180, armorPen: 0.85, rpm: 160, mag: -1, reserve: -1,
    reloadTime: 0, deployTime: 0.5, range: 1.6, speedMul: 1.0, killReward: 1500,
    spread: { stand: 0, move: 0, air: 0, crouchMul: 1, bloom: 0, bloomMax: 0 },
  }),
  glock: weapon({
    id: 'glock', name: 'Glock-18', type: 'pistol', slot: 'secondary', auto: false,
    price: 0, damage: 30, armorPen: 0.47, rpm: 400, mag: 20, reserve: 120,
    reloadTime: 2.2, deployTime: 0.7, falloff: 0.9885, penetration: 0.2,
    speedMul: 1.0, killReward: 300, recoilScale: 0.6,
    spread: { stand: 0.08, move: 0.9, air: 4.0, crouchMul: 0.75, bloom: 0.35, bloomMax: 3.0 },
    pattern: makePattern('pistol', 20),
  }),
  usp: weapon({
    id: 'usp', name: 'USP-S', type: 'pistol', slot: 'secondary', auto: false,
    price: 0, damage: 35, armorPen: 0.505, rpm: 352, mag: 12, reserve: 24,
    reloadTime: 2.2, deployTime: 0.7, falloff: 0.9875, penetration: 0.25,
    speedMul: 1.0, killReward: 300, recoilScale: 0.55, silenced: true,
    spread: { stand: 0.05, move: 0.85, air: 3.8, crouchMul: 0.75, bloom: 0.30, bloomMax: 2.6 },
    pattern: makePattern('pistol', 12),
  }),
  p250: weapon({
    id: 'p250', name: 'P250', type: 'pistol', slot: 'secondary', auto: false,
    price: 300, damage: 38, armorPen: 0.645, rpm: 400, mag: 13, reserve: 26,
    reloadTime: 2.2, deployTime: 0.7, falloff: 0.9855, penetration: 0.3,
    speedMul: 1.0, killReward: 300, recoilScale: 0.6,
    spread: { stand: 0.07, move: 0.9, air: 4.2, crouchMul: 0.75, bloom: 0.34, bloomMax: 2.8 },
    pattern: makePattern('pistol', 13),
  }),
  deagle: weapon({
    id: 'deagle', name: 'Desert Eagle', type: 'pistol', slot: 'secondary', auto: false,
    price: 700, damage: 63, armorPen: 0.93, rpm: 267, mag: 7, reserve: 35,
    reloadTime: 2.2, deployTime: 0.9, falloff: 0.9905, penetration: 0.6,
    speedMul: 0.98, killReward: 300, recoilScale: 1.5, recoilRecovery: 5.5,
    spread: { stand: 0.09, move: 2.4, air: 8.0, crouchMul: 0.7, bloom: 0.9, bloomMax: 5.0 },
    pattern: makePattern('heavy', 7),
  }),
  mac10: weapon({
    id: 'mac10', name: 'MAC-10', type: 'smg', price: 1050, damage: 29, armorPen: 0.475,
    rpm: 800, mag: 30, reserve: 100, reloadTime: 2.3, deployTime: 0.8,
    falloff: 0.982, penetration: 0.25, speedMul: 0.96, killReward: 600, recoilScale: 0.75,
    spread: { stand: 0.10, move: 0.55, air: 4.2, crouchMul: 0.75, bloom: 0.22, bloomMax: 2.6 },
    pattern: makePattern('smg', 30), team: 'T',
  }),
  mp9: weapon({
    id: 'mp9', name: 'MP9', type: 'smg', price: 1250, damage: 26, armorPen: 0.60,
    rpm: 857, mag: 30, reserve: 120, reloadTime: 2.1, deployTime: 0.75,
    falloff: 0.982, penetration: 0.25, speedMul: 0.97, killReward: 600, recoilScale: 0.7,
    spread: { stand: 0.09, move: 0.5, air: 4.0, crouchMul: 0.75, bloom: 0.20, bloomMax: 2.4 },
    pattern: makePattern('smg', 30), team: 'CT',
  }),
  galil: weapon({
    id: 'galil', name: 'Galil AR', type: 'rifle', price: 1800, damage: 30, armorPen: 0.775,
    rpm: 666, mag: 35, reserve: 90, reloadTime: 3.0, deployTime: 1.0,
    falloff: 0.9948, penetration: 0.5, speedMul: 0.91, killReward: 300, recoilScale: 1.05,
    spread: { stand: 0.045, move: 1.15, air: 5.4, crouchMul: 0.72, bloom: 0.20, bloomMax: 2.6 },
    pattern: makePattern('ak', 35), team: 'T',
  }),
  famas: weapon({
    id: 'famas', name: 'FAMAS', type: 'rifle', price: 2050, damage: 30, armorPen: 0.70,
    rpm: 666, mag: 25, reserve: 90, reloadTime: 3.3, deployTime: 1.0,
    falloff: 0.9948, penetration: 0.5, speedMul: 0.91, killReward: 300, recoilScale: 1.0,
    spread: { stand: 0.045, move: 1.10, air: 5.2, crouchMul: 0.72, bloom: 0.20, bloomMax: 2.6 },
    pattern: makePattern('m4', 25), team: 'CT',
  }),
  ak47: weapon({
    id: 'ak47', name: 'AK-47', type: 'rifle', price: 2700, damage: 36, armorPen: 0.775,
    rpm: 600, mag: 30, reserve: 90, reloadTime: 2.5, deployTime: 1.0,
    falloff: 0.9849, penetration: 0.6, speedMul: 0.88, killReward: 300, recoilScale: 1.15,
    spread: { stand: 0.035, move: 1.20, air: 5.6, crouchMul: 0.70, bloom: 0.18, bloomMax: 2.6 },
    pattern: makePattern('ak', 30), team: 'T',
  }),
  m4a4: weapon({
    id: 'm4a4', name: 'M4A4', type: 'rifle', price: 3100, damage: 33, armorPen: 0.70,
    rpm: 666, mag: 30, reserve: 90, reloadTime: 3.1, deployTime: 1.0,
    falloff: 0.9881, penetration: 0.55, speedMul: 0.89, killReward: 300, recoilScale: 0.95,
    spread: { stand: 0.032, move: 1.10, air: 5.2, crouchMul: 0.70, bloom: 0.17, bloomMax: 2.4 },
    pattern: makePattern('m4', 30), team: 'CT',
  }),
  awp: weapon({
    id: 'awp', name: 'AWP', type: 'sniper', price: 4750, damage: 115, armorPen: 0.975,
    rpm: 41, mag: 10, reserve: 30, reloadTime: 3.7, deployTime: 1.3, auto: false,
    falloff: 0.99, penetration: 0.9, speedMul: 0.84, killReward: 100, recoilScale: 2.2,
    recoilRecovery: 4.0, zoom: [40, 15],
    spread: { stand: 0.02, move: 8.0, air: 12.0, crouchMul: 0.8, bloom: 1.0, bloomMax: 8.0 },
    pattern: makePattern('heavy', 10),
  }),
  ssg08: weapon({
    id: 'ssg08', name: 'SSG 08', type: 'sniper', price: 1700, damage: 88, armorPen: 0.85,
    rpm: 75, mag: 10, reserve: 90, reloadTime: 3.7, deployTime: 1.1, auto: false,
    falloff: 0.9971, penetration: 0.85, speedMul: 0.96, killReward: 300, recoilScale: 1.4,
    zoom: [40, 15],
    spread: { stand: 0.02, move: 6.0, air: 10.0, crouchMul: 0.8, bloom: 0.8, bloomMax: 6.0 },
    pattern: makePattern('heavy', 10),
  }),
  he: weapon({
    id: 'he', name: 'HE Bombası', type: 'grenade', kind: 'he', slot: 'grenade', price: 300,
    damage: 98, radius: 7.0, fuse: 1.7, auto: false, mag: 1, reserve: 0,
    speedMul: 1.0, killReward: 300, deployTime: 0.6,
    spread: { stand: 0, move: 0, air: 0, crouchMul: 1, bloom: 0, bloomMax: 0 },
  }),
  flash: weapon({
    id: 'flash', name: 'Flaş Bombası', type: 'grenade', kind: 'flash', slot: 'grenade', price: 200,
    damage: 0, radius: 14, fuse: 1.6, auto: false, mag: 1, reserve: 0,
    blindMax: 4.2, speedMul: 1.0, killReward: 300, deployTime: 0.6,
    spread: { stand: 0, move: 0, air: 0, crouchMul: 1, bloom: 0, bloomMax: 0 },
  }),
  smoke: weapon({
    id: 'smoke', name: 'Sis Bombası', type: 'grenade', kind: 'smoke', slot: 'grenade', price: 300,
    damage: 0, radius: 4.6, fuse: 1.9, duration: 16, auto: false, mag: 1, reserve: 0,
    speedMul: 1.0, killReward: 300, deployTime: 0.6,
    spread: { stand: 0, move: 0, air: 0, crouchMul: 1, bloom: 0, bloomMax: 0 },
  }),
  molotov: weapon({
    id: 'molotov', name: 'Molotof', type: 'grenade', kind: 'fire', slot: 'grenade', price: 400,
    damage: 0, radius: 2.9, duration: 7, dps: 33, fuse: 0, impact: true, auto: false,
    mag: 1, reserve: 0, speedMul: 1.0, killReward: 300, deployTime: 0.6, team: 'T',
    spread: { stand: 0, move: 0, air: 0, crouchMul: 1, bloom: 0, bloomMax: 0 },
  }),
  incendiary: weapon({
    id: 'incendiary', name: 'Yangın Bombası', type: 'grenade', kind: 'fire', slot: 'grenade', price: 600,
    damage: 0, radius: 2.9, duration: 7, dps: 33, fuse: 0, impact: true, auto: false,
    mag: 1, reserve: 0, speedMul: 1.0, killReward: 300, deployTime: 0.6, team: 'CT',
    spread: { stand: 0, move: 0, air: 0, crouchMul: 1, bloom: 0, bloomMax: 0 },
  }),
};

export const MAX_GRENADES = 3;

export const KEVLAR_PRICE = 650;
export const HELMET_PRICE = 1000;
export const DEFUSE_KIT_PRICE = 400;

// Satın alma menüsü düzeni (takıma göre filtrelenir).
export const BUY_MENU = [
  { key: '1', kind: 'weapon', id: 'p250' },
  { key: '2', kind: 'weapon', id: 'deagle' },
  { key: '3', kind: 'weapon', id: 'mp9', team: 'CT' },
  { key: '3', kind: 'weapon', id: 'mac10', team: 'T' },
  { key: '4', kind: 'weapon', id: 'famas', team: 'CT' },
  { key: '4', kind: 'weapon', id: 'galil', team: 'T' },
  { key: '5', kind: 'weapon', id: 'm4a4', team: 'CT' },
  { key: '5', kind: 'weapon', id: 'ak47', team: 'T' },
  { key: '6', kind: 'weapon', id: 'ssg08' },
  { key: '7', kind: 'weapon', id: 'awp' },
  { key: '8', kind: 'armor' },
  { key: '9', kind: 'helmet' },
  { key: 'g', kind: 'grenade', id: 'he' },
  { key: 'f', kind: 'grenade', id: 'flash' },
  { key: 's', kind: 'grenade', id: 'smoke' },
  { key: 'm', kind: 'grenade', id: 'molotov', team: 'T' },
  { key: 'm', kind: 'grenade', id: 'incendiary', team: 'CT' },
  { key: 'k', kind: 'kit', team: 'CT' },
];

export function weaponsForTeam(team) {
  return BUY_MENU.filter((e) => !e.team || e.team === team);
}

export function cycleTime(w) {
  return 60 / w.rpm;
}
