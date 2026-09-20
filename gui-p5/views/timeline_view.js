/**
 * views/timeline_view.js - Raw Experience Timeline Lane
 */
class TimelineView {
  constructor(x, y, w, h) {
    this.bounds = { x, y, w, h };
  }

  draw(p, data, selectedAgentId) {
    p.push();
    p.stroke(43, 56, 78);
    p.fill(17, 24, 39);
    p.rect(this.bounds.x, this.bounds.y, this.bounds.w, this.bounds.h, 6);

    p.noStroke();
    p.fill(136, 153, 172);
    p.textSize(12);
    p.text("RAW EXPERIENCE TIMELINE (Immutable Source History)", this.bounds.x + 12, this.bounds.y + 20);

    const records = data?.history_snapshot?.records || [];
    const agentRecords = records.filter(r => r.agent_id === selectedAgentId);

    if (agentRecords.length === 0) {
      p.fill(100);
      p.textSize(11);
      p.text("No interaction experiences recorded yet.", this.bounds.x + 20, this.bounds.y + 50);
      p.pop();
      return;
    }

    // Horizontal timeline rail
    const railY = this.bounds.y + 55;
    p.stroke(43, 56, 78);
    p.line(this.bounds.x + 20, railY, this.bounds.x + this.bounds.w - 20, railY);

    // Render experience nodes along the rail
    const nodeSpacing = Math.min(180, (this.bounds.w - 60) / Math.max(1, agentRecords.length));
    for (let i = 0; i < agentRecords.length; i++) {
      const rec = agentRecords[i];
      const nx = this.bounds.x + 30 + i * nodeSpacing;

      // Node circle
      const isProgress = (rec.outcome === 'approach_progress' || rec.result_payload?.outcome === 'approach_progress');
      p.stroke(255);
      p.strokeWeight(1);
      if (isProgress) {
        p.fill(52, 211, 153); // Green progress
      } else {
        p.fill(251, 191, 36); // Amber unresolved
      }
      p.circle(nx, railY, 12);

      // Label below
      p.noStroke();
      p.fill(226, 232, 240);
      p.textSize(9);
      p.textAlign(p.CENTER);
      p.text(`Tick ${rec.tick ?? (i + 1)}`, nx, railY + 18);
      p.fill(136, 153, 172);
      const actionName = rec.action || rec.decision?.action?.type || rec.decision?.action || "action";
      p.text(actionName, nx, railY + 28);
      p.textAlign(p.LEFT);
    }

    p.pop();
  }
}
