const fs=require('fs'),path=require('path'),rl=require('readline');
const run=process.argv[2];if(require.main===module&&!run)throw Error('usage: diagnose_mb.cjs RUN [TEN_DAY_BASELINE]');
const read=f=>JSON.parse(fs.readFileSync(f,'utf8'));
const DAY=17280000000;
const cmp=(a,b)=>a<b?-1:a>b?1:0;
function distance(g,start,goal,now,{fresh=true,depth=4,run=false,undirected=false,allowed=null}={}){
 const adj=new Map();for(const[k,e]of Object.entries(g.edges)){
 if(!['walk','scan',...(run?['run']:[])].includes(e.action)||(fresh&&now-e.seen>DAY))continue;
 if(!adj.has(e.from))adj.set(e.from,[]);adj.get(e.from).push([e.to,k]);
 if(undirected){if(!adj.has(e.to))adj.set(e.to,[]);adj.get(e.to).push([e.from,k]);}
 }
 const q=[[start,0]],seen=new Set([start]);
 for(let i=0;i<q.length;i++){
  const [u,d]=q[i];if(d>=depth)continue;
  for(const [v,k]of adj.get(u)||[]){
   if(d===0&&allowed&&!allowed.includes(k))continue;
   const n=g.nodes[v];if(v!==start&&n&&n[goal]&&(!fresh||now-n.seen<=DAY))return d+1;
   if(!seen.has(v)){seen.add(v);q.push([v,d+1]);}
  }
 }
 return null;
}
function actual(g,start,goal,now,allowed=null){
 let q=[{node:start,path:[],cost:0,seen:new Set([start])}],expanded=0;
 const sort=()=>q.sort((a,b)=>a.cost-b.cost||cmp(a.path.join('/'),b.path.join('/')));
 const cost=e=>1+e.energy_sum/Math.max(1,e.samples)+2/(1+e.samples+e.matches)+2*Math.log1p(e.misses);
 while(q.length&&expanded<64){
 sort();const x=q.shift();expanded++;const n=g.nodes[x.node];
 if(x.path.length&&n&&n[goal]&&now-n.seen<=DAY)return x.path.length;
 if(x.path.length>=4)continue;
 const es=Object.entries(g.edges).filter(([k,e])=>e.from===x.node&&!x.seen.has(e.to)&&['walk','scan'].includes(e.action)&&now-e.seen<=DAY).sort(([a,e],[b,f])=>cost(e)-cost(f)||cmp(a,b)).slice(0,8);
 for(const[k,e]of es){if(!x.path.length&&allowed&&!allowed.includes(k))continue;
 q.push({node:e.to,path:[...x.path,k],cost:x.cost+cost(e),seen:new Set([...x.seen,e.to])});}
 sort();q=q.slice(0,64);
 }return null;
}
async function main(){
const actors={};const homeHistory={};
for await(const line of rl.createInterface({input:fs.createReadStream(path.join(run,'mb-observations.jsonl')),crlfDelay:Infinity})){
 if(!line)continue;const r=JSON.parse(line),a=r.actor;
 const s=actors[a]??=( {observations:0,valid:0,reasons:{},resets:{},trace_loss:{},valid_to_invalid:0,valid_key_changes:0,stationary_key_changes:0,stationary_same_yaw_key_changes:0,home_entries:[],home_observations:0,home_valid:0,physical_bins:new Map(),view_bins:new Map(),key_spatial:new Map(),recent:[],prev:null});
 s.observations++;if(r.key)s.valid++;s.reasons[r.reason]=(s.reasons[r.reason]||0)+1;s.resets[r.reset]=(s.resets[r.reset]||0)+1;
 if(r.trace_before>0&&r.trace_after===0)s.trace_loss[r.reset]=(s.trace_loss[r.reset]||0)+1;
 if(r.home){s.home_observations++;if(r.key){s.home_valid++;(homeHistory[a]??={})[r.key]??=r.us;}}
 if(r.key){let k=s.key_spatial.get(r.key);if(!k)s.key_spatial.set(r.key,k={first:r.position,max_distance:0,home:0,away:0});k.max_distance=Math.max(k.max_distance,Math.hypot(r.position[0]-k.first[0],r.position[1]-k.first[1]));if(r.home)k.home++;else k.away++;}
 let prev=s.prev;
 if(prev){
 if(prev.key&&!r.key)s.valid_to_invalid++;
 if(prev.key&&r.key&&prev.key!==r.key){
 s.valid_key_changes++;
 if(Math.hypot(r.position[0]-prev.position[0],r.position[1]-prev.position[1])<1e-9){
 s.stationary_key_changes++;if(Math.abs(r.yaw-prev.yaw)<1e-9)s.stationary_same_yaw_key_changes++;
 }}
 if(r.home&&!prev.home)s.home_entries.push({us:r.us,key:r.key,reason:r.reason,trace_before:r.trace_before,trace_after:r.trace_after,preceding:s.recent.slice(-12)});
 }
 if(r.key)for(const [name,key]of [['physical_bins',r.position.map(x=>Math.floor(x*2)).join(',')],['view_bins',r.position.map(x=>Math.floor(x*2)).join(',')+','+Math.floor(r.yaw/15)]]){
 let bin=s[name].get(key);if(!bin)s[name].set(key,bin={count:0,keys:new Set(),first:r.us,last:r.us});
 bin.count++;bin.keys.add(r.key);bin.last=r.us;
 }
 s.recent.push({us:r.us,key:r.key,reason:r.reason,reset:r.reset,trace:r.trace_after,action:r.receipt?.action,goal:r.receipt?.goal});if(s.recent.length>12)s.recent.shift();s.prev=r;
}
for(const s of Object.values(actors)){
 for(const name of ['physical_bins','view_bins']){
 const bins=[...s[name].values()].filter(b=>b.last-b.first>=60000000);
 s[name]={revisited_bins:bins.length,multiple_keys:bins.filter(b=>b.keys.size>1).length,max_keys:Math.max(0,...bins.map(b=>b.keys.size))};
 }s.key_spatial={keys:s.key_spatial.size,spread_over_5m:[...s.key_spatial.values()].filter(k=>k.max_distance>5).length,max_distance:Math.max(0,...[...s.key_spatial.values()].map(k=>k.max_distance)),home_keys_also_away:[...s.key_spatial.values()].filter(k=>k.home&&k.away).length};delete s.prev;delete s.recent;
}
const goals=fs.readFileSync(path.join(run,'mb-goals.jsonl'),'utf8').trim().split('\n').filter(Boolean).map(x=>JSON.parse(x));
const goalSummary={};for(const r of goals){let s=goalSummary[r.actor]??={count:0,reasons:{},positive_H:[]};s.count++;s.reasons[r.reason]=(s.reasons[r.reason]||0)+1;if(r.H_before>r.H_after)s.positive_H.push(r);}
const snapshots=[];
for(const file of fs.readdirSync(path.join(run,'mb-snapshots')).sort()){
 const g=read(path.join(run,'mb-snapshots',file));
 const starts=g.kind==='sleep'?Object.keys(g.nodes).sort((a,b)=>g.nodes[b].seen-g.nodes[a].seen||cmp(a,b)).slice(0,8):[g.start];
 const results=[];
 for(const start of starts)for(const goal of g.kind==='sleep'?['home','food']:[g.kind.slice(5)]){
 const opts={allowed:g.allowed};const targets=Object.entries(g.nodes).filter(([k,n])=>n[goal]);
 const base={start,goal,targets:targets.length,fresh_targets:targets.filter(([k,n])=>g.now-n.seen<=DAY).length};
 const historical={...g,nodes:Object.fromEntries(Object.entries(g.nodes).map(([k,n])=>[k,{...n,home:n.home||((homeHistory[g.actor]?.[k]??Infinity)<=g.now)}]))};
 const prod=actual(g,start,goal,g.now,g.allowed);
 const fresh4=distance(g,start,goal,g.now,opts),old4=distance(g,start,goal,g.now,{...opts,fresh:false}),freshAny=distance(g,start,goal,g.now,{...opts,depth:Infinity}),all=distance(g,start,goal,g.now,{...opts,fresh:false,depth:Infinity});
 results.push({...base,historical_goal:distance(historical,start,goal,g.now,{fresh:false,depth:Infinity}),actual:prod,fresh_depth4_no_budget:fresh4,all_age_depth4:old4,fresh_any_depth:freshAny,all_age_any_depth:all,all_age_any_depth_no_first_gate:distance(g,start,goal,g.now,{fresh:false,depth:Infinity}),including_run:distance(g,start,goal,g.now,{fresh:false,depth:Infinity,run:true}),undirected:distance(g,start,goal,g.now,{fresh:false,depth:Infinity,run:true,undirected:true})});
 }
 snapshots.push({file,actor:g.actor,now:g.now,kind:g.kind,results});
}
const final10=read(path.join(process.argv[3]||'outputs/mb-sleep-10d-20261025','narrow/run/summary.json'));
const finalGraphs={};
for(const[a,g]of Object.entries(final10.mb_map)){
 const now=final10.ended_us;finalGraphs[a]={};
 for(const goal of ['home','food']){
 const starts=Object.keys(g.nodes).filter(k=>!g.nodes[k][goal]);const counts={starts:starts.length,targets:Object.values(g.nodes).filter(n=>n[goal]).length,fresh4:0,allAge4:0,freshAny:0,allAgeAny:0};
 for(const k of starts){
 if(distance(g,k,goal,now)!==null)counts.fresh4++;
 if(distance(g,k,goal,now,{fresh:false})!==null)counts.allAge4++;
 if(distance(g,k,goal,now,{depth:Infinity})!==null)counts.freshAny++;
 if(distance(g,k,goal,now,{fresh:false,depth:Infinity})!==null)counts.allAgeAny++;
 }finalGraphs[a][goal]=counts;
 }
}
const aggregate={};for(const s of snapshots)for(const r of s.results){
 const k=s.kind==='sleep'?'sleep':'wake';const t=aggregate[k]??={requests:0,no_targets:0,no_fresh_targets:0};
 t.requests++;if(!r.targets)t.no_targets++;if(!r.fresh_targets)t.no_fresh_targets++;
 for(const key of ['actual','fresh_depth4_no_budget','all_age_depth4','fresh_any_depth','all_age_any_depth','all_age_any_depth_no_first_gate','including_run','undirected','historical_goal'])t[key]=(t[key]||0)+(r[key]!==null?1:0);
}
const result={actors,goalSummary,aggregate,snapshots,final10:finalGraphs};
fs.writeFileSync(path.join(run,'diagnosis.json'),JSON.stringify(result,null,2));
console.log(JSON.stringify({actors:Object.fromEntries(Object.entries(actors).map(([a,s])=>[a,{...s,home_entries:s.home_entries.map(({preceding,...r})=>r)}])),goalSummary,aggregate,final10:finalGraphs},null,2));
}
module.exports={distance,actual};
if(require.main===module)main().catch(e=>{console.error(e);process.exitCode=1});
