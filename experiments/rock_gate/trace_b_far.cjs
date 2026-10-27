const fs=require('fs'),path=require('path');
const sharp=require('C:/Users/ken_m/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const root=process.argv[2],dest=process.argv[3];fs.mkdirSync(dest,{recursive:true});
const read=f=>JSON.parse(fs.readFileSync(path.join(root,'ordinary',f)));
const r=read('run/result.json'),ps=read('positions.json').filter(x=>x.actor==='npc_b'),es=r.events.filter(x=>x.actor==='npc_b'),days=[];
for(let day=4;day<=10;day++){
 const lo=(day-1)*17280,hi=day*17280,p=ps.filter(x=>x.sec>=lo&&x.sec<=hi);let durations={},counts={};
 for(let i=0;i<es.length;i++){const e=es[i],s=Math.max(lo,e.us/1e6),t=Math.min(hi,(es[i+1]?.us??172800e6)/1e6);if(t<=s)continue;const key=e.purpose_family+':'+e.action;durations[key]=(durations[key]||0)+t-s;counts[e.action]=(counts[e.action]||0)+t-s;}
 const distance=p=>Math.hypot(p.position[0],p.position[1]-10.83);
 const nearest=p.reduce((a,b)=>distance(a)<distance(b)?a:b);
 days.push({day,durations,counts,nearest_gate:{...nearest,distance:distance(nearest)},end:r.daily[day-1].physical.npc_b.position,inventory:r.daily[day-1].physical.npc_b.inventory,homeH:r.daily[day-1].physical.npc_b.loops.home.H});
}
const summary={days,arrival:r.mb_map.npc_b.goal_arrival.home.records.filter(x=>x.us>=51840e6),food_events:es.filter(x=>x.us>=51840e6&&['pickup','eat','deposit','retrieve'].includes(x.action))};
fs.writeFileSync(path.join(dest,'b-trace.json'),JSON.stringify(summary,null,2));console.log(JSON.stringify(days));
(async()=>{const imgs=[];for(let d=4;d<=10;d++){const png=await sharp(path.join('outputs/far-10d-daily-paths',`day-${String(d).padStart(2,'0')}.png`)).extract({left:540,top:90,width:495,height:535}).resize(396,428).png().toBuffer();const x=((d-4)%4)*410,y=50+Math.floor((d-4)/4)*470;imgs.push({input:png,left:x,top:y+25});const title=Buffer.from(`<svg width="396" height="25"><text x="10" y="20" font-family="sans-serif" font-size="18">DAY ${d}</text></svg>`);imgs.push({input:title,left:x,top:y});}const title=Buffer.from('<svg width="1640" height="50"><text x="10" y="30" font-family="sans-serif" font-size="24">B / Days 4-10 / blue → purple: time within each day / sampled every 60 seconds</text></svg>');imgs.push({input:title,left:0,top:0});await sharp({create:{width:1640,height:1000,channels:3,background:'#f4f5f0'}}).composite(imgs).png().toFile(path.join(dest,'b-days4-10.png'));})();
