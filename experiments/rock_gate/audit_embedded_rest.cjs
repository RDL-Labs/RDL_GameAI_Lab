const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const [run,dest,caseName='ordinary']=process.argv.slice(2);
if(!dest)throw Error('usage: audit_embedded_rest.cjs RUN DEST [CASE]');
const read=f=>JSON.parse(fs.readFileSync(path.join(run,caseName,f),'utf8'));
const s=read('run/summary.json'),report=read('report.json'),result={measurement:s.measurement,actors:{}};
for(const [actor,m]of Object.entries(s.mb_map)){
 const e=m.embedded_rest,r=m.configured_home_rest_reward;
 assert.ok(e && e.decisions>0 && e.selections<=e.decisions && e.food_blocks<=e.decisions);
 assert.ok(e.records.length<=64 && e.experience.length<=64);
 assert.ok(e.experience.every(x=>Number.isFinite(x)&&x>=0&&x<=1));
 assert.ok(e.place_value>=0&&e.place_value<=1&&e.awake_seconds>=0&&e.awake_seconds<=17280);
 for(const x of e.records)assert.ok(x.probability>=0&&x.probability<=1&&x.need>=0&&x.need<=1);
 assert.ok(new Set(r.records.map(x=>x.day)).size===r.records.length);
 assert.equal(r.reward_total,r.records.reduce((a,x)=>a+x.reward,0));
 result.actors[actor]={reserve:report.actors[actor].reserve,returnPurpose:report.actors[actor].return_purpose,
  inward:report.actors[actor].inward,outward:report.actors[actor].outward,
  embedded:e,restReward:r,routeOutcomes:m.routes.outcomes,chunkFormations:m.chunk_formations,
  counts:report.actors[actor].counts};
}
fs.writeFileSync(dest,JSON.stringify(result,null,2)+'\n');
console.log(JSON.stringify({...result,actors:Object.fromEntries(Object.entries(result.actors).map(([a,x])=>[a,{reserve:x.reserve,
 returnCompleted:x.returnPurpose.completed,inward:x.inward,restReward:x.restReward.reward_total,
 decisions:x.embedded.decisions,selections:x.embedded.selections,foodBlocks:x.embedded.food_blocks,
 placeValue:x.embedded.place_value,experienceCount:x.embedded.experience.length,routeOutcomes:x.routeOutcomes}]))},null,2));
