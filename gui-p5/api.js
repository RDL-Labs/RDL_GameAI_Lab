/**
 * api.js - Data ingestion layer for p5 Workbench
 * Contract: Read-only viewer adapter. Does not mutate or calculate RDL states.
 */
class RDLWorkbenchAPI {
  constructor() {
    this.sourceMode = 'mock'; // 'mock' or 'live'
    this.baseUrl = 'http://127.0.0.1:8765';
    this.cachedData = null;
    this.statusText = 'Ready (Mock)';
  }

  setSourceMode(mode) {
    this.sourceMode = mode;
  }

  async fetchData() {
    if (this.sourceMode === 'mock') {
      return await this.fetchMock();
    } else {
      return await this.fetchLive();
    }
  }

  async fetchMock() {
    try {
      const resp = await fetch('fixtures/snapshot_mock.json');
      if (!resp.ok) throw new Error(`Failed to load mock JSON: ${resp.status}`);
      const data = await resp.json();
      this.cachedData = data;
      this.statusText = 'Loaded Mock Fixture';
      return data;
    } catch (err) {
      console.error('Error fetching mock data:', err);
      this.statusText = `Mock Load Error: ${err.message}`;
      return null;
    }
  }

  async fetchLive() {
    try {
      // Gather multi-endpoint snapshots in parallel
      const [expResp, canResp, resResp] = await Promise.allSettled([
        fetch(`${this.baseUrl}/v1/experience-snapshot`),
        fetch(`${this.baseUrl}/v1/canonical-snapshot`),
        fetch(`${this.baseUrl}/v1/rescue-snapshot`),
      ]);

      const data = {
        tick: Date.now(),
        agents: {
          npc_a: { id: 'npc_a', position: [12.0, 8.0], food_need: 0.5, held: null, goal: 'idle', target: null, state: 'live' },
          npc_b: { id: 'npc_b', position: [24.0, 16.0], food_need: 0.2, held: null, goal: 'idle', target: null, state: 'live' }
        },
        objects: [
          { id: 'base_01', type: 'base', position: [5.0, 5.0], status: 'active' }
        ],
        history_snapshot: expResp.status === 'fulfilled' && expResp.value.ok ? await expResp.value.json() : null,
        canonical_snapshot: canResp.status === 'fulfilled' && canResp.value.ok ? await canResp.value.json() : null,
        rescue_snapshot: resResp.status === 'fulfilled' && resResp.value.ok ? await resResp.value.json() : null,
        sleep_window: null,
        relation_profiles: null
      };

      this.cachedData = data;
      this.statusText = 'Connected to Live Bridge';
      return data;
    } catch (err) {
      console.error('Error fetching live data:', err);
      this.statusText = 'Bridge Offline (Check 8765)';
      return null;
    }
  }
}

window.workbenchAPI = new RDLWorkbenchAPI();
