// Üstten görünüm mini harita (kuzey yukarı).

export class Radar {
  constructor(canvas, world) {
    this.canvas = canvas;
    this.ctx = canvas.getContext('2d');
    this.world = world;
    const b = world.bounds;
    this.minX = b.minX - 2;
    this.maxX = b.maxX + 2;
    this.minZ = b.minZ - 2;
    this.maxZ = b.maxZ + 2;
    const w = this.maxX - this.minX;
    const h = this.maxZ - this.minZ;
    this.scale = Math.min(canvas.width / w, canvas.height / h);
    this.offX = (canvas.width - w * this.scale) / 2;
    this.offZ = (canvas.height - h * this.scale) / 2;
    this.walls = world.colliders.filter((c) => !c.ground && c.maxY >= 3.5);
    this.props = world.colliders.filter((c) => !c.ground && c.maxY < 3.5 && c.maxY > 0.5);
  }

  px(x) { return this.offX + (x - this.minX) * this.scale; }
  pz(z) { return this.offZ + (z - this.minZ) * this.scale; }

  draw(game) {
    const ctx = this.ctx;
    const c = this.canvas;
    ctx.clearRect(0, 0, c.width, c.height);

    // Zemin
    ctx.fillStyle = 'rgba(28, 33, 40, 0.85)';
    ctx.fillRect(this.px(this.minX), this.pz(this.minZ),
      (this.maxX - this.minX) * this.scale, (this.maxZ - this.minZ) * this.scale);

    // Duvarlar
    ctx.fillStyle = 'rgba(126, 134, 146, 0.85)';
    for (const w of this.walls) {
      ctx.fillRect(this.px(w.minX), this.pz(w.minZ),
        Math.max(1, (w.maxX - w.minX) * this.scale),
        Math.max(1, (w.maxZ - w.minZ) * this.scale));
    }
    // Kapaklar / kasalar
    ctx.fillStyle = 'rgba(96, 104, 116, 0.55)';
    for (const w of this.props) {
      ctx.fillRect(this.px(w.minX), this.pz(w.minZ),
        Math.max(1, (w.maxX - w.minX) * this.scale),
        Math.max(1, (w.maxZ - w.minZ) * this.scale));
    }

    // Bombasahaları
    ctx.strokeStyle = 'rgba(232, 97, 60, 0.9)';
    ctx.fillStyle = 'rgba(232, 97, 60, 0.85)';
    ctx.lineWidth = 1;
    ctx.font = 'bold 11px Arial';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    for (const key of ['A', 'B']) {
      const s = this.world.sites[key];
      ctx.strokeRect(this.px(s.minX), this.pz(s.minZ),
        (s.maxX - s.minX) * this.scale, (s.maxZ - s.minZ) * this.scale);
      ctx.fillText(key, this.px(s.center.x), this.pz(s.center.z));
    }

    const player = game.player;

    // Bomba
    const round = game.round;
    if (round.bombPlanted) {
      const x = this.px(round.bombPos.x);
      const z = this.pz(round.bombPos.z);
      ctx.fillStyle = Math.floor(game.time * 4) % 2 ? '#ff3b30' : '#ffd166';
      ctx.beginPath();
      ctx.arc(x, z, 4, 0, Math.PI * 2);
      ctx.fill();
    } else if (round.bombCarrier && round.bombCarrier.alive && player && round.bombCarrier.team === player.team) {
      const x = this.px(round.bombCarrier.pos.x);
      const z = this.pz(round.bombCarrier.pos.z);
      ctx.fillStyle = '#ffd166';
      ctx.beginPath();
      ctx.arc(x, z, 5.5, 0, Math.PI * 2);
      ctx.fill();
    }

    // Oyuncular
    for (const a of game.actors) {
      if (!a.alive) continue;
      const isTeammate = player && a.team === player.team;
      const spotted = game.spotted.has(a.id);
      if (!isTeammate && !spotted) continue;
      const x = this.px(a.pos.x);
      const z = this.pz(a.pos.z);
      if (a === player) continue;
      ctx.fillStyle = isTeammate ? (a.team === 'CT' ? '#6ba4e8' : '#e0a743') : '#ff453a';
      ctx.beginPath();
      ctx.arc(x, z, 3.2, 0, Math.PI * 2);
      ctx.fill();
      // Bakış yönü
      ctx.strokeStyle = ctx.fillStyle;
      ctx.beginPath();
      ctx.moveTo(x, z);
      ctx.lineTo(x - Math.sin(a.yaw) * 7, z - Math.cos(a.yaw) * 7);
      ctx.stroke();
    }

    // Oyuncunun kendisi
    if (player) {
      const x = this.px(player.pos.x);
      const z = this.pz(player.pos.z);
      ctx.save();
      ctx.translate(x, z);
      ctx.rotate(-player.yaw);
      ctx.fillStyle = player.alive ? '#3ee07a' : '#888';
      ctx.beginPath();
      ctx.moveTo(0, -6);
      ctx.lineTo(4.5, 5);
      ctx.lineTo(0, 2.5);
      ctx.lineTo(-4.5, 5);
      ctx.closePath();
      ctx.fill();
      ctx.restore();
    }
  }
}
