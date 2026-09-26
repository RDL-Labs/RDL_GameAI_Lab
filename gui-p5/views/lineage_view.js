/** Provenance lineage viewer. It displays missing stages instead of inferring them. */
class LineageView {
  constructor(x, y, w, h) { this.bounds = { x, y, w, h }; }

  draw(p, data, selectedAgentId, selectedExperienceId, selectedProfileId) {
    p.push(); p.stroke(43, 56, 78); p.fill(17, 24, 39);
    p.rect(this.bounds.x, this.bounds.y, this.bounds.w, this.bounds.h, 6);
    p.noStroke(); p.fill(136, 153, 172); p.textSize(12);
    const luanti = data?.luanti_outcome_snapshot || null;
    p.text(luanti ? 'LUANTI LIFE TRACE — selected agent / read-only provenance' :
      'PROVENANCE LINEAGE — derived objects stay separate',
      this.bounds.x + 12, this.bounds.y + 20);

    if (luanti) {
      this.drawLuantiTrace(p, data, selectedAgentId, luanti);
      p.pop();
      return;
    }

    const records = (data?.history_snapshot?.records || []).filter(record => record.agent_id === selectedAgentId);
    const win = data?.sleep_window;
    const profiles = data?.relation_profiles?.profiles || [];
    const deep = data?.deep_similarity || null;
    const fastQueries = data?.fast_retrieval_snapshot?.queries || [];
    const latestFast = fastQueries.length ? fastQueries[fastQueries.length - 1] : null;
    const recoveredSleep = latestFast?.results?.find(item => item.source_type === 'sleep_candidate') || null;

    const stages = [
      { title: 'RAW EXPERIENCE', value: records.length + ' records', detail: selectedExperienceId ? 'selected ' + selectedExperienceId.slice(0, 8) + '…' : 'immutable source', state: records.length ? 'ok' : 'missing' },
      { title: 'S1 WINDOW', value: win ? win.status : 'NOT EXPOSED', detail: win ? (win.source_count + ' sourced') : 'no viewer snapshot', state: win ? (win.status === 'READY' ? 'ok' : 'warn') : 'missing' },
      { title: 'S2 PROFILES', value: profiles.length ? profiles.length + ' profiles' : 'NOT EXPOSED', detail: selectedProfileId ? 'selected ' + selectedProfileId.slice(0, 8) + '…' : 'derived only', state: profiles.length ? 'ok' : 'missing' },
      { title: 'S3 SIMILARITY', value: deep?.similarity_observations ? deep.similarity_observations.length + ' observations' : 'CONTRACT ONLY', detail: 'no inference in viewer', state: deep ? 'ok' : 'pending' },
      { title: 'CLUSTER / CANDIDATE', value: deep?.candidate ? 'shadow candidate' : 'NONE PRESENT', detail: 'not Commitment / Truth', state: deep?.candidate ? 'ok' : 'pending' },
      { title: 'F1/F2 FAST', value: latestFast ? latestFast.status : 'NOT ENABLED', detail: recoveredSleep ? ('sleep ' + recoveredSleep.source_id.slice(0, 6) + '… · ' + recoveredSleep.source_provenance.source_experience_ids.length + ' sources') : (latestFast ? latestFast.results.length + ' / top-' + latestFast.top_k : 'no query snapshot'), state: latestFast ? 'ok' : 'pending' }
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

  drawLuantiTrace(p, data, selectedAgentId, luanti) {
    const experiences = (luanti.experiences?.records || [])
      .filter(item => item.agent_id === selectedAgentId);
    const biases = (luanti.biases?.records || [])
      .filter(item => item.agent_id === selectedAgentId);
    const sleeps = (luanti.sleep_results || [])
      .filter(item => item.agent_id === selectedAgentId);
    const sleep = sleeps.length ? sleeps[sleeps.length - 1] : null;
    const candidate = sleep?.candidate || null;
    const canonical = data?.canonical_snapshot || {};
    const bundles = (canonical.T1_materials?.bundles || [])
      .filter(item => item.agent_id === selectedAgentId);
    const models = Object.values(canonical.models || {})
      .filter(item => item.agent_id === selectedAgentId);
    const model = models.length ? models[models.length - 1] : null;
    const archived = Object.values(canonical.model_archive || {})
      .filter(item => item.agent_id === selectedAgentId);

    const shortId = value => value ? String(value).slice(0, 8) + '…' : 'none';
    const stages = [
      { title: 'EXPERIENCE', value: experiences.length + ' records', detail: experiences.length ? shortId(experiences[experiences.length - 1].record_id) : 'none exposed', state: experiences.length ? 'ok' : 'missing' },
      { title: 'LOCAL BIAS', value: biases.length + ' relations', detail: biases.length ? new Set(biases.map(item => item.relation)).size + ' relation kinds' : 'none exposed', state: biases.length ? 'ok' : 'missing' },
      { title: 'SLEEP / DEEP', value: sleep ? sleep.status : 'NOT RUN', detail: sleep ? shortId(sleep.deep_similarity_id) : 'explicit trigger required', state: sleep ? 'ok' : 'pending' },
      { title: 'CANDIDATE', value: candidate ? 'support ' + candidate.support_count : 'NONE', detail: candidate ? shortId(candidate.candidate_id) : 'no promotion inferred', state: candidate ? 'ok' : 'pending' },
      { title: 'T1 MATERIALS', value: bundles.length ? bundles.length + ' bundle' + (bundles.length === 1 ? '' : 's') : 'NONE', detail: bundles.length ? bundles[bundles.length - 1].counts.candidates + ' candidate materials' : 'explicit review required', state: bundles.length ? 'ok' : 'pending' },
      { title: 'ACTIVE M_B', value: model ? 'active' : 'NOT PRESENT', detail: model ? shortId(model.model_ref) + ' · archive ' + archived.length : 'no model for agent', state: model ? 'ok' : 'missing' }
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
      const border = stage.state === 'ok' ? [52, 211, 153] : stage.state === 'pending' ? [251, 191, 36] : [75, 90, 112];
      p.fill(22, 30, 43); p.stroke(...border); p.rect(x, y, boxW, boxH, 5);
      p.noStroke(); p.fill(...border); p.textSize(9); p.text(stage.title, x + 10, y + 18);
      p.fill(226, 232, 240); p.textSize(10); p.text(stage.value, x + 10, y + 43);
      p.fill(136, 153, 172); p.textSize(8.5); p.text(stage.detail, x + 10, y + 64, boxW - 20, 24);
    }

    const by = y + boxH + 18;
    p.stroke(248, 113, 113, 130);
    for (let dx = this.bounds.x + 24; dx < this.bounds.x + this.bounds.w - 24; dx += 10) p.line(dx, by, dx + 5, by);
    p.noStroke(); p.fill(248, 113, 113); p.textSize(8.5);
    p.text('Read-only projection: trace visibility != review, selection, M_B admission, or action authority', this.bounds.x + 24, by + 16);
  }
}
