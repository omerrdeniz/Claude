// Görsel efektler: iz (tracer), mermi izleri, kan, namlu alevi, patlama.
// Tüm nesneler havuzlanır; kare başına yeni allocation yapılmaz.

import * as THREE from 'three';

function sprite(color, size) {
  const canvas = document.createElement('canvas');
  canvas.width = canvas.height = 64;
  const ctx = canvas.getContext('2d');
  const grad = ctx.createRadialGradient(32, 32, 0, 32, 32, 32);
  grad.addColorStop(0, color);
  grad.addColorStop(1, 'rgba(0,0,0,0)');
  ctx.fillStyle = grad;
  ctx.fillRect(0, 0, 64, 64);
  const tex = new THREE.CanvasTexture(canvas);
  tex.colorSpace = THREE.SRGBColorSpace;
  const mat = new THREE.SpriteMaterial({ map: tex, transparent: true, depthWrite: false });
  const s = new THREE.Sprite(mat);
  s.scale.setScalar(size);
  return s;
}

function decalTexture() {
  const canvas = document.createElement('canvas');
  canvas.width = canvas.height = 32;
  const ctx = canvas.getContext('2d');
  const grad = ctx.createRadialGradient(16, 16, 1, 16, 16, 15);
  grad.addColorStop(0, 'rgba(15,12,10,0.95)');
  grad.addColorStop(0.55, 'rgba(30,26,22,0.55)');
  grad.addColorStop(1, 'rgba(0,0,0,0)');
  ctx.fillStyle = grad;
  ctx.fillRect(0, 0, 32, 32);
  const tex = new THREE.CanvasTexture(canvas);
  tex.colorSpace = THREE.SRGBColorSpace;
  return tex;
}

export class Effects {
  constructor(scene) {
    this.scene = scene;
    this.time = 0;

    // Tracer havuzu
    this.tracers = [];
    const tracerGeo = new THREE.BoxGeometry(1, 1, 1);
    for (let i = 0; i < 48; i++) {
      const mat = new THREE.MeshBasicMaterial({
        color: 0xffe6a0, transparent: true, opacity: 0, depthWrite: false, blending: THREE.AdditiveBlending,
      });
      const mesh = new THREE.Mesh(tracerGeo, mat);
      mesh.visible = false;
      mesh.frustumCulled = false;
      scene.add(mesh);
      this.tracers.push({ mesh, mat, life: 0, maxLife: 0.08 });
    }
    this.tracerIndex = 0;

    // Mermi izi (decal) havuzu
    this.decals = [];
    const decalGeo = new THREE.PlaneGeometry(0.16, 0.16);
    const decalTex = decalTexture();
    for (let i = 0; i < 80; i++) {
      const mat = new THREE.MeshBasicMaterial({
        map: decalTex, transparent: true, opacity: 0, depthWrite: false, polygonOffset: true, polygonOffsetFactor: -2,
      });
      const mesh = new THREE.Mesh(decalGeo, mat);
      mesh.visible = false;
      scene.add(mesh);
      this.decals.push({ mesh, mat, life: 0 });
    }
    this.decalIndex = 0;

    // Kıvılcım / kan parçacıkları
    this.particles = [];
    for (let i = 0; i < 60; i++) {
      const s = sprite('rgba(255,255,255,0.9)', 0.12);
      s.visible = false;
      scene.add(s);
      this.particles.push({ sprite: s, life: 0, maxLife: 0.5, vel: new THREE.Vector3(), gravity: 8 });
    }
    this.particleIndex = 0;

    // Namlu alevi
    this.flashes = [];
    for (let i = 0; i < 8; i++) {
      const s = sprite('rgba(255,224,150,0.95)', 0.5);
      s.visible = false;
      s.material.blending = THREE.AdditiveBlending;
      scene.add(s);
      this.flashes.push({ sprite: s, life: 0 });
    }
    this.flashIndex = 0;
    this.flashLight = new THREE.PointLight(0xffcc77, 0, 12, 2);
    scene.add(this.flashLight);
    this.flashLightLife = 0;

    // Kovanlar
    this.shells = [];
    const shellGeo = new THREE.BoxGeometry(0.012, 0.012, 0.032);
    const shellMat = new THREE.MeshStandardMaterial({ color: 0xc59a3c, roughness: 0.35, metalness: 0.95 });
    for (let i = 0; i < 24; i++) {
      const mesh = new THREE.Mesh(shellGeo, shellMat);
      mesh.visible = false;
      mesh.castShadow = true;
      scene.add(mesh);
      this.shells.push({ mesh, life: 0, vel: new THREE.Vector3(), spin: new THREE.Vector3() });
    }
    this.shellIndex = 0;

    // Patlama
    this.explosions = [];
    const sphereGeo = new THREE.SphereGeometry(1, 12, 8);
    for (let i = 0; i < 4; i++) {
      const mat = new THREE.MeshBasicMaterial({
        color: 0xffa040, transparent: true, opacity: 0, depthWrite: false, blending: THREE.AdditiveBlending,
      });
      const mesh = new THREE.Mesh(sphereGeo, mat);
      mesh.visible = false;
      scene.add(mesh);
      this.explosions.push({ mesh, mat, life: 0 });
    }
    this.explosionIndex = 0;
  }

  tracer(from, to, width = 0.03) {
    const t = this.tracers[this.tracerIndex];
    this.tracerIndex = (this.tracerIndex + 1) % this.tracers.length;
    const dir = new THREE.Vector3().subVectors(to, from);
    const len = dir.length();
    if (len < 0.05) return;
    const mid = new THREE.Vector3().addVectors(from, to).multiplyScalar(0.5);
    t.mesh.position.copy(mid);
    t.mesh.scale.set(width, width, len);
    t.mesh.lookAt(to);
    t.mesh.visible = true;
    t.mat.opacity = 0.85;
    t.life = t.maxLife;
  }

  decal(point, normal) {
    const d = this.decals[this.decalIndex];
    this.decalIndex = (this.decalIndex + 1) % this.decals.length;
    d.mesh.position.set(point.x + normal.x * 0.012, point.y + normal.y * 0.012, point.z + normal.z * 0.012);
    const lookAt = new THREE.Vector3(
      d.mesh.position.x + normal.x,
      d.mesh.position.y + normal.y,
      d.mesh.position.z + normal.z,
    );
    d.mesh.lookAt(lookAt);
    d.mesh.rotation.z = Math.random() * Math.PI;
    d.mesh.visible = true;
    d.mat.opacity = 0.9;
    d.life = 12;
  }

  burst(point, normal, color, count = 6, speed = 3, size = 0.1) {
    for (let i = 0; i < count; i++) {
      const p = this.particles[this.particleIndex];
      this.particleIndex = (this.particleIndex + 1) % this.particles.length;
      p.sprite.position.copy(point);
      p.sprite.material.color.set(color);
      p.sprite.scale.setScalar(size * (0.6 + Math.random() * 0.8));
      p.sprite.visible = true;
      p.sprite.material.opacity = 0.95;
      p.vel.set(
        normal.x * speed * (0.4 + Math.random()) + (Math.random() - 0.5) * speed,
        normal.y * speed * (0.4 + Math.random()) + Math.random() * speed * 0.6,
        normal.z * speed * (0.4 + Math.random()) + (Math.random() - 0.5) * speed,
      );
      p.life = 0.35 + Math.random() * 0.3;
      p.maxLife = p.life;
    }
  }

  // Boş kovan fırlat
  shell(pos, right, up) {
    const s = this.shells[this.shellIndex];
    this.shellIndex = (this.shellIndex + 1) % this.shells.length;
    s.mesh.position.copy(pos);
    s.mesh.visible = true;
    s.vel.set(
      right.x * (1.8 + Math.random()) + up.x * 1.2,
      right.y * (1.8 + Math.random()) + up.y * 1.2 + 1.4,
      right.z * (1.8 + Math.random()) + up.z * 1.2,
    );
    s.spin.set(Math.random() * 18, Math.random() * 18, Math.random() * 18);
    s.life = 2.2;
  }

  impact(point, normal, mat) {
    this.decal(point, normal);
    const color = mat === 'metal' ? 0xffd9a0 : (mat === 'wood' ? 0xb08040 : 0xcfcabc);
    this.burst(point, normal, color, 5, 2.5, 0.07);
  }

  blood(point, normal) {
    this.burst(point, normal, 0x9b1414, 8, 2.2, 0.13);
  }

  muzzleFlash(pos, dir) {
    const f = this.flashes[this.flashIndex];
    this.flashIndex = (this.flashIndex + 1) % this.flashes.length;
    f.sprite.position.set(pos.x + dir.x * 0.4, pos.y + dir.y * 0.4, pos.z + dir.z * 0.4);
    f.sprite.scale.setScalar(0.45 + Math.random() * 0.2);
    f.sprite.visible = true;
    f.sprite.material.opacity = 1;
    f.life = 0.05;
    this.flashLight.position.copy(f.sprite.position);
    this.flashLight.intensity = 8;
    this.flashLightLife = 0.06;
  }

  // Flaş bombası: çok parlak kısa süreli küre
  flashBurst(pos) {
    const e = this.explosions[this.explosionIndex];
    this.explosionIndex = (this.explosionIndex + 1) % this.explosions.length;
    e.mesh.position.copy(pos);
    e.mesh.scale.setScalar(0.4);
    e.mesh.visible = true;
    e.mat.color.setHex(0xffffff);
    e.mat.opacity = 1;
    e.life = 0.3;
    this.flashLight.position.copy(pos);
    this.flashLight.color.setHex(0xffffff);
    this.flashLight.intensity = 60;
    this.flashLightLife = 0.35;
  }

  explosion(pos) {
    const e = this.explosions[this.explosionIndex];
    this.explosionIndex = (this.explosionIndex + 1) % this.explosions.length;
    e.mesh.position.copy(pos);
    e.mesh.scale.setScalar(0.6);
    e.mesh.visible = true;
    e.mat.color.setHex(0xffa040);
    e.mat.opacity = 0.95;
    e.life = 0.45;
    this.flashLight.position.copy(pos);
    this.flashLight.color.setHex(0xffcc77);
    this.flashLight.intensity = 30;
    this.flashLightLife = 0.25;
    this.burst(pos, new THREE.Vector3(0, 1, 0), 0x555555, 14, 7, 0.5);
  }

  update(dt) {
    this.time += dt;
    for (const t of this.tracers) {
      if (t.life <= 0) continue;
      t.life -= dt;
      t.mat.opacity = Math.max(0, t.life / t.maxLife) * 0.85;
      if (t.life <= 0) t.mesh.visible = false;
    }
    for (const d of this.decals) {
      if (d.life <= 0) continue;
      d.life -= dt;
      if (d.life < 2) d.mat.opacity = Math.max(0, d.life / 2) * 0.9;
      if (d.life <= 0) d.mesh.visible = false;
    }
    for (const p of this.particles) {
      if (p.life <= 0) continue;
      p.life -= dt;
      p.vel.y -= p.gravity * dt;
      p.sprite.position.addScaledVector(p.vel, dt);
      p.sprite.material.opacity = Math.max(0, p.life / p.maxLife);
      if (p.life <= 0) p.sprite.visible = false;
    }
    for (const f of this.flashes) {
      if (f.life <= 0) continue;
      f.life -= dt;
      f.sprite.material.opacity = Math.max(0, f.life / 0.05);
      if (f.life <= 0) f.sprite.visible = false;
    }
    if (this.flashLightLife > 0) {
      this.flashLightLife -= dt;
      this.flashLight.intensity *= Math.max(0, 1 - dt * 12);
      if (this.flashLightLife <= 0) this.flashLight.intensity = 0;
    }
    for (const s of this.shells) {
      if (s.life <= 0) continue;
      s.life -= dt;
      s.vel.y -= 12 * dt;
      s.mesh.position.addScaledVector(s.vel, dt);
      s.mesh.rotation.x += s.spin.x * dt;
      s.mesh.rotation.y += s.spin.y * dt;
      s.mesh.rotation.z += s.spin.z * dt;
      if (s.mesh.position.y < 0.012) {
        s.mesh.position.y = 0.012;
        s.vel.set(s.vel.x * 0.4, -s.vel.y * 0.25, s.vel.z * 0.4);
        s.spin.multiplyScalar(0.4);
      }
      if (s.life <= 0) s.mesh.visible = false;
    }
    for (const e of this.explosions) {
      if (e.life <= 0) continue;
      e.life -= dt;
      const k = 1 - Math.max(0, e.life) / 0.45;
      e.mesh.scale.setScalar(0.6 + k * 5);
      e.mat.opacity = Math.max(0, 1 - k) * 0.9;
      if (e.life <= 0) e.mesh.visible = false;
    }
  }
}
