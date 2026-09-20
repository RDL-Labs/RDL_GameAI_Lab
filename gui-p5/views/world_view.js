/** 2D spatial projection. It never invents live positions. */
class WorldView {
  constructor(x, y, w, h) {
    this.bounds = { x, y, w, h };
    this.worldScale = 12;
    this.origin = { x: 30, y: 32 };
  }

  draw(p, data, selectedAgentId) {
    p.push();
    p.stroke(43, 56, 78); p.fill(17, 24, 39);
    p.rect(this.bounds.x, this.bounds.y, this.bounds.w, this.bounds.h, 6);
    p.noStroke(); p.fill(136, 153, 172); p.textSize(12);
    p.text('WORLD VIEW — bounded spatial projection', this.bounds.x + 12, this.bounds.y + 20);

    if (!data?.agents || !data?.objects) {
      p.fill(100); p.textSize(11);
      p.text('No live spatial snapshot is exposed by the current Runtime bridge.', this.bounds.x + 20, this.bounds.y + 58);
      p.fill(136, 153, 172); p.textSize(10);
      p.text('Viewer does not fabricate positions. Fixture mode contains a finite world projection.', this.bounds.x + 20, this.bounds.y + 78);
      p.pop(); return;
    }

    p.translate(this.bounds.x + this.origin.x, this.bounds.y + this.origin.y);
    p.stroke(26, 36, 52); p.strokeWeight(1);
    for (let gx = 0; gx < 36; gx += 5) p.line(gx * this.worldScale, 0, gx * this.worldScale, 27 * this.worldScale);
    for (let gy = 0; gy < 27; gy += 5) p.line(0, gy * this.worldScale, 36 * this.worldScale, gy * this.worldScale);

    for (const obj of data.objects) {
      if (!Array.isArray(obj.position)) continue;
      const ox = obj.position[0] * this.worldScale;
      const oy = obj.position[1] * this.worldScale;
      if (obj.type === 'base') {
        p.fill(52, 211, 153, 40); p.stroke(52, 211, 153); p.rect(ox - 16, oy - 16, 32, 32, 4);
        p.noStroke(); p.fill(52, 211, 153); p.textAlign(p.CENTER); p.textSize(9); p.text('BASE', ox, oy + 3);
      } else if (obj.type === 'danger') {
        const r = (obj.radius || 4) * this.worldScale;
        p.fill(248, 113, 113, 25); p.stroke(248, 113, 113, 150); p.circle(ox, oy, r * 2);
        p.noStroke(); p.fill(248, 113, 113); p.textAlign(p.CENTER); p.textSize(9); p.text('DANGER', ox, oy);
      } else if (obj.type === 'food') {
        p.noStroke(); p.fill(251, 191, 36); p.circle(ox, oy, 10);
      } else if (obj.type === 'bed') {
        p.fill(192, 132, 252, 50); p.stroke(192, 132, 252); p.rect(ox - 12, oy - 8, 24, 16, 2);
      }
    }

    for (const [id, agent] of Object.entries(data.agents)) {
      if (!Array.isArray(agent.position)) continue;
      const ax = agent.position[0] * this.worldScale;
      const ay = agent.position[1] * this.worldScale;
      const selected = id === selectedAgentId;
      if (selected) {
        p.noFill(); p.stroke(56, 189, 248, 180); p.strokeWeight(2); p.circle(ax, ay, 28);
        p.stroke(56, 189, 248, 40); p.strokeWeight(1); p.circle(ax, ay, 120);
      }
      p.strokeWeight(1.5); p.stroke(255); p.fill(id === 'npc_a' ? 56 : 251, id === 'npc_a' ? 189 : 146, id === 'npc_a' ? 248 : 60);
      p.circle(ax, ay, 18);
      p.noStroke(); p.fill(255); p.textSize(9); p.textAlign(p.CENTER); p.text(id.toUpperCase(), ax, ay + 20);
      if (agent.held) { p.fill(251, 191, 36); p.circle(ax + 8, ay - 8, 8); }
    }
    p.pop();
  }

  checkAgentClick(mx, my, data) {
    if (!data?.agents) return null;
    const relX = mx - (this.bounds.x + this.origin.x);
    const relY = my - (this.bounds.y + this.origin.y);
    for (const [id, agent] of Object.entries(data.agents)) {
      if (!Array.isArray(agent.position)) continue;
      const ax = agent.position[0] * this.worldScale;
      const ay = agent.position[1] * this.worldScale;
      if (Math.hypot(relX - ax, relY - ay) <= 16) return id;
    }
    return null;
  }
}