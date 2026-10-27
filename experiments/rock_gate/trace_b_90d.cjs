const fs=require('fs'),path=require('path');
const [root,dest]=process.argv.slice(2),r=JSON.parse(fs.readFileSync(path.join(root,'ordinary/run/result.json')));
const events=r.events.filter(e=>e.actor==='npc_b'&&Number.isFinite(e.us)).sort((a,b)=>a.us-b.us),days=[];
for(let day=2;day<=90;day++){
 const current=r.daily[day-1],prior=r.daily[day-2],c=current.counts.npc_b;
 const counts=Object.fromEntries(Object.entries(c).map(([k,v])=>[k,v-(prior.counts.npc_b[k]||0)]));
 if(counts.deposit>0)continue;
 const lo=(day-1)*17280,hi=day*17280,durations={},segments=[];
 for(let i=0;i<events.length;i++){
  const e=events[i],start=Math.max(lo,e.us/1e6),end=Math.min(hi,events[i+1] ? events[i+1].us/1e6 : 90*17280);
  if(end<=start)continue;
  const key=[e.purpose_family,e.action,e.method].join(':');durations[key]=(durations[key]||0)+end-start;
  if(end-start>=300)segments.push({start,end,seconds:end-start,...e});
 }
 const f=current.physical.npc_b;
 days.push({day,counts,reserve:f.body.reserve,position:f.position,inventory:f.inventory,
  home_distance:Math.hypot(f.position[0],f.position[1]-6),durations,
  long_segments:segments,food_events:events.filter(e=>e.us/1e6>=lo&&e.us/1e6<hi&&['pickup','eat','deposit','retrieve','request','give'].includes(e.action))});
}
fs.writeFileSync(dest,JSON.stringify({actor:'npc_b',scope:'Action durations inferred between change events; counts from daily cumulative deltas.',days},null,2));
for(const d of days) console.log(JSON.stringify({day:d.day,counts:d.counts,dominant:Object.entries(d.durations).sort((a,b)=>b[1]-a[1]).slice(0,4),food:d.food_events.map(e=>[e.us/1e6,e.action,e.method])}));
