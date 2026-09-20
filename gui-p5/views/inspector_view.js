/** Agent and live endpoint inspection. */
class InspectorView {
  constructor(x, y, w, h) { this.bounds = { x, y, w, h }; }

  draw(p, data, selectedAgentId) {
    p.push(); p.stroke(43, 56, 78); p.fill(24, 32, 44);
    p.rect(this.bounds.x, this.bounds.y, this.bounds.w, this.bounds.h, 6);
    p.noStroke(); p.fill(136, 153, 172); p.textSize(12);
    p.text('AGENT / SOURCE INSPECTOR', this.bounds.x + 12, this.bounds.y + 20);
    let cy = this.bounds.y + 45;
    const row = (label, value, color = [226, 232, 240]) => {
      p.fill(136, 153, 172); p.textSize(10); p.text(label, this.bounds.x + 16, cy);
      p.fill(...color); p.text(String(value), this.bounds.x + 112, cy); cy += 18;
    };

    const agent = data?.agents?.[selectedAgentId];
    if (agent) {
      row('Agent', agent.id, [56, 189, 248]);
      row('State', agent.state || 'n/a', [52, 211, 153]);
      row('Goal', agent.goal || 'none', [251, 191, 36]);
      row('Target', agent.target || 'none');
      row('Held', agent.held || 'empty');
      const need = Number(agent.food_need ?? 0);
      row('FoodNeed', Math.round(need * 100) + '%');
    } else {
      p.fill(100); p.textSize(10);
      p.text('No agent projection available in this source.', this.bounds.x + 16, cy);
      cy += 28;
    }

    p.stroke(43, 56, 78); p.line(this.bounds.x + 16, cy, this.bounds.x + this.bounds.w - 16, cy);
    cy += 20; p.noStroke(); p.fill(136, 153, 172); p.textSize(10);
    p.text('SOURCE / ENDPOINT STATUS', this.bounds.x + 16, cy); cy += 18;
    row('Mode', data?._viewer_meta?.source || 'none', [56, 189, 248]);

    const endpoints = data?._viewer_meta?.endpoint_status || {};
    const names = Object.keys(endpoints);
    if (names.length) {
      for (const name of names.slice(0, 7)) {
        const state = endpoints[name];
        row(name, state.ok ? 'GET ' + state.status : 'unavailable ' + state.status, state.ok ? [52, 211, 153] : [136, 153, 172]);
      }
    } else {
      row('Runtime', 'fixture / no live GET');
    }

    p.stroke(43, 56, 78); p.line(this.bounds.x + 16, cy, this.bounds.x + this.bounds.w - 16, cy);
    cy += 20; p.noStroke(); p.fill(136, 153, 172); p.textSize(10);
    p.text('CANONICAL SIDECAR', this.bounds.x + 16, cy); cy += 18;
    const can = data?.canonical_snapshot;
    if (can) {
      row('retained H', can.total_retained_h ?? 0, [192, 132, 252]);
      row('pending E', can.pending_reviews?.length ?? 0);
    } else {
      row('status', 'not available');
    }
    p.pop();
  }
}