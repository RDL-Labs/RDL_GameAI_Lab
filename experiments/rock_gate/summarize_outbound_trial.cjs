const fs=require('fs'),path=require('path');
const run=process.argv[2],dest=process.argv[3];
const read=f=>JSON.parse(fs.readFileSync(path.join(run,f)));
const r=read('ordinary/run/result.json'),s=read('ordinary/run/summary.json');
const result={run,measurement:s.measurement,food:s.food,days:r.daily.length,actors:{}};
for(const [id,a] of Object.entries(r.final_agents)){
 const e=r.mb_map[id].exploration_relations;
 const links=Object.values(e?.links||{});
 result.actors[id]={body:a.body,position:a.position,deposit:r.counts[id].deposit||0,
  relations:e?{scenes:Object.keys(e.scenes).length,links:links.length,created:e.created,selected:e.selected,
   observed:e.observed,missing:e.missing,blocked:e.blocked,offered:e.offered,used:e.used,
   supported:links.filter(l=>l.support>0).length,approached:links.filter(l=>l.approach_evidence>0).length,
   maxArrival:Math.max(0,...links.map(l=>l.arrival_evidence)),
   firstRecords:e.records.slice(0,3)}:null};
}
result.daily=r.daily.map((d,i)=>({day:i+1,ground:d.ground,shared:d.shared_stock,consumed:d.consumed,
 actors:Object.fromEntries(Object.entries(d.physical).map(([id,a])=>[id,{reserve:a.body.reserve,position:a.position,deposit:d.counts[id]?.deposit||0}]))}));
fs.writeFileSync(dest,JSON.stringify(result,null,2));
console.log(JSON.stringify(result));
