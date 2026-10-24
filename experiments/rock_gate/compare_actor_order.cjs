const fs=require('node:fs');const assert=require('node:assert/strict');
const read=p=>JSON.parse(fs.readFileSync(p,'utf8'));
const [oldPath,newPath,outPath]=process.argv.slice(2);
const old=read(oldPath),rev=read(newPath);const audit={actors:{}};
function equal(a,b){try{assert.deepStrictEqual(a,b);return true;}catch{return false;}}
for(const a of ['npc_a','npc_b','npc_c']){
 const x=old.events.filter(e=>e.actor===a),y=rev.events.filter(e=>e.actor===a);
 let i=0;while(i<Math.min(x.length,y.length)&&equal(x[i],y[i]))i++;
 audit.actors[a]={events_identical:i===x.length&&i===y.length,baseline_events:x.length,reversed_events:y.length,
 first_difference:i===x.length&&i===y.length?null:{baseline:x[i],reversed:y[i]},
 final_position_identical:equal(old.final_agents[a].position,rev.final_agents[a].position),
 baseline_position:old.final_agents[a].position,reversed_position:rev.final_agents[a].position,
 baseline_max_radius:old.final_agents[a].max_radius_observer_only,reversed_max_radius:rev.final_agents[a].max_radius_observer_only,
 baseline_counts:old.counts[a],reversed_counts:rev.counts[a],
 initial:old.day_starts[0][a],
 failed_resource_events:x.filter(e=>['not_found','unavailable','no_food'].includes(e.status)).map(e=>({us:e.us,action:e.action,status:e.status}))};
 delete audit.actors[a].initial.loops;delete audit.actors[a].initial.harvest;delete audit.actors[a].initial.social_model;
}
fs.writeFileSync(outPath,JSON.stringify(audit,null,2));console.log(JSON.stringify(audit,null,2));
