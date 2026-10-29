// Saved-result analysis only; never starts or resumes a simulation.
const fs=require('fs'),path=require('path'),assert=require('assert/strict'),crypto=require('crypto');
const [root,dest,baseline]=process.argv.slice(2);
if(!root||!dest)throw Error('usage: summarize.cjs RUN OUTPUT.json [PREVIOUS_1D_RUN]');
const read=p=>JSON.parse(fs.readFileSync(p,'utf8').replace(/^\uFEFF/,''));
const r=read(path.join(root,'run/result.json')),s=read(path.join(root,'run/summary.json'));
const input=read(path.join(root,'input.json')),manifest=read(path.join(root,'run/manifest.json'));
const completed=read(path.join(root,'completed.json'));
const incidental=input.scene.incidental_items===true;
const sum=xs=>xs.reduce((a,b)=>a+b,0),ids=Object.keys(r.final_agents).sort();
const delta=(a,b={})=>Object.fromEntries(Object.entries(a).map(([k,v])=>[k,v-(b[k]||0)]));
assert.equal(r.daily.length,input.config.days);assert.equal(completed.days,input.config.days);
const daily=r.daily.map((d,i)=>{
 const stocks=sum(Object.values(d.physical).map(a=>a.inventory+a.personal_stock));
 assert.equal(r.initial_food+d.replenished_food,d.ground+d.shared_stock+d.consumed+stocks);
 assert.deepEqual(d.portable_items.remaining_counts,r.portable_items.initial_counts);
 const previous=i?r.daily[i-1]:null;
 return {day:i+1,food:{ground:d.ground,held_and_stored:stocks,consumed:d.consumed,added:d.replenished_food},
  trade_new:delta(d.food_exchange.world.counts,previous?.food_exchange.world.counts),
  humans:Object.fromEntries(ids.map(a=>[a,{body:d.physical[a].body,position:d.physical[a].position,
   inventory:d.physical[a].inventory,personal_stock:d.physical[a].personal_stock,
   actions_new:delta(d.counts[a],previous?.counts[a]),
   contact_seconds:Object.fromEntries(Object.entries(d.social_relationships[a].peers).map(([b,v])=>[b,v.contact_seconds]))}])),
  wildlife_alive:d.wildlife.alive,
  ...(incidental?{incidental_new:Object.fromEntries(ids.map(a=>[a,Object.fromEntries(
   ['decisions','continued','selected','succeeded','failed','ignored'].map(k=>[k,d.incidental_items[a][k]-(previous?.incidental_items[a][k]||0)]))]))}:{})};
});
const agents=Object.fromEntries(ids.map(a=>{
 const f=r.final_agents[a],rel=r.social_relationships[a],meals=r.food_resources.meals.filter(m=>m.actor===a);
 return [a,{body:f.body,position:f.position,home_distance:Math.hypot(f.position[0]-input.scene.home[0],f.position[1]-input.scene.home[1]),
  inventory:f.inventory,personal_stock:f.personal_stock,food_counts:r.food_resources.personal[a],
  min_day_end_reserve:Math.min(...r.daily.map(d=>d.physical[a].body.reserve)),actions:r.counts[a],
  successful_deposit_events:r.events.filter(e=>e.actor===a&&e.action==='deposit'&&e.status==='performed').length,
  meals_retained:meals.length,meal_kinds_retained:r.food_resources.labels.map((_,i)=>meals.filter(m=>m.kind===i+1).length),
  social_mb:{nodes:Object.keys(rel.mb.nodes).length,reviews:rel.mb.reviews.length},
  peers:Object.fromEntries(Object.entries(rel.peers).map(([b,v])=>[b,{contact_seconds:v.contact_seconds,
   trade_participation:v.trade_offer.exchanged+v.trade_response.exchanged,trade_food_value_sum:v.trade_value_sum}]))}];
}));
if(incidental){
 assert.equal(r.portable_items.counts.picked_up,sum(Object.values(r.incidental_items).map(x=>x.succeeded)));
 assert.ok(Object.entries(r.portable_items.counts).every(([k,v])=>['picked_up','unavailable'].includes(k)||v===0));
}else assert.ok(Object.values(r.portable_items.counts).every(v=>v===0));
const meal_history_complete=r.food_resources.meals.length===sum(r.food_resources.consumed);
if(meal_history_complete)for(const a of ids)assert.equal(agents[a].meals_retained,r.counts[a].eat);
const checkpoints=Array.from({length:r.daily.length},(_,i)=>{
 const p=path.join(root,'checkpoints',`day-${String(i+1).padStart(3,'0')}.jls`),st=fs.statSync(p);
 return {day:i+1,bytes:st.size,modified_utc:st.mtime.toISOString(),mtime_ms:st.mtimeMs};
});
checkpoints.forEach((d,i)=>{d.interval_seconds=i?(d.mtime_ms-checkpoints[i-1].mtime_ms)/1000:null;});
checkpoints.forEach(d=>delete d.mtime_ms);
let first_day_match=null;
if(baseline)first_day_match=require('util').isDeepStrictEqual(r.daily[0],read(path.join(baseline,'run/result.json')).daily[0]);
const output={date:'2026-10-30',days:r.daily.length,input_sha256:manifest.spec_sha256,
 result_sha256:crypto.createHash('sha256').update(fs.readFileSync(path.join(root,'run/result.json'))).digest('hex'),
 measurement:s.measurement,first_day_matches_previous:first_day_match,meal_history_complete,agents,
 food:{initial:r.initial_food,ground:r.ground,consumed:r.consumed,added:r.replenished_food,
  personal:sum(ids.map(a=>r.final_agents[a].personal_stock)),consumed_by_kind:r.food_resources.consumed,
  processed_inputs:r.food_resources.processed_inputs},exchange:r.food_exchange.world.counts,
 items:{kind_ids:r.portable_items.kind_ids,initial:r.portable_items.initial_counts,remaining:r.portable_items.remaining_counts,counts:r.portable_items.counts,
 ...(incidental?{locations:r.portable_items.items.map(({id,kind,location,owner})=>({id,kind,location,owner})),
 actors:Object.fromEntries(ids.map(a=>{const m=r.incidental_items[a];return [a,{
  ...Object.fromEntries(['decisions','continued','selected','succeeded','failed','ignored'].map(k=>[k,m[k]])),
  records:m.records,memory_count:Object.keys(m.memory).length,metric_updates:m.metric.updates,weights:m.metric.weights}];})),
 followups:ids.flatMap(a=>{const events=r.events.filter(e=>e.actor===a);return events.flatMap((e,i)=>e.incidental_item?[{actor:a,pickup:e,next:events[i+1]||null}]:[]);})}:{})},
 wildlife:{count:r.wildlife.count,alive:r.wildlife.alive,starvation_deaths:r.wildlife.starvation_deaths,
  grass_initial:r.wildlife.grass_initial,grass_grown:r.wildlife.grass_grown,grass_eaten:r.wildlife.grass_eaten,grass_remaining:r.wildlife.grass_remaining},
 checkpoints,daily};
fs.writeFileSync(dest,JSON.stringify(output,null,2)+'\n');
console.log(JSON.stringify({saved:dest,days:output.days,first_day_match,food:output.food,exchange:output.exchange,
 seconds:output.measurement.call_seconds,day_intervals:checkpoints.slice(1).map(d=>d.interval_seconds)}));
