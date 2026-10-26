const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const [run,dest,caseName='ordinary']=process.argv.slice(2);
if(!dest)throw Error('usage: audit_boundary_crossings.cjs RUN DEST [CASE]');
const dir=path.join(run,caseName),read=f=>JSON.parse(fs.readFileSync(path.join(dir,f),'utf8'));
const r=read('run/result.json'),input=read('input.json'),home=input.scene.home;
const crossings=fs.readFileSync(path.join(dir,'crossings.jsonl'),'utf8').trim().split('\n').filter(Boolean).map(JSON.parse);
const radius=p=>Math.hypot(p[0]-home[0],p[1]-home[1]);
const result={note:'Carry forward per-actor event signature, which is logged whenever it changes. Radius 5 is observer-only; arrival is visible home within 1.25.',actors:{},days:{},examples:[]};
for(const actor of Object.keys(r.final_agents)){
 const events=r.events.filter(e=>e.actor===actor),es=crossings.filter(e=>e.actor===actor);let index=0;
 const actorResult={inward:0,outward:0,byMethodGroup:{},outsideIntervals:[],observation:r.home_observation[actor]};
 actorResult.observation={origin:actorResult.observation.origin,maxDisplacement:actorResult.observation.max_displacement,actions:actorResult.observation.actions};
 result.actors[actor]=actorResult;
 for(let i=0;i<es.length;i++){
  const c=es[i],us=(c.sec-1)*1e6;
  while(index+1<events.length && events[index+1].us<=us)index++;
  const e=events[index];assert.ok(e.us<=us);assert.ok(['walk','run'].includes(e.action));
  const group=/^(walk|run)_-?\d+$/.test(e.method||'')?'safety':e.method==='configured_observation'?'configured_observation':(e.method||'').startsWith('mb_')?'MB':'other';
  const day=Math.ceil(c.sec/17280),d=result.days[day]??={crossings:0,inward:0,byMethodGroup:{},returnActive:0};
  d.crossings++;d.inward+=Number(c.direction==='in');d.returnActive+=Number(c.return_active);d.byMethodGroup[group]=(d.byMethodGroup[group]||0)+1;
  actorResult[c.direction==='in'?'inward':'outward']++;
  actorResult.byMethodGroup[group]=(actorResult.byMethodGroup[group]||0)+1;
  if(c.direction==='out' && es[i+1]?.direction==='in')actorResult.outsideIntervals.push(es[i+1].sec-c.sec);
  if(result.examples.filter(x=>x.day===day&&x.group===group).length<2)result.examples.push({actor,day,sec:c.sec,direction:c.direction,group,method:e.method,phase:e.phase,purpose:e.purpose_family,returnActive:c.return_active,fromRadius:radius(c.from),toRadius:radius(c.to)});
 }
 const ds=actorResult.outsideIntervals.sort((a,b)=>a-b);
 actorResult.outsideIntervalSummary={count:ds.length,atMost10Seconds:ds.filter(x=>x<=10).length,medianSeconds:ds[Math.floor(ds.length/2)]??null,maxSeconds:ds.at(-1)??null};
 delete actorResult.outsideIntervals;
 actorResult.safety={entries:r.safety[actor].entries,overrides:r.safety[actor].overrides};
}
fs.writeFileSync(dest,JSON.stringify(result,null,2)+'\n');console.log(JSON.stringify(result,null,2));
