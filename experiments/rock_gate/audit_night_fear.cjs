const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const [run,dest,caseName='ordinary']=process.argv.slice(2);
if(!dest)throw Error('usage: audit_night_fear.cjs RUN DEST [CASE]');
const read=f=>JSON.parse(fs.readFileSync(path.join(run,caseName,f),'utf8'));
const s=read('run/summary.json'),r=read('report.json'),out={measurement:s.measurement,actors:{}};
for(const[a,m]of Object.entries(s.mb_map)){
 const f=m.night_fear;
 assert.ok(f.evaluations>0&&f.requests<=f.evaluations&&f.anticipatory_evaluations<=f.evaluations);
 assert.ok(f.H>=0&&f.H<=8&&f.peak_H>=f.H&&f.peak_H<=8&&f.records.length<=64);
 for(const x of f.records){assert.ok(Number.isFinite(x.H)&&x.H>=0&&x.H<=8);assert.ok(x.increment>=0&&x.relief>=0);assert.ok(x.estimate.seconds>=0&&x.estimate.margin>=0);}
 out.actors[a]={fear:f,reserve:r.actors[a].reserve,returnPurpose:r.actors[a].return_purpose,
  inward:r.actors[a].inward,routeOutcomes:m.routes.outcomes,restReward:m.configured_home_rest_reward?.reward_total,
  counts:r.actors[a].counts,daily:r.actors[a].daily};
}
fs.writeFileSync(dest,JSON.stringify(out,null,2)+'\n');
console.log(JSON.stringify({...out,actors:Object.fromEntries(Object.entries(out.actors).map(([a,x])=>[a,{reserve:x.reserve,
 returnCompleted:x.returnPurpose.completed,inward:x.inward,routeOutcomes:x.routeOutcomes,restReward:x.restReward,
 peakH:x.fear.peak_H,finalH:x.fear.H,anticipatoryEvaluations:x.fear.anticipatory_evaluations,requests:x.fear.requests,foodBlocks:x.fear.food_blocks}]))},null,2));
