const fs=require('node:fs');
const assert=require('node:assert/strict');
const path=require('node:path');
const [run,previous]=process.argv.slice(2);
const read=p=>JSON.parse(fs.readFileSync(p,'utf8'));
const now=read(path.join(run,'narrow/run/result.json'));
const old=read(path.join(previous,'narrow/run/result.json'));
assert.deepStrictEqual(now.daily.slice(0,old.daily.length),old.daily);
assert.deepStrictEqual(now.day_starts.slice(0,old.daily.length),old.day_starts);
const until=old.ended_us;
assert.deepStrictEqual(now.events.filter(e=>e.us<until),old.events);
const report=read(path.join(run,'comparison.json'))[0];
const summary={prefix_days:old.daily.length,prefix_daily_exact:true,prefix_events_exact:true,days:now.daily.length,actors:{}};
for(const [a,v] of Object.entries(report.actors)){
 const loops=now.daily.at(-1).physical[a].loops;
 summary.actors[a]={outward:v.outward,inward:v.inward,reserve:v.reserve,counts:v.counts,return_purpose:v.return_purpose,max_radius:v.max_radius,
 food_H:loops.food.H,food_reward:Object.values(loops.food.methods).reduce((s,n)=>s+n.reward,0),
 daily:v.daily.map(d=>({day:d.day,reserve:d.reserve,return_active:d.return_purpose.active,return_completed:d.return_purpose.completed}))};
}
fs.writeFileSync(path.join(run,'prefix-audit.json'),JSON.stringify(summary,null,2));
console.log(JSON.stringify(summary,null,2));
