/** Agent-scoped, read-only SensorFrame inspection. */
class SensoryView {
  constructor(x, y, w, h) { this.bounds = { x, y, w, h }; }

  draw(p, data, selectedAgentId) {
    const snapshot = data?.sensory_observation_snapshot;
    const latest = snapshot?.latest_by_agent?.[selectedAgentId] || {};
    const channels = [
      ['vision_local', 'LOCAL VISION'],
      ['vision_distant', 'DISTANT VISION'],
      ['audition', 'AUDITION']
    ];

    p.push();
    p.stroke(43, 56, 78); p.fill(20, 27, 38);
    p.rect(this.bounds.x, this.bounds.y, this.bounds.w, this.bounds.h, 6);
    p.noStroke(); p.fill(136, 153, 172); p.textSize(12);
    p.text('SENSORY OBSERVATION — independent capture times', this.bounds.x + 12, this.bounds.y + 20);
    p.fill(56, 189, 248); p.textSize(9);
    p.text(`${selectedAgentId} · read-only · ${snapshot?.run_id || 'no run'} / epoch ${snapshot?.world_epoch ?? 'n/a'}`,
      this.bounds.x + 12, this.bounds.y + 35);

    const cardY = this.bounds.y + 48;
    const gap = 7;
    const cardH = Math.floor((this.bounds.h - 78 - gap * 2) / 3);
    channels.forEach(([channel, label], index) => {
      this.drawChannel(p, cardY + index * (cardH + gap), cardH, label, channel, latest[channel]);
    });

    p.fill(136, 153, 172); p.textSize(8.5);
    p.text(`Stored ${snapshot?.count ?? 0} · rejected ${snapshot?.rejection_count ?? 0} · channels are not time-synchronized`,
      this.bounds.x + 12, this.bounds.y + this.bounds.h - 10);
    p.pop();
  }

  drawChannel(p, y, h, label, channel, frame) {
    const x = this.bounds.x + 12;
    const w = this.bounds.w - 24;
    p.stroke(43, 56, 78); p.fill(24, 32, 44); p.rect(x, y, w, h, 4);
    p.noStroke(); p.fill(192, 132, 252); p.textSize(9); p.text(label, x + 9, y + 14);
    if (!frame) {
      p.fill(100); p.textSize(9); p.text('NO FRAME FOR SELECTED AGENT', x + 9, y + 34);
      return;
    }

    const window = frame.capture_window || {};
    const partial = frame.coverage !== 'COMPLETE_WITHIN_PLAN';
    p.fill(partial ? 251 : 52, partial ? 191 : 211, partial ? 36 : 153); p.textSize(8.5);
    p.text(`${frame.status} · ${frame.coverage}${frame.output_limited ? ' · OUTPUT LIMITED' : ''}`, x + 9, y + 30);
    p.fill(226, 232, 240); p.textSize(8.5);
    p.text(`seq ${frame.sample_seq} · tick ${frame.sampled_world_tick} · capture ${this.captureLabel(window)}`,
      x + 9, y + 44);
    p.fill(136, 153, 172);
    p.text(`pose ${frame.observer_frame_ref || 'not recorded'} · profile ${frame.profile_id} r${frame.profile_revision}`,
      x + 9, y + 57);
    p.fill(226, 232, 240);
    p.text(this.payloadLabel(channel, frame.payload || {}), x + 9, y + 72);
  }

  captureLabel(window) {
    if (window.kind === 'interval') return `[${window.start_us}, ${window.end_us}) us`;
    if (window.kind === 'instant') return `${window.start_us} us`;
    return 'unavailable';
  }

  payloadLabel(channel, payload) {
    if (channel === 'vision_local') return `visible count ${payload.visible_count ?? 'n/a'}`;
    if (channel === 'vision_distant') {
      const features = payload.features || [];
      const sample = features[0];
      return sample ? `${features.length} feature(s) · first ${sample.color_band || 'unknown'} ${this.angle(sample.azimuth_interval_deg)}` : '0 features';
    }
    const detections = payload.detections || [];
    const sample = detections[0];
    return sample ? `${detections.length} detection(s) · first ${sample.received_strength_band}/${sample.dominant_band} ${this.angle(sample.azimuth_interval_deg)}` : '0 detections';
  }

  angle(interval) {
    return Array.isArray(interval) ? `[${interval[0]}, ${interval[1]}) deg` : 'direction unavailable';
  }
}

if (typeof module !== 'undefined') module.exports = SensoryView;
