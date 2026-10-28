const fs=require('fs'),path=require('path'),assert=require('assert/strict');
const root=process.argv[2],dest=process.argv[3],out={root,cases:{}};
for(const mode of ['standard','angle60','distance2','colors']){
 const run=path.join(root,mode),r=JSON.parse(fs.readFileSync(path.join(run,'ordinary/run/result.json'))),
 s=JSON.parse(fs.readFileSync(path.join(run,'ordinary/run/summary.json')));
 assert.equal(r.daily.length,3);
 const actors={};
 for(const [id,m]of Object.entries(r.mb_map)){
  assert.equal(m.scene_abstraction,mode);
  const e=m.exploration_relations,a=r.final_agents[id];
  actors[id]={reserve:a.body.reserve,position:a.position,deposit:r.counts[id].deposit||0,
   minDayEndReserve:Math.min(...r.daily.map(d=>d.physical[id].body.reserve)),
   nodes:Object.keys(m.nodes).length,edges:Object.keys(m.edges).length,chunks:Object.keys(m.chunks).length,
   scenes:Object.keys(e.scenes).length,relations:Object.keys(e.links).length,
   relationUsed:e.used,goalCueUsed:m.goal_cues?.selected||0,
   prediction:{match:m.prediction_match,miss:m.prediction_miss,unknown:m.prediction_unknown},
   routes:m.routes.outcomes,localRepairs:m.routes.local_repairs,localRejoins:m.routes.local_rejoins,
   mbJSONBytes:Buffer.byteLength(JSON.stringify(m)),sceneJSONBytes:Buffer.byteLength(JSON.stringify(m.nodes))};
 }
 out.cases[mode]={measurement:s.measurement,food:s.food,actors};
}
fs.writeFileSync(dest,JSON.stringify(out,null,2));
for(const [mode,c]of Object.entries(out.cases))console.log(JSON.stringify({mode,seconds:c.measurement.call_seconds,
 nodes:Object.values(c.actors).reduce((n,a)=>n+a.nodes,0),edges:Object.values(c.actors).reduce((n,a)=>n+a.edges,0),
 sceneBytes:Object.values(c.actors).reduce((n,a)=>n+a.sceneJSONBytes,0),
 actors:Object.fromEntries(Object.entries(c.actors).map(([id,a])=>[id,{reserve:a.reserve,deposit:a.deposit,nodes:a.nodes,edges:a.edges,relations:a.relations}]))}));
