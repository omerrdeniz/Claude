// Giriş noktası: menü, ayarlar ve ana döngü.

import { Game } from './game.js';
import { DEFAULT_SETTINGS } from './config.js';

const canvas = document.getElementById('game');
const menu = document.getElementById('menu');
const setupSection = document.getElementById('setup-section');
const btnStart = document.getElementById('btn-start');
const btnRestart = document.getElementById('btn-restart');
const fpsEl = document.getElementById('fps');

const els = {
  team: document.getElementById('opt-team'),
  difficulty: document.getElementById('opt-difficulty'),
  teamsize: document.getElementById('opt-teamsize'),
  sens: document.getElementById('opt-sens'),
  fov: document.getElementById('opt-fov'),
  vol: document.getElementById('opt-vol'),
  shadows: document.getElementById('opt-shadows'),
  valSens: document.getElementById('val-sens'),
  valFov: document.getElementById('val-fov'),
  valVol: document.getElementById('val-vol'),
};

const STORAGE_KEY = 'cs2js.settings';

function loadSettings() {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return { ...DEFAULT_SETTINGS };
    return { ...DEFAULT_SETTINGS, ...JSON.parse(raw) };
  } catch {
    return { ...DEFAULT_SETTINGS };
  }
}

function saveSettings(s) {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(s));
  } catch {
    /* depolama kapalıysa sorun değil */
  }
}

const settings = loadSettings();
els.sens.value = settings.sensitivity;
els.fov.value = settings.fov;
els.vol.value = Math.round(settings.volume * 100);
els.shadows.checked = settings.shadows;
els.difficulty.value = String(settings.botDifficulty);
els.valSens.textContent = Number(settings.sensitivity).toFixed(1);
els.valFov.textContent = settings.fov;
els.valVol.textContent = Math.round(settings.volume * 100);

let game;
try {
  game = new Game(canvas, settings);
} catch (err) {
  console.error(err);
  menu.innerHTML = `<div class="menu-card"><h1>Hata</h1>
    <p class="sub">WebGL başlatılamadı. Tarayıcınızın donanım hızlandırmasını açın.</p>
    <pre style="text-align:left;font-size:11px;white-space:pre-wrap">${String(err && err.message || err)}</pre></div>`;
  throw err;
}

let matchStarted = false;

function readSettingsFromUI() {
  settings.sensitivity = parseFloat(els.sens.value);
  settings.fov = parseInt(els.fov.value, 10);
  settings.volume = parseInt(els.vol.value, 10) / 100;
  settings.shadows = els.shadows.checked;
  settings.botDifficulty = parseInt(els.difficulty.value, 10);
  saveSettings(settings);
  game.applySettings(settings);
}

for (const el of [els.sens, els.fov, els.vol, els.shadows, els.difficulty]) {
  el.addEventListener('input', () => {
    els.valSens.textContent = Number(els.sens.value).toFixed(1);
    els.valFov.textContent = els.fov.value;
    els.valVol.textContent = els.vol.value;
    readSettingsFromUI();
  });
}

function showMenu(resumeLabel) {
  menu.classList.remove('hidden');
  btnStart.textContent = resumeLabel;
  setupSection.classList.toggle('hidden', matchStarted);
  btnRestart.classList.toggle('hidden', !matchStarted);
  game.paused = true;
}

function hideMenu() {
  menu.classList.add('hidden');
  game.paused = false;
}

game.onMenuRequest = () => showMenu('DEVAM ET');

btnStart.addEventListener('click', () => {
  readSettingsFromUI();
  game.audio.resume();
  if (!matchStarted) {
    game.createMatch({
      team: els.team.value,
      teamSize: parseInt(els.teamsize.value, 10),
      difficulty: parseInt(els.difficulty.value, 10),
    });
    matchStarted = true;
    game.running = true;
  }
  hideMenu();
  game.input.requestLock();
});

btnRestart.addEventListener('click', () => {
  readSettingsFromUI();
  game.audio.resume();
  game.restartMatch();
  hideMenu();
  game.input.requestLock();
});

canvas.addEventListener('click', () => {
  if (matchStarted && !menu.classList.contains('hidden')) return;
  if (matchStarted && !game.input.locked) {
    game.audio.resume();
    game.input.requestLock();
    game.paused = false;
  }
});

// Ana döngü
let last = performance.now();
let fpsAccum = 0;
let fpsFrames = 0;

function loop(now) {
  const dt = (now - last) / 1000;
  last = now;
  game.frame(dt);

  fpsAccum += dt;
  fpsFrames++;
  if (fpsAccum >= 0.5) {
    const fps = Math.round(fpsFrames / fpsAccum);
    fpsEl.textContent = `${fps} fps`;
    fpsAccum = 0;
    fpsFrames = 0;
  }
  requestAnimationFrame(loop);
}
requestAnimationFrame(loop);

// Hata ayıklama / otomatik test için
window.__game = game;
window.__startMatch = (opts = {}) => {
  game.createMatch({
    team: opts.team || els.team.value,
    teamSize: opts.teamSize || parseInt(els.teamsize.value, 10),
    difficulty: opts.difficulty ?? parseInt(els.difficulty.value, 10),
  });
  matchStarted = true;
  game.running = true;
  hideMenu();
};
