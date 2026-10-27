const fs=require('node:fs'),path=require('node:path');
const [run,dest]=process.argv.slice(2);
const r=JSON.parse(fs.readFileSync(path.join(run,'ordinary/run/result.json')));
const summary=JSON.parse(fs.readFileSync(path.join(run,'ordinary/run/summary.json')));
const out={measurement:summary.measurement,storage:r.shared_storage,stock:r.world_checkpoint.stock,actors:{}};
for(const [a,m] of Object.entries(r.mb_map)){
 const actor=r.final_agents[a];
 out.actors[a]={reserve:actor.body.reserve,position:actor.position,
  home_distance:Math.hypot(actor.position[0],actor.position[1]-6),inventory:actor.inventory,
  deliveries:m.configured_daily_delivery.records.map(x=>({...x,day:x.day+1})),
  goals:Object.fromEntries(Object.entries(m.goal_arrival).map(([g,s])=>[g,{
   mode:s.mode,entries:s.entries,rejections:s.rejections,selected:s.selected,completed:s.completed||0,
   rho_fine_decisions:s.rho_fine_decisions||0,rho_baseline:s.rho_baseline,rho_effective:s.rho_effective,
   parent_mode:m.parent_mb.modes[g].mode,
   // Transition logs are bounded to the last 64, not whole-run event totals.
   retained_parent_events:m.parent_mb.modes[g].events}]))};
}
fs.writeFileSync(dest,JSON.stringify(out,null,2));
console.log(JSON.stringify({measurement:out.measurement,actors:Object.fromEntries(Object.entries(out.actors).map(([a,s])=>[a,{reserve:s.reserve,home_distance:s.home_distance,deliveries:s.deliveries,goals:Object.fromEntries(Object.entries(s.goals).map(([g,t])=>[g,{entries:t.entries,completed:t.completed,rejections:t.rejections,outcome_events_retained:t.retained_parent_events.filter(e=>typeof e.success==="boolean")}]))}]))},null,2));
