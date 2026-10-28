const fs=require('fs'),path=require('path'),assert=require('assert/strict');
const root=process.argv[2];fs.mkdirSync(root,{recursive:false});
const base=JSON.parse(fs.readFileSync(path.join(__dirname,'channel_trial_spec.json')));
base.scene.mb_navigation_mode='goal_cues';base.scene.mb_exploration_relations=true;
base.config.days=3;base.config.seed=20261007;
for(const mode of ['standard','angle60','distance2','colors']){
 const input=structuredClone(base);input.scene.mb_scene_abstraction=mode;
 const check=structuredClone(input);delete check.scene.mb_scene_abstraction;assert.deepEqual(check,base);
 fs.writeFileSync(path.join(root,mode+'.json'),JSON.stringify(input),{flag:'wx'});
}
console.log('Prepared four inputs; only scene abstraction differs.');
