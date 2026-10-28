const fs=require('fs'),path=require('path'),assert=require('assert/strict');
const out=process.argv[2];if(!out)throw Error('usage: prepare.cjs INPUT.json');
const input=JSON.parse(fs.readFileSync(path.join(__dirname,'../rock_gate/channel_trial_spec.json')));
input.config.days=3;input.config.seed=20261007;
input.scene.mb_navigation_mode='goal_cues';input.scene.mb_exploration_relations=true;
input.scene.mb_scene_abstraction='standard';
input.scene.wildlife={enabled:true,count:30,seed:20261028,grass_scale:1,spawn_min_distance:8,spawn_max_distance:40};
assert(input.scene.food.every(f=>f.renewable===false));
fs.writeFileSync(out,JSON.stringify(input),{flag:'wx'});
console.log(JSON.stringify({days:3,humans:3,rabbits:30,seed:input.config.seed,wildlife:input.scene.wildlife,
  humanFood:input.scene.food.reduce((s,f)=>s+f.stock,0),humanFoodRenewal:false,grassRecoveryDays:2,
  predators:false,hunting:false,breeding:false,sceneAbstraction:'standard',firstDayObservation:true,
  hazards:input.config.hazards,sensitivity:input.config.mb_sensitivities},null,2));
