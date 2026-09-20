/** Sleep window and derived profile viewer. */
class MemoryView {
  constructor(x, y, w, h) {
    this.bounds = { x, y, w, h };
    this.profileHitboxes = [];
  }

  draw(p, data, selectedAgentId, selectedProfileId, selectedExperienceId) {
    this.profileHitboxes = [];
    p.push(); p.stroke(43, 56, 78); p.fill(20, 27, 38);
    p.rect(this.bounds.x, this.bounds.y, this.bounds.w, this.bounds.h, 6);
    p.noStroke(); p.fill(136, 153, 172); p.textSize(12);
    p.text('SLEEP MEMORY — source window / relation profiles', this.bounds.x + 12, this.bounds.y + 20);

    const win = data?.sleep_window;
    const allProfiles = data?.relation_profiles?.profiles || [];
    const profiles = allProfiles.filter(profile => !data?.relation_profiles?.agent_id || data.relation_profiles.agent_id === selectedAgentId);
    let cy = this.bounds.y + 36;

    p.fill(15, 23, 42); p.stroke(30, 41, 59); p.rect(this.bounds.x + 12, cy, this.bounds.w - 24, 48, 4);
    p.noStroke(); p.fill(192, 132, 252); p.textSize(9); p.text('S1 FINITE WINDOW', this.bounds.x + 20, cy + 15);
    p.fill(226, 232, 240); p.textSize(10);
    if (win) {
      const selectedInWindow = selectedExperienceId && win.source_experience_ids?.includes(selectedExperienceId);
      p.text('Cycle ' + win.sleep_cycle + ' · ' + win.status + ' · ' + win.source_count + '/6 sources' + (selectedInWindow ? ' · selected source included' : ''), this.bounds.x + 20, cy + 33);
    } else {
      p.text(data?._viewer_meta?.sleep_projection || 'No Sleep window snapshot', this.bounds.x + 20, cy + 33);
    }
    cy += 62;

    p.fill(136, 153, 172); p.textSize(10);
    p.text('S2 DERIVED PROFILES — click a card', this.bounds.x + 14, cy);
    cy += 12;

    if (!profiles.length) {
      p.fill(100); p.textSize(10);
      p.text('No relation profile snapshot in this source.', this.bounds.x + 20, cy + 24);
      cy += 52;
    } else {
      const cardW = Math.floor((this.bounds.w - 36) / 3);
      const cardH = 82;
      for (let i = 0; i < Math.min(profiles.length, 3); i++) {
        const prof = profiles[i];
        const x = this.bounds.x + 12 + i * (cardW + 6);
        const selected = prof.profile_id === selectedProfileId;
        p.fill(selected ? 31 : 26, selected ? 52 : 36, selected ? 74 : 52);
        p.stroke(selected ? 56 : 43, selected ? 189 : 56, selected ? 248 : 78);
        p.rect(x, cy, cardW, cardH, 4);
        this.profileHitboxes.push({ x, y: cy, w: cardW, h: cardH, id: prof.profile_id });
        p.noStroke(); p.fill(56, 189, 248); p.textSize(8);
        p.text('SRC ' + prof.source_experience_id.slice(0, 8) + '…', x + 8, cy + 14);
        let ry = cy + 29;
        for (const rel of (prof.relations || [])) {
          const col = rel.polarity === 'supportive' ? [52, 211, 153] : rel.polarity === 'unresolved' ? [251, 191, 36] : [180, 190, 205];
          p.fill(...col); p.textSize(7.5);
          p.text(rel.kind + ': ' + String(rel.object).slice(0, 14), x + 8, ry);
          ry += 10;
          if (ry > cy + cardH - 6) break;
        }
      }
      cy += cardH + 16;
    }

    const selectedProfile = profiles.find(profile => profile.profile_id === selectedProfileId) || null;
    p.stroke(43, 56, 78); p.line(this.bounds.x + 12, cy, this.bounds.x + this.bounds.w - 12, cy);
    cy += 17; p.noStroke(); p.fill(136, 153, 172); p.textSize(9); p.text('PROFILE DETAIL', this.bounds.x + 14, cy);
    cy += 14;
    if (!selectedProfile) {
      p.fill(100); p.textSize(9); p.text('Select an Experience or Profile to inspect its sourced relations.', this.bounds.x + 20, cy);
    } else {
      for (const rel of selectedProfile.relations || []) {
        const col = rel.polarity === 'supportive' ? [52, 211, 153] : rel.polarity === 'unresolved' ? [251, 191, 36] : [226, 232, 240];
        p.fill(...col); p.textSize(8.5);
        p.text(rel.kind + '  ' + rel.predicate + ' → ' + rel.object + '  [' + rel.polarity + ' / ' + rel.strength + ']', this.bounds.x + 20, cy);
        cy += 13;
        if (cy > this.bounds.y + this.bounds.h - 8) break;
      }
    }
    p.pop();
  }

  checkProfileClick(mx, my) {
    const hit = this.profileHitboxes.find(box => mx >= box.x && mx <= box.x + box.w && my >= box.y && my <= box.y + box.h);
    return hit?.id || null;
  }
}