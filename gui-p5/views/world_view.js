/**
 * views/world_view.js - 2D Spatial & Interaction projection
 */
class WorldView {
  constructor(x, y, w, h) {
    this.bounds = { x, y, w, h };
    this.worldScale = 14; // pixels per world unit
    this.origin = { x: 30, y: 30 };
  }

  draw(p, data, selectedAgentId) {
    p.push();
    // Panel Background
    p.stroke(43, 56, 78);
    p.fill(17, 24, 39);
    p.rect(this.bounds.x, this.bounds.y, this.bounds.w, this.bounds.h, 6);

    // Panel Header
    p.noStroke();
    p.fill(136, 153, 172);
    p.textSize(12);
    p.text("WORLD VIEW (Spatial Projection)", this.bounds.x + 12, this.bounds.y + 20);

    p.translate(this.bounds.x + this.origin.x, this.bounds.y + this.origin.y);

    if (!data) {
      p.fill(100);
      p.text("No world data", 50, 50);
      p.pop();
      return;
    }

    // Draw grid lines
    p.stroke(26, 36, 52);
    p.strokeWeight(1);
    for (let gx = 0; gx < 35; gx += 5) {
      p.line(gx * this.worldScale, 0, gx * this.worldScale, 25 * this.worldScale);
    }
    for (let gy = 0; gy < 25; gy += 5) {
      p.line(0, gy * this.worldScale, 35 * this.worldScale, gy * this.worldScale);
    }

    // Draw Objects (Base, Danger, Beds, Food)
    if (data.objects) {
      for (const obj of data.objects) {
        const ox = obj.position[0] * this.worldScale;
        const oy = obj.position[1] * this.worldScale;

        if (obj.type === 'base') {
          p.fill(52, 211, 153, 40);
          p.stroke(52, 211, 153);
          p.rect(ox - 16, oy - 16, 32, 32, 4);
          p.noStroke();
          p.fill(52, 211, 153);
          p.textSize(10);
          p.textAlign(p.CENTER);
          p.text("BASE", ox, oy + 4);
        } else if (obj.type === 'danger') {
          const r = (obj.radius || 4.0) * this.worldScale;
          p.fill(248, 113, 113, 25);
          p.stroke(248, 113, 113, 150);
          p.circle(ox, oy, r * 2);
          p.noStroke();
          p.fill(248, 113, 113);
          p.textSize(10);
          p.textAlign(p.CENTER);
          p.text("DANGER", ox, oy);
        } else if (obj.type === 'food') {
          p.fill(251, 191, 36);
          p.noStroke();
          p.circle(ox, oy, 10);
          p.textSize(9);
          p.fill(200);
          p.textAlign(p.CENTER);
          p.text(obj.id, ox, oy - 8);
        } else if (obj.type === 'bed') {
          p.fill(192, 132, 252, 50);
          p.stroke(192, 132, 252);
          p.rect(ox - 12, oy - 8, 24, 16, 2);
          p.noStroke();
          p.fill(192, 132, 252);
          p.textSize(9);
          p.textAlign(p.CENTER);
          p.text("BED", ox, oy + 3);
        }
      }
    }

    // Draw Agents (NPC A, NPC B)
    if (data.agents) {
      for (const [id, agent] of Object.entries(data.agents)) {
        const ax = agent.position[0] * this.worldScale;
        const ay = agent.position[1] * this.worldScale;
        const isSelected = (id === selectedAgentId);

        // Selection ring
        if (isSelected) {
          p.noFill();
          p.stroke(56, 189, 248, 180);
          p.strokeWeight(2);
          p.circle(ax, ay, 28);

          // Bounded observation radius preview
          p.stroke(56, 189, 248, 40);
          p.strokeWeight(1);
          p.circle(ax, ay, 120);
        }

        // Agent body
        p.strokeWeight(1.5);
        p.stroke(255);
        if (id === 'npc_a') {
          p.fill(56, 189, 248); // Cyan for A
        } else {
          p.fill(251, 146, 60); // Orange for B
        }
        p.circle(ax, ay, 18);

        // Name tag
        p.noStroke();
        p.fill(255);
        p.textSize(10);
        p.textAlign(p.CENTER);
        p.text(id.toUpperCase(), ax, ay + 20);

        // Held item badge
        if (agent.held) {
          p.fill(251, 191, 36);
          p.circle(ax + 8, ay - 8, 8);
        }
      }
    }

    p.pop();
  }

  checkAgentClick(mx, my, data) {
    if (!data || !data.agents) return null;
    const relX = mx - (this.bounds.x + this.origin.x);
    const relY = my - (this.bounds.y + this.origin.y);

    for (const [id, agent] of Object.entries(data.agents)) {
      const ax = agent.position[0] * this.worldScale;
      const ay = agent.position[1] * this.worldScale;
      const d = Math.hypot(relX - ax, relY - ay);
      if (d <= 16) {
        return id;
      }
    }
    return null;
  }
}
