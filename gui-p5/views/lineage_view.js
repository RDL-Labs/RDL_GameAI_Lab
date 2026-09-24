/** Provenance lineage viewer. It displays missing stages instead of inferring them. */
class LineageView {
  constructor(x, y, w, h) { this.bounds = { x, y, w, h }; }

  draw(p, data, selectedAgentId, selectedExperienceId, selectedProfileId) {
    p.push(); p.stroke(43, 56, 78); p.fill(17, 24, 39);
    p.rect(this.bounds.x, this.bounds.y, this.bounds.w, this.bounds.h, 6);
    p.noStroke(); p.fill(136, 153, 172); p.textSize(12);
    p.text('PROVENANCE LINEAGE — derived objects stay separate', this.bounds.x + 12, this.bounds.y + 20);

    const records = (data?.history_snapshot?.records || []).filter(record => record.agent_id === selectedAgentId);
    const win = data?.sleep_window;
    const profiles = data?.relation_profiles?.profiles || [];
    const deep = data?.deep_similarity || null;
    const fastQueries = data?.fast_retrieval_snapshot?.queries || [];
    const latestFast = fastQueries.length ? fastQueries[fastQueries.length - 1] : null;

    const stages = [
      { title: 'RAW EXPERIENCE', value: records.length + ' records', detail: selectedExperienceId ? 'selected ' + selectedExperienceId.slice(0, 8) + '…' : 'immutable source', state: records.length ? 'ok' : 'missing' },
      { title: 'S1 WINDOW', value: win ? win.status : 'NOT EXPOSED', detail: win ? (win.source_count + ' sourced') : 'no viewer snapshot', state: win ? (win.status === 'READY' ? 'ok' : 'warn') : 'missing' },
      { title: 'S2 PROFILES', value: profiles.length ? profiles.length + ' profiles' : 'NOT EXPOSED', detail: selectedProfileId ? 'selected ' + selectedProfileId.slice(0, 8) + '…' : 'derived only', state: profiles.length ? 'ok' : 'missing' },
      { title: 'S3 SIMILARITY', value: deep?.similarity_observations ? deep.similarity_observations.length + ' observations' : 'CONTRACT ONLY', detail: 'no inference in viewer', state: deep ? 'ok' : 'pending' },
      { title: 'CLUSTER / CANDIDATE', value: deep?.candidate ? 'shadow candidate' : 'NONE PRESENT', detail: 'not Commitment / Truth', state: deep?.candidate ? 'ok' : 'pending' },
      { title: 'F1 FAST RETRIEVAL', value: latestFast ? latestFast.status : 'NOT ENABLED', detail: latestFast ? (latestFast.results.length + ' / top-' + latestFast.top_k + ' · read only') : 'no query snapshot', state: latestFast ? 'ok' : 'pending' }
    ];

    const startX = this.bounds.x + 24;
    const y = this.bounds.y + 50;
    const gap = 16;
    const boxW = Math.floor((this.bounds.w - 48 - gap * (stages.length - 1)) / stages.length);
    const boxH = 92;
    for (let i = 0; i < stages.length; i++) {
      const stage = stages[i];
      const x = startX + i * (boxW + gap);
      if (i > 0) {
        p.stroke(75, 90, 112); p.line(x - gap + 2, y + boxH / 2, x - 4, y + boxH / 2);
        p.noStroke(); p.fill(75, 90, 112); p.triangle(x - 4, y + boxH / 2, x - 10, y + boxH / 2 - 4, x - 10, y + boxH / 2 + 4);
      }
      const border = stage.state === 'ok' ? [52, 211, 153] : stage.state === 'warn' ? [251, 191, 36] : stage.state === 'pending' ? [192, 132, 252] : [75, 90, 112];
      p.fill(22, 30, 43); p.stroke(...border); p.rect(x, y, boxW, boxH, 5);
      p.noStroke(); p.fill(...border); p.textSize(9); p.text(stage.title, x + 10, y + 18);
      p.fill(226, 232, 240); p.textSize(10); p.text(stage.value, x + 10, y + 43);
      p.fill(136, 153, 172); p.textSize(8.5); p.text(stage.detail, x + 10, y + 64);
    }

    const by = y + boxH + 18;
    p.stroke(248, 113, 113, 130);
    for (let dx = this.bounds.x + 24; dx < this.bounds.x + this.bounds.w - 24; dx += 10) p.line(dx, by, dx + 5, by);
    p.noStroke(); p.fill(248, 113, 113); p.textSize(8.5);
    p.text('Authority boundary: no automatic Candidate → Canonical M_B admission', this.bounds.x + 24, by + 16);
    p.pop();
  }
}
