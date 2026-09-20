/**
 * views/inspector_view.js - Agent details & BodyState
 */
class InspectorView {
  constructor(x, y, w, h) {
    this.bounds = { x, y, w, h };
  }

  draw(p, data, selectedAgentId) {
    p.push();
    p.stroke(43, 56, 78);
    p.fill(24, 32, 44);
    p.rect(this.bounds.x, this.bounds.y, this.bounds.w, this.bounds.h, 6);

    p.noStroke();
    p.fill(136, 153, 172);
    p.textSize(12);
    p.text("AGENT INSPECTOR", this.bounds.x + 12, this.bounds.y + 20);

    const agent = data?.agents?.[selectedAgentId];
    if (!agent) {
      p.fill(100);
      p.text("Select an agent from the world view", this.bounds.x + 20, this.bounds.y + 50);
      p.pop();
      return;
    }

    let cy = this.bounds.y + 45;
    const drawRow = (label, val, col = [226, 232, 240]) => {
      p.fill(136, 153, 172);
      p.textSize(11);
      p.text(label, this.bounds.x + 16, cy);
      p.fill(...col);
      p.text(String(val), this.bounds.x + 100, cy);
      cy += 20;
    };

    // Agent ID & State
    drawRow("Agent ID:", agent.id.toUpperCase(), [56, 189, 248]);
    drawRow("State:", agent.state || "normal", [52, 211, 153]);
    drawRow("Goal:", agent.goal || "none", [251, 191, 36]);
    drawRow("Target ID:", agent.target || "none");
    drawRow("Held Item:", agent.held || "empty");

    // FoodNeed Meter
    cy += 5;
    p.fill(136, 153, 172);
    p.text("FoodNeed:", this.bounds.x + 16, cy);
    const needVal = agent.food_need ?? 0.0;
    p.fill(15, 23, 42);
    p.stroke(43, 56, 78);
    p.rect(this.bounds.x + 100, cy - 10, 140, 12, 3);

    p.noStroke();
    if (needVal > 0.7) p.fill(248, 113, 113);
    else if (needVal > 0.4) p.fill(251, 191, 36);
    else p.fill(52, 211, 153);
    p.rect(this.bounds.x + 101, cy - 9, Math.min(138, needVal * 138), 10, 2);

    p.fill(255);
    p.textSize(9);
    p.text(`${(needVal * 100).toFixed(0)}%`, this.bounds.x + 248, cy);

    // Canonical sidecar status (H / E)
    cy += 30;
    p.stroke(43, 56, 78);
    p.line(this.bounds.x + 16, cy - 10, this.bounds.x + this.bounds.w - 16, cy - 10);
    p.noStroke();
    p.fill(136, 153, 172);
    p.textSize(11);
    p.text("DIAGNOSTIC SIDECAR", this.bounds.x + 16, cy);
    cy += 20;

    const canSnap = data?.canonical_snapshot;
    if (canSnap) {
      drawRow("Diagnostic H:", canSnap.total_retained_h ?? 0.0, [192, 132, 252]);
      drawRow("Pending E:", canSnap.pending_reviews?.length ?? 0);
    } else {
      p.fill(100);
      p.text("Sidecar: Frozen Mock State", this.bounds.x + 16, cy);
    }

    p.pop();
  }
}
