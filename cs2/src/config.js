// Oyun genelinde kullanılan sabitler.
// Ölçek: 1 birim = 1 metre. Değerler CS hareket modelinden (unit -> metre) çevrildi.

export const PHYS = {
  gravity: 15.24,        // 800 u/s^2
  jumpSpeed: 5.75,       // 301 u/s
  runSpeed: 4.8,         // 250 u/s
  walkSpeed: 2.4,        // shift ile yavaş yürüyüş
  crouchSpeed: 1.9,
  accelerate: 5.5,       // sv_accelerate
  airAccelerate: 12,     // sv_airaccelerate
  airWishSpeed: 0.6,     // havada ivmelenebilen maksimum hız (30 u/s)
  friction: 5.2,         // sv_friction
  stopSpeed: 1.4,        // 75 u/s
  stepHeight: 0.45,
  radius: 0.42,
  standHeight: 1.80,
  crouchHeight: 1.25,
  eyeHeight: 1.62,
  crouchEyeHeight: 1.08,
  crouchSpeedLerp: 7,
  fallSafeSpeed: 8.0,    // bu hızın altındaki düşüşler hasarsız
  fallDamageScale: 11,
  maxFallSpeed: 40,
};

export const HITBOX = {
  head: 4.0,
  chest: 1.0,
  stomach: 1.25,
  legs: 0.75,
};

export const ROUND = {
  freezeTime: 6,
  roundTime: 115,
  bombTime: 40,
  endTime: 5,
  plantTime: 3.2,
  defuseTime: 10,
  defuseTimeKit: 5,
  maxRounds: 24,         // MR12: 13 galibiyet, 12. rauntta taraf değişimi
  winScore: 13,
  halfTime: 12,
  teamSize: 5,
};

export const ECONOMY = {
  start: 800,
  max: 16000,
  winRound: 3250,
  winBombPlant: 800,
  winDefuse: 3500,
  lossBase: 1400,
  lossStep: 500,
  lossMax: 3400,
  plantBonus: 300,
  defuseBonus: 300,
  killAssistShare: 0,
};

export const DEFAULT_SETTINGS = {
  sensitivity: 2.2,      // CS ile aynı ölçek (m_yaw 0.022)
  fov: 90,
  shadows: true,
  volume: 0.6,
  botDifficulty: 2,      // 0=kolay 1=normal 2=zor 3=uzman
  showFps: false,
};

export const TEAM = { CT: 'CT', T: 'T' };

export const COLORS = {
  ct: 0x5b8bd0,
  ctDark: 0x2f4d78,
  t: 0xd9a441,
  tDark: 0x7a5a1e,
  sand: 0xc8b48a,
  sandDark: 0xa8946e,
  concrete: 0x9e9c96,
  wood: 0xa9793f,
  metal: 0x77797d,
  floor: 0xb9a684,
  sky: 0x9fc4e8,
};
