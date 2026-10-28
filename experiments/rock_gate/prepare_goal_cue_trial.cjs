// Only the navigation policy changes; the runner sets duration and choice seed.
const fs = require('fs');
const assert = require('assert/strict');
const path = require('path');
const original = JSON.parse(fs.readFileSync(path.join(__dirname, 'channel_trial_spec.json')));
const input = structuredClone(original);
input.scene.mb_navigation_mode = 'goal_cues';
if (process.argv.includes('--outbound-relations')) input.scene.mb_exploration_relations = true;
const check = structuredClone(input);
delete check.scene.mb_navigation_mode;
delete check.scene.mb_exploration_relations;
assert.deepEqual(check, original);
fs.writeFileSync(process.argv[2], JSON.stringify(input), {flag: 'wx'});
console.log('Prepared: only navigation/optional outbound relation settings differ.');
