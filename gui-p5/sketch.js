/** Main p5 Workbench orchestrator. */
let worldView;
let inspectorView;
let memoryView;
let lineageView;
let timelineView;
let currentData = null;
let selectedAgentId = 'npc_a';
let selectedExperienceId = null;
let selectedProfileId = null;

const BASE_W = 1360;
const BASE_H = 820;

function setup() {
  const container = document.getElementById('workbench-container');
  const targetW = Math.min(BASE_W, Math.max(900, (container ? container.clientWidth - 24 : BASE_W)));
  const scaleRatio = targetW / BASE_W;
  const targetH = Math.round(BASE_H * scaleRatio);

  const canvas = createCanvas(targetW, targetH);
  canvas.parent('canvas-wrapper');

  createViews(targetW, targetH, scaleRatio);

  const selectElem = document.getElementById('data-source-select');
  const refreshBtn = document.getElementById('btn-refresh');
  const playBtn = document.getElementById('btn-play');
  const stepBtn = document.getElementById('btn-step');
  const resetBtn = document.getElementById('btn-reset');

  if (selectElem) {
    selectElem.addEventListener('change', event => {
      window.workbenchAPI.setSourceMode(event.target.value);
      clearSelection();
      updatePlayButtonUI();
      loadData();
    });
  }
  if (refreshBtn) {
    refreshBtn.addEventListener('click', loadData);
  }
  if (playBtn) {
    playBtn.addEventListener('click', togglePlayback);
  }
  if (stepBtn) {
    stepBtn.addEventListener('click', stepPlayback);
  }
  if (resetBtn) {
    resetBtn.addEventListener('click', resetPlayback);
  }

  loadData();

  // Tick simulation loop (100ms when running in mock, 2000ms polling when in live)
  setInterval(() => {
    if (window.workbenchAPI.sourceMode === 'mock') {
      if (window.workbenchAPI.isRunning) {
        window.workbenchAPI.stepSimulation();
        updateStatus();
      }
    } else if (window.workbenchAPI.sourceMode === 'live') {
      loadData();
    }
  }, 120);
}

function togglePlayback() {
  const isRunning = window.workbenchAPI.toggleRun();
  updatePlayButtonUI();
  updateStatus();
}

function stepPlayback() {
  window.workbenchAPI.stepSimulation();
  updateStatus();
}

function resetPlayback() {
  window.workbenchAPI.resetSimulation();
  clearSelection();
  updatePlayButtonUI();
  loadData();
}

function updatePlayButtonUI() {
  const playBtn = document.getElementById('btn-play');
  if (!playBtn) return;
  if (window.workbenchAPI.isRunning) {
    playBtn.textContent = '⏸ Pause';
    playBtn.classList.add('active');
  } else {
    playBtn.textContent = '▶ Run';
    playBtn.classList.remove('active');
  }
}

function updateStatus() {
  const statusElem = document.getElementById('connection-status');
  if (statusElem) statusElem.textContent = window.workbenchAPI.statusText;
}

function createViews(w, h, scaleRatio) {
  // Proportional layouts based on target width
  const topH = Math.round(390 * scaleRatio);
  const midH = Math.round(190 * scaleRatio);
  const botH = Math.round(200 * scaleRatio);

  const leftW = Math.round(500 * scaleRatio);
  const midW = Math.round(300 * scaleRatio);
  const rightW = w - leftW - midW - 30;

  worldView = new WorldView(10, 10, leftW, topH);
  inspectorView = new InspectorView(leftW + 20, 10, midW, topH);
  memoryView = new MemoryView(leftW + midW + 30, 10, rightW, topH);
  lineageView = new LineageView(10, topH + 20, w - 20, midH);
  timelineView = new TimelineView(10, topH + midH + 30, w - 20, botH);
}

function windowResized() {
  const container = document.getElementById('workbench-container');
  if (!container) return;
  const targetW = Math.min(BASE_W, Math.max(900, container.clientWidth - 24));
  const scaleRatio = targetW / BASE_W;
  const targetH = Math.round(BASE_H * scaleRatio);

  resizeCanvas(targetW, targetH);
  createViews(targetW, targetH, scaleRatio);
}

function clearSelection() {
  selectedExperienceId = null;
  selectedProfileId = null;
}

async function loadData() {
  currentData = await window.workbenchAPI.fetchData();
  const statusElem = document.getElementById('connection-status');
  if (statusElem) statusElem.textContent = window.workbenchAPI.statusText;
}

function draw() {
  background(15, 20, 28);
  worldView.draw(this, currentData, selectedAgentId);
  inspectorView.draw(this, currentData, selectedAgentId);
  memoryView.draw(this, currentData, selectedAgentId, selectedProfileId, selectedExperienceId);
  lineageView.draw(this, currentData, selectedAgentId, selectedExperienceId, selectedProfileId);
  timelineView.draw(this, currentData, selectedAgentId, selectedExperienceId);

  updateCursor();
}

function updateCursor() {
  const hoveringAgent = worldView.checkAgentClick(mouseX, mouseY, currentData);
  const hoveringExp = timelineView.checkExperienceClick(mouseX, mouseY);
  const hoveringProf = memoryView.checkProfileClick(mouseX, mouseY);

  if (hoveringAgent || hoveringExp || hoveringProf) {
    cursor(HAND);
  } else {
    cursor(ARROW);
  }
}

function mousePressed() {
  const clickedAgent = worldView.checkAgentClick(mouseX, mouseY, currentData);
  if (clickedAgent) {
    selectedAgentId = clickedAgent;
    clearSelection();
    return;
  }

  const experienceId = timelineView.checkExperienceClick(mouseX, mouseY);
  if (experienceId) {
    selectedExperienceId = experienceId;
    const profiles = currentData?.relation_profiles?.profiles || [];
    const profile = profiles.find(item => item.source_experience_id === experienceId);
    selectedProfileId = profile?.profile_id || null;
    return;
  }

  const profileId = memoryView.checkProfileClick(mouseX, mouseY);
  if (profileId) {
    selectedProfileId = profileId;
    const profiles = currentData?.relation_profiles?.profiles || [];
    const profile = profiles.find(item => item.profile_id === profileId);
    selectedExperienceId = profile?.source_experience_id || null;
  }
}

function keyPressed() {
  // Hotkeys for rapid inspection & simulation
  if (key === '1') {
    selectedAgentId = 'npc_a';
    clearSelection();
  } else if (key === '2') {
    selectedAgentId = 'npc_b';
    clearSelection();
  } else if (key === ' ') {
    togglePlayback();
  } else if (key === 's' || key === 'S') {
    stepPlayback();
  } else if (key === 'r' || key === 'R') {
    loadData();
  } else if (key === 'Escape') {
    resetPlayback();
  }
}