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
  }

  setSourceMode(mode) {
    this.sourceMode = mode;
  }

  async fetchData() {
    return this.sourceMode === 'live' ? this.fetchLive() : this.fetchMock();
  }

  async fetchMock() {
    try {
      const resp = await fetch('fixtures/snapshot_mock.json', { cache: 'no-store' });
      if (!resp.ok) throw new Error('fixture HTTP ' + resp.status);
      const data = await resp.json();
      data._viewer_meta = {
        source: 'fixture',
        endpoint_status: {},
        world_projection: 'fixture-only',
        sleep_projection: 'fixture-s1-s2',
        deep_similarity: 'S3 contract frozen; implementation not represented'
      };
      this.cachedData = data;
      this.statusText = 'Fixture loaded';
      return data;
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