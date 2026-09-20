/**
 * api.js - read-only data ingestion for the Workbench.
 * The viewer never computes RDL state and never sends mutation requests.
 */
class RDLWorkbenchAPI {
  constructor() {
    this.sourceMode = 'mock';
    this.baseUrl = '/runtime';
    this.cachedData = null;
    this.statusText = 'Ready (Fixture)';
    this.isRunning = false;
    this.baseFixture = null;
    this.mockStep = 0;
  }

  setSourceMode(mode) {
    this.sourceMode = mode;
    this.resetSimulation();
  }

  toggleRun() {
    this.isRunning = !this.isRunning;
    return this.isRunning;
  }

  stepSimulation() {
    if (!this.cachedData) return;
    this.mockStep++;
    this.cachedData.tick = 20 + this.mockStep;

    // Simulate gentle agent dynamics in fixture mode
    if (this.cachedData.agents) {
      const a = this.cachedData.agents.npc_a;
      const b = this.cachedData.agents.npc_b;
      if (a && a.position) {
        // Move npc_a slightly toward apple_01 or base
        const tx = a.held ? 5.0 : 15.0;
        const ty = a.held ? 5.0 : 10.0;
        const dx = tx - a.position[0];
        const dy = ty - a.position[1];
        const dist = Math.hypot(dx, dy);
        if (dist > 0.4) {
          a.position[0] += (dx / dist) * 0.4;
          a.position[1] += (dy / dist) * 0.4;
        } else {
          a.held = a.held ? null : 'apple_01';
          a.goal = a.held ? 'deposit' : 'approach';
          a.food_need = Math.max(0.1, a.food_need - 0.05);
        }
      }
      if (b && b.position) {
        // NPC B resting & slowly waking
        b.food_need = Math.min(0.9, (b.food_need || 0.2) + 0.005);
        if (this.mockStep % 15 === 0) {
          b.state = b.state === 'resting' ? 'waking' : 'resting';
        }
      }
    }
  }

  resetSimulation() {
    this.mockStep = 0;
    this.isRunning = false;
    if (this.baseFixture) {
      this.cachedData = JSON.parse(JSON.stringify(this.baseFixture));
    }
  }

  async fetchData() {
    return this.sourceMode === 'live' ? this.fetchLive() : this.fetchMock();
  }

  async fetchMock() {
    try {
      if (!this.baseFixture) {
        const resp = await fetch('fixtures/snapshot_mock.json', { cache: 'no-store' });
        if (!resp.ok) throw new Error('fixture HTTP ' + resp.status);
        this.baseFixture = await resp.json();
        this.baseFixture._viewer_meta = {
          source: 'fixture',
          endpoint_status: {},
          world_projection: 'fixture-only',
          sleep_projection: 'fixture-s1-s2',
          deep_similarity: 'S3 contract frozen; implementation not represented'
        };
      }
      if (!this.cachedData || this.mockStep === 0) {
        this.cachedData = JSON.parse(JSON.stringify(this.baseFixture));
      }
      this.statusText = this.isRunning ? `Running (Tick ${this.cachedData.tick})` : `Paused (Tick ${this.cachedData.tick})`;
      return this.cachedData;
    } catch (err) {
      console.error(err);
      this.statusText = 'Fixture error: ' + err.message;
      return null;
    }
  }

  async fetchEndpoint(name, path) {
    try {
      const resp = await fetch(this.baseUrl + path, { cache: 'no-store' });
      let payload = null;
      try { payload = await resp.json(); } catch (_) { payload = null; }
      return { name, ok: resp.ok, status: resp.status, payload };
    } catch (err) {
      return { name, ok: false, status: 0, payload: null, error: err.message };
    }
  }

  async fetchLive() {
    const specs = [
      ['health', '/health'],
      ['experience', '/v1/experience-snapshot'],
      ['canonical', '/v1/canonical-snapshot'],
      ['rescue', '/v1/rescue-snapshot'],
      ['rest', '/v1/rest-snapshot'],
      ['life', '/v1/life-snapshot'],
      ['food_mb', '/v1/food-mb-shadow']
    ];
    const results = await Promise.all(specs.map(([name, path]) => this.fetchEndpoint(name, path)));
    const byName = Object.fromEntries(results.map(result => [result.name, result]));
    const endpointStatus = Object.fromEntries(results.map(result => [
      result.name,
      { ok: result.ok, status: result.status, error: result.error || null }
    ]));
    const okCount = results.filter(result => result.ok).length;

    const data = {
      tick: Date.now(),
      agents: null,
      objects: null,
      history_snapshot: byName.experience.ok ? byName.experience.payload : null,
      canonical_snapshot: byName.canonical.ok ? byName.canonical.payload : null,
      rescue_snapshot: byName.rescue.ok ? byName.rescue.payload : null,
      rest_snapshot: byName.rest.ok ? byName.rest.payload : null,
      life_snapshot: byName.life.ok ? byName.life.payload : null,
      food_mb_snapshot: byName.food_mb.ok ? byName.food_mb.payload : null,
      sleep_window: null,
      relation_profiles: null,
      deep_similarity: null,
      _viewer_meta: {
        source: 'live',
        endpoint_status: endpointStatus,
        world_projection: 'not exposed by current Runtime bridge',
        sleep_projection: 'S1/S2 snapshots not exposed by current Runtime bridge',
        deep_similarity: 'S3 implementation not exposed'
      }
    };

    this.cachedData = data;
    this.statusText = 'Live read-only: ' + okCount + '/' + results.length + ' GET endpoints';
    return data;
  }
}

window.workbenchAPI = new RDLWorkbenchAPI();