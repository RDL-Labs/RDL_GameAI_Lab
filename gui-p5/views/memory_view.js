/**
 * views/memory_view.js - Sleep Consolidation, Window & Relation Profiles
 */
class MemoryView {
  constructor(x, y, w, h) {
    this.bounds = { x, y, w, h };
  }

  draw(p, data, selectedAgentId) {
    p.push();
    p.stroke(43, 56, 78);
    p.fill(20, 27, 38);
    p.rect(this.bounds.x, this.bounds.y, this.bounds.w, this.bounds.h, 6);

    p.noStroke();
    p.fill(136, 153, 172);
    p.textSize(12);
    p.text("SLEEP MEMORY & RELATION PROFILES (Phase 6)", this.bounds.x + 12, this.bounds.y + 20);

    const win = data?.sleep_window;
    const profiles = data?.relation_profiles?.profiles || [];

    let cy = this.bounds.y + 40;

    // Window info box
    p.fill(15, 23, 42);
    p.stroke(30, 41, 59);
    p.rect(this.bounds.x + 12, cy, this.bounds.w - 24, 45, 4);

    p.noStroke();
    p.fill(192, 132, 252);
    p.textSize(10);
    p.text("SLEEP WINDOW STATUS", this.bounds.x + 20, cy + 16);

    p.fill(226, 232, 240);
    p.textSize(11);
    if (win) {
      p.text(`Cycle: ${win.sleep_cycle} | Status: ${win.status} | Sources: ${win.source_count}/6`, this.bounds.x + 20, cy + 33);
    } else {
      p.text("No active sleep window", this.bounds.x + 20, cy + 33);
    }

    cy += 55;

    // Profiles title
    p.fill(136, 153, 172);
    p.textSize(11);
    p.text(`Derived Relation Profiles (${profiles.length} records):`, this.bounds.x + 14, cy);
    cy += 15;

    // Draw up to 3 relation profile cards
    const cardH = 52;
    for (let i = 0; i < Math.min(profiles.length, 3); i++) {
      const prof = profiles[i];
      p.fill(26, 36, 52);
      p.stroke(43, 56, 78);
      p.rect(this.bounds.x + 12, cy, this.bounds.w - 24, cardH, 4);

      // Card Header
      p.noStroke();
      p.fill(56, 189, 248);
      p.textSize(9);
      p.text(`SRC: ${prof.source_experience_id.slice(0, 12)}...`, this.bounds.x + 20, cy + 14);

      // Relations tags
      let tagX = this.bounds.x + 20;
      for (const rel of (prof.relations || [])) {
        let tagBg = [30, 41, 59];
        let tagCol = [226, 232, 240];

        if (rel.kind === 'outcome') {
          if (rel.polarity === 'supportive') {
            tagBg = [6, 78, 59];
            tagCol = [52, 211, 153];
          } else if (rel.polarity === 'unresolved') {
            tagBg = [120, 53, 15];
            tagCol = [251, 191, 36];
          }
        }

        p.fill(...tagBg);
        p.rect(tagX, cy + 22, 50, 18, 2);
        p.fill(...tagCol);
        p.textSize(8);
        p.textAlign(p.CENTER);
        p.text(rel.kind.toUpperCase(), tagX + 25, cy + 34);
        p.textAlign(p.LEFT);

        tagX += 54;
      }

      cy += cardH + 6;
    }

    p.pop();
  }
}
