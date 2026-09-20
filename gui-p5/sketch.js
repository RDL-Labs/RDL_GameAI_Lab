/**
 * sketch.js - Main orchestrator for p5 Workbench
 */

let worldView;
let inspectorView;
let memoryView;
let timelineView;

let currentData = null;
let selectedAgentId = 'npc_a';

function setup() {
  const canvas = createCanvas(1180, 680);
  canvas.parent('canvas-wrapper');

  // Layout partition
  // Top: WorldView (560px) + InspectorView (280px) + MemoryView (320px) = 1160px
  // Bottom: TimelineView (1160px)
  worldView = new WorldView(10, 10, 560, 420);
  inspectorView = new InspectorView(580, 10, 280, 420);
  memoryView = new MemoryView(870, 10, 300, 420);
  timelineView = new TimelineView(10, 440, 1160, 100);

  // Bind controls
  const selectElem = document.getElementById('data-source-select');
  const refreshBtn = document.getElementById('btn-refresh');
  const statusElem = document.getElementById('connection-status');

  selectElem.addEventListener('change', (e) => {
    window.workbenchAPI.setSourceMode(e.target.value);
    loadData();
  });

  refreshBtn.addEventListener('click', () => {
    loadData();
  });

  // Initial fetch
  loadData();

  // Auto polling if live mode
  setInterval(() => {
    if (window.workbenchAPI.sourceMode === 'live') {
      loadData();
    }
  }, 2000);
}

async function loadData() {
  const statusElem = document.getElementById('connection-status');
  currentData = await window.workbenchAPI.fetchData();
  if (statusElem) {
    statusElem.textContent = window.workbenchAPI.statusText;
  }
}

function draw() {
  background(15, 20, 28);

  worldView.draw(this, currentData, selectedAgentId);
  inspectorView.draw(this, currentData, selectedAgentId);
  memoryView.draw(this, currentData, selectedAgentId);
  timelineView.draw(this, currentData, selectedAgentId);
}

function mousePressed() {
  // Check if click was inside world view on an agent
  const clickedAgent = worldView.checkAgentClick(mouseX, mouseY, currentData);
  if (clickedAgent) {
    selectedAgentId = clickedAgent;
  }
}
