// Summarize a completed run without changing the simulation or actor policy.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const [run,dest]=process.argv.slice(2);
if(!run||!dest) throw new Error('usage: summarize_food_days.cjs RUN OUTPUT_JSON');
const read=p=>JSON.parse(fs.readFileSync(p,'utf8').replace(/^\uFEFF/,''));
const result=read(path.join(run,'narrow/run/result.json'));
const summary=read(path.join(run,'narrow/run/summary.json'));
const report=read(path.join(run,'narrow/report.json'));
const input=read(path.join(run,'narrow/input.json'));
const actors=Object.keys(result.final_agents).sort(),ticksPerDay=input.clock.day_us/1e6;
assert.equal(result.daily.length,input.config.days);
const daily=result.daily.map((d,i)=>{
  const previous=i?result.daily[i-1]:null;
  const physical=d.physical;
  const carried=actors.reduce((s,a)=>s+physical[a].inventory,0);
  const personal=actors.reduce((s,a)=>s+physical[a].personal_stock,0);
  assert.equal(result.initial_food+d.replenished_food,d.ground+d.shared_stock+d.consumed+carried+personal);
  return {day:i+1,ground:d.ground,replenished:d.replenished_food,consumed:d.consumed,shared:d.shared_stock,carried,
    actors:Object.fromEntries(actors.map(a=>{
      const p=physical[a],counts=d.counts[a],old=previous?.counts[a]??{};
      const actions=Object.fromEntries(Object.entries(counts).map(([k,v])=>[k,v-(old[k]??0)]));
      assert.equal(Object.values(actions).reduce((s,v)=>s+v,0),ticksPerDay);
      assert.ok(Number.isFinite(p.body.reserve));
      return [a,{reserve:p.body.reserve,position:p.position,inventory:p.inventory,
        return_active:p.return_purpose.active,return_completed:p.return_purpose.completed,
        home_H:p.loops.home.H,actions}];
    }))};
});
const audit=Object.fromEntries(actors.map(a=>[a,{
  outward:report.actors[a].outward,inward:report.actors[a].inward,
  return_completed:report.actors[a].return_purpose.completed,
  final_reserve:report.actors[a].reserve,
  zero_reserve_day_ends:daily.filter(d=>d.actors[a].reserve<=0).map(d=>d.day),
  all_rest_days:daily.filter(d=>d.actors[a].actions.rest===ticksPerDay).map(d=>d.day)
}]));
const out={days:daily.length,seed:input.config.seed,measurement:summary.measurement,
  initial_food:result.initial_food,replenished_food:result.replenished_food,
  replenishments:result.replenishments,consumed:result.consumed,
  remaining_by_site:result.world_checkpoint.stock,
  shared_storage:result.shared_storage,dropped_cargo:result.dropped_cargo,
  actors:audit,daily};
fs.writeFileSync(dest,JSON.stringify(out,null,2));
console.log(JSON.stringify({days:out.days,initial:out.initial_food,replenished:out.replenished_food,
  consumed:out.consumed,remaining:out.remaining_by_site,storage:out.shared_storage,actors:audit},null,2));
