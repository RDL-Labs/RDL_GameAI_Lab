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
      p.fill(...color); p.text(String(value), this.bounds.x + 112, cy); cy += 14;
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
      const luanti = data?.luanti_outcome_snapshot;
      const traceExperiences = (luanti?.experiences?.records || [])
        .filter(item => item.agent_id === selectedAgentId);
      const traceSleeps = (luanti?.sleep_results || [])
        .filter(item => item.agent_id === selectedAgentId);
      if (luanti) {
        row('Trace agent', selectedAgentId, [56, 189, 248]);
        row('Experiences', traceExperiences.length, [52, 211, 153]);
        row('Sleep results', traceSleeps.length, [192, 132, 252]);
        row('World view', 'not exposed');
      } else {
        p.fill(100); p.textSize(10);
        p.text('No agent projection available in this source.', this.bounds.x + 16, cy);
        cy += 28;
      }
    }

    p.stroke(43, 56, 78); p.line(this.bounds.x + 16, cy, this.bounds.x + this.bounds.w - 16, cy);
    cy += 20; p.noStroke(); p.fill(136, 153, 172); p.textSize(10);
    p.text('SOURCE / ENDPOINT STATUS', this.bounds.x + 16, cy); cy += 18;
    row('Mode', data?._viewer_meta?.source || 'none', [56, 189, 248]);

    const endpoints = data?._viewer_meta?.endpoint_status || {};
    const names = Object.keys(endpoints);
    if (names.length) {
      for (const name of names.slice(0, 3)) {
        const state = endpoints[name];
        row(name, state.ok ? 'GET ' + state.status : 'unavailable ' + state.status, state.ok ? [52, 211, 153] : [136, 153, 172]);
      }
    } else {
      row('Runtime', 'fixture / no live GET');
    }

    p.stroke(43, 56, 78); p.line(this.bounds.x + 16, cy, this.bounds.x + this.bounds.w - 16, cy);
    cy += 20; p.noStroke(); p.fill(136, 153, 172); p.textSize(10);
    p.text('CANONICAL SIDECAR — ' + selectedAgentId, this.bounds.x + 16, cy); cy += 18;
    const can = data?.canonical_snapshot;
    if (can) {
      const last = items => items.length ? items[items.length - 1] : null;
      const paths = (data?.review_path_snapshot?.paths || [])
        .filter(item => item.agent_id === selectedAgentId);
      const latest = last(paths);
      row('C2 paths', paths.length, [192, 132, 252]);
      row('review / H', latest ?
        `${latest.review.status} r${latest.review.revision} / ${latest.H}` : 'none',
        latest?.H > 0 ? [248, 113, 113] : [52, 211, 153]);
      const assessmentIds = new Set(paths.map(item => item.assessment_id));
      const theta = last((data?.theta_effective_snapshot?.evaluations || [])
        .filter(item => assessmentIds.has(item.assessment_id)));
      row('theta_eff', theta ? theta.theta_eff : 'none');
      row('C3 boundary', theta ? (theta.comparison || theta.status) : 'none',
        theta?.comparison === 'rupture_boundary_met' ? [248, 113, 113] : [52, 211, 153]);
      const modelRefs = new Set([
        ...Object.values(can.models || {}),
        ...Object.values(can.model_archive || {})
      ].filter(item => item.agent_id === selectedAgentId).map(item => item.model_ref));
      const delta = last((data?.m_delta_snapshot?.states || [])
        .filter(item => modelRefs.has(item.model_ref)));
      row('C4 phase', delta ? delta.phase : 'not entered',
        delta?.phase === 'M_delta' ? [248, 113, 113] : [52, 211, 153]);
      const bundle = last((data?.t1_material_snapshot?.bundles || [])
        .filter(item => item.agent_id === selectedAgentId));
      row('T1-A bundle', bundle ? bundle.material_count + ' materials' : 'none');
      const selection = last((data?.t1_selection_snapshot?.records || [])
        .filter(item => item.agent_id === selectedAgentId));
      row('T1-B select', selection ?
        `R${selection.counts.RETAIN} J${selection.counts.REJECT} D${selection.counts.DEFER}` : 'none');
      const artifact = last((data?.t1_reconstruction_snapshot?.artifacts || [])
        .filter(item => item.agent_id === selectedAgentId));
      row('T1-C M_B prime', artifact ? artifact.status : 'none',
        artifact ? [192, 132, 252] : [136, 153, 172]);
      const cutover = last((data?.model_cutover_snapshot?.records || [])
        .filter(item => item.agent_id === selectedAgentId));
      row('DMB-B cutover', cutover ? cutover.status : 'none',
        cutover ? [52, 211, 153] : [136, 153, 172]);
    } else {
      row('status', 'not available');
    }
    p.pop();
  }
}
