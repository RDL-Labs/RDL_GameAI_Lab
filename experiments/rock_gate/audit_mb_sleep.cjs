const fs=require('fs'),assert=require('assert/strict'),u=require('util');
const [run,baseline]=process.argv.slice(2);if(!baseline)throw Error('usage: audit_mb_sleep.cjs RUN BASELINE');const p=run+'/',b=baseline+'/';
const read=f=>JSON.parse(fs.readFileSync(f));
const s=read(p+'narrow/run/summary.json'),base=read(b+'narrow/run/summary.json');
const x=read(p+'narrow/input.json'),y=read(b+'narrow/input.json');
delete x.config.mb_sleep;delete y.config.mb_sleep;
assert.ok(u.isDeepStrictEqual(x,y));assert.equal(s.sleep_action_models,null);
const actors={};
for(const [a,m] of Object.entries(s.mb_map)){
 const q=m.sleep;
 assert.ok(q.reviews.length>0);
 assert.equal(q.reviews.length,s.general_sleep[a].reviews.length);
 for(const h of Object.values(q.hypotheses)){
  for(let i=1;i<h.edges.length;i++)assert.equal(m.edges[h.edges[i-1]].to,m.edges[h.edges[i]].from);
 }
 actors[a]={reviews:q.reviews.length,searches:q.reviews.reduce((n,r)=>n+r.searches,0),expanded:q.reviews.reduce((n,r)=>n+r.expanded,0),found:q.reviews.reduce((n,r)=>n+r.found,0),hypotheses:Object.keys(q.hypotheses).length,proposals:q.proposals,selected:q.selected,chunk_formations:m.chunk_formations,chunk_reward:m.chunk_reward};
}
const r=read(p+'narrow/run/result.json'),z=read(b+'narrow/run/result.json');
const comparison={input_equal_except_mb_sleep:true,old_sleep_priority_disabled:true,actors,behavior_equal:Object.fromEntries(['daily','day_starts','events'].map(k=>[k,u.isDeepStrictEqual(r[k],z[k])])),seconds:s.measurement.call_seconds,baseline_seconds:base.measurement.call_seconds};
fs.writeFileSync(p+'sleep-audit.json',JSON.stringify(comparison,null,2));console.log(JSON.stringify(comparison,null,2));
