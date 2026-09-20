/** Raw Experience timeline with source selection. */
class TimelineView {
  constructor(x, y, w, h) {
    this.bounds = { x, y, w, h };
    this.nodeHitboxes = [];
  }

  actionName(record) {
    if (typeof record?.action === 'string') return record.action;
    if (record?.action?.type) return record.action.type;
    if (typeof record?.decision?.action === 'string') return record.decision.action;
    if (record?.decision?.action?.type) return record.decision.action.type;
    return 'action';
  }

  draw(p, data, selectedAgentId, selectedExperienceId) {
    this.nodeHitboxes = [];
    p.push(); p.stroke(43, 56, 78); p.fill(17, 24, 39);
    p.rect(this.bounds.x, this.bounds.y, this.bounds.w, this.bounds.h, 6);
    p.noStroke(); p.fill(136, 153, 172); p.textSize(12);
    p.text('RAW EXPERIENCE TIMELINE — click a source record', this.bounds.x + 12, this.bounds.y + 20);

    const records = data?.history_snapshot?.records || [];
    const agentRecords = records.filter(record => record.agent_id === selectedAgentId);
    if (!agentRecords.length) {
      p.fill(100); p.textSize(10);
      p.text('No accepted Experience records for ' + selectedAgentId + '.', this.bounds.x + 20, this.bounds.y + 52);
      p.pop(); return;
    }

    const railY = this.bounds.y + 67;
    p.stroke(43, 56, 78); p.line(this.bounds.x + 30, railY, this.bounds.x + this.bounds.w - 30, railY);
    const usable = this.bounds.w - 80;
    const spacing = agentRecords.length === 1 ? 0 : Math.min(190, usable / (agentRecords.length - 1));
    const total = spacing * Math.max(0, agentRecords.length - 1);
    const start = this.bounds.x + (this.bounds.w - total) / 2;

    for (let i = 0; i < agentRecords.length; i++) {
      const rec = agentRecords[i];
      const nx = start + i * spacing;
      const selected = rec.record_id === selectedExperienceId;
      const progress = rec.outcome === 'approach_progress' || rec.result_payload?.outcome === 'approach_progress';
      p.stroke(selected ? 56 : 255, selected ? 189 : 255, selected ? 248 : 255);
      p.strokeWeight(selected ? 3 : 1);
      p.fill(progress ? 52 : 251, progress ? 211 : 191, progress ? 153 : 36);
      p.circle(nx, railY, selected ? 18 : 13);
      this.nodeHitboxes.push({ x: nx, y: railY, r: 13, id: rec.record_id });
      p.noStroke(); p.textAlign(p.CENTER); p.textSize(8.5); p.fill(226, 232, 240);
      p.text('T' + (rec.tick ?? i + 1), nx, railY + 22);
      p.fill(136, 153, 172); p.text(this.actionName(rec), nx, railY + 34);
    }
    p.textAlign(p.LEFT);

    const selected = agentRecords.find(record => record.record_id === selectedExperienceId);
    const detailY = this.bounds.y + 122;
    p.stroke(43, 56, 78); p.line(this.bounds.x + 20, detailY - 12, this.bounds.x + this.bounds.w - 20, detailY - 12);
    p.noStroke(); p.fill(136, 153, 172); p.textSize(9); p.text('SOURCE DETAIL', this.bounds.x + 20, detailY);
    if (selected) {
      const action = this.actionName(selected);
      const target = selected.action?.target_id || selected.decision?.action?.target_id || 'n/a';
      const purpose = selected.context?.purpose || 'n/a';
      p.fill(226, 232, 240); p.textSize(9);
      p.text('action=' + action + '   target=' + target + '   outcome=' + (selected.outcome || 'n/a') + '   purpose=' + purpose, this.bounds.x + 20, detailY + 20);
      p.fill(136, 153, 172); p.textSize(8);
      p.text('record ' + selected.record_id, this.bounds.x + 20, detailY + 38);
    } else {
      p.fill(100); p.textSize(9); p.text('Select a timeline node to trace it into S1/S2.', this.bounds.x + 20, detailY + 20);
    }
    p.pop();
  }

  checkExperienceClick(mx, my) {
    const hit = this.nodeHitboxes.find(node => Math.hypot(mx - node.x, my - node.y) <= node.r);
    return hit?.id || null;
  }
}