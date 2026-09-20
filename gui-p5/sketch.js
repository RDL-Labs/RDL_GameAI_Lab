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

function setup() {
  const canvas = createCanvas(1360, 820);
  canvas.parent('canvas-wrapper');

  worldView = new WorldView(10, 10, 500, 390);
  inspectorView = new InspectorView(520, 10, 300, 390);
  memoryView = new MemoryView(830, 10, 520, 390);
  lineageView = new LineageView(10, 410, 1340, 190);
  timelineView = new TimelineView(10, 610, 1340, 200);

  const selectElem = document.getElementById('data-source-select');
  const refreshBtn = document.getElementById('btn-refresh');
  selectElem.addEventListener('change', event => {
    window.workbenchAPI.setSourceMode(event.target.value);
    clearSelection();
    loadData();
  });
  refreshBtn.addEventListener('click', loadData);
  loadData();

  setInterval(() => {
    if (window.workbenchAPI.sourceMode === 'live') loadData();
  }, 2000);
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