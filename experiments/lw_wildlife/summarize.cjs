const fs=require('fs'),path=require('path'),assert=require('assert/strict');
const [root,dest,baseline]=process.argv.slice(2);
if(!dest)throw Error('usage: summarize.cjs RUN OUTPUT.json [BASELINE_RUN]');
const read=p=>JSON.parse(fs.readFileSync(p));
const e=read(path.join(root,'evidence.json')),r=read(path.join(root,'run/result.json'));
let parity=null;
if(baseline){
 const old=read(path.join(baseline,'result.json')),input=read(path.join(root,'input.json'));
 delete input.scene.wildlife;assert.deepEqual(input,read(path.join(baseline,'spec.json')));
 for(const key of ['counts','final_agents','mb_map','events','day_starts'])assert.deepEqual(r[key],old[key],key);
 assert.deepEqual(r.daily.map(d=>d.physical),old.daily.map(d=>d.physical));
 parity={baseline:baseline,human_counts_final_mb_events_daily_positions_identical:true};
}
const output={days:e.days,config:e.config,wildlife_config:e.wildlife_config,measurement:e.measurement,
 grazing_update_seconds:e.grazing_update_seconds,wildlife:e.wildlife,humans:e.humans,food:e.food,parity,
 daily:e.daily.map(d=>({day:d.day,wildlife:d.wildlife,humans:Object.fromEntries(Object.entries(d.humans).map(([a,v])=>[a,{position:v.position,body:v.body,inventory:v.inventory,personal_stock:v.personal_stock}]))}))};
fs.writeFileSync(dest,JSON.stringify(output,null,2));
console.log(`Saved ${dest}; alive ${e.wildlife.alive}/${e.wildlife.count}; parity ${parity!==null}.`);
