const fs=require('fs');
const [base,out]=process.argv.slice(2);
const trace=fs.readFileSync(out+'/trace.jsonl','utf8').trim().split('\n').map(JSON.parse);
const cases=[['A-D','npc_a','npc_d',93966000000,94093000000],['C-B','npc_c','npc_b',107873000000,108000000000]];
const summary=[];
for(const [label,a,b,lo,hi] of cases){
 const rows=trace.filter(t=>t.us>=lo&&t.us<hi);
 for(const [actor,peer] of [[a,b],[b,a]]){
  const observed=rows.filter(t=>t.actors[actor].social_sight?.peers.some(p=>p.ref===peer));
  summary.push({case:label,actor,peer,ticks:rows.length,
   observation_missing:rows.filter(t=>!t.actors[actor].social_sight).length,
   observed:observed.length,observed_wait:observed.filter(t=>t.actors[actor].method==='camp_trade_wait').length,
   observed_approach:observed.filter(t=>t.actors[actor].method==='camp_trade_meeting').length,
   occluded:rows.filter(t=>t.actors[actor].geometry[peer].occluded).length,
   outside_fov:rows.filter(t=>Math.abs(t.actors[actor].geometry[peer].bearing)>90).length,
   first_observed:observed.length?{us:observed[0].us,...observed[0].actors[actor].geometry[peer],method:observed[0].actors[actor].method}:null});
 }
}
const original=JSON.parse(fs.readFileSync(base+'/run/result.json'));
const replay=JSON.parse(fs.readFileSync(out+'/run/result.json'));
const filter=e=>cases.some(([,a,b,lo,hi])=>e.us>=lo&&e.us<hi);
const result={summary,window_events_identical:JSON.stringify(original.events.filter(filter))===JSON.stringify(replay.events.filter(filter))};
console.log(JSON.stringify(result,null,2));fs.writeFileSync(out+'/sight-summary.json',JSON.stringify(result,null,2));
