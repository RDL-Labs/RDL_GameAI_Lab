const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const run=process.argv[2];if(!run)throw Error('usage: audit_home_observation.cjs RUN');
const read=p=>JSON.parse(fs.readFileSync(path.join(run,p),'utf8'));
const r=read('narrow/run/result.json'),summary=read('narrow/run/summary.json'),input=read('narrow/input.json');
const day=input.clock.day_us;
assert.equal(input.config.home_observation,'on');assert.equal(r.daily.length,4);
assert.deepEqual(summary.home_observation,r.home_observation);
const crossings=fs.readFileSync(path.join(run,'narrow/crossings.jsonl'),'utf8').trim().split('\n').filter(Boolean).map(x=>JSON.parse(x));
assert.equal(crossings.filter(e=>e.sec<=day/1e6).length,0);
const actors={};
for(const[a,s]of Object.entries(r.home_observation)){
 assert.equal(s.ticks,day/1e6);assert.equal(s.completed,true);
 const configured=r.events.filter(e=>e.actor===a&&e.method==='configured_observation');
 assert.ok(configured.length>0&&configured.every(e=>e.us<day));
 assert.ok(r.events.some(e=>e.actor===a&&e.us>=day&&e.action==='walk'));
 actors[a]={...s,keys:s.keys.length,configured_events:configured.length,
  day1_reserve:r.daily[0].physical[a].body.reserve,
  first_outward_seconds:crossings.find(e=>e.actor===a&&e.direction==='out')?.sec??null,
  final_nodes:Object.keys(r.mb_map[a].nodes).length,final_edges:Object.keys(r.mb_map[a].edges).length,
  sleep_reviews:r.mb_map[a].sleep.reviews.length,sleep_found:r.mb_map[a].sleep.reviews.reduce((n,x)=>n+x.found,0),
  sleep_proposals:r.mb_map[a].sleep.proposals,sleep_selected:r.mb_map[a].sleep.selected,
  wake_proposals:r.mb_map[a].proposals,selected:r.mb_map[a].selected,chunk_formations:r.mb_map[a].chunk_formations};
}
const out={first_day_no_gate_crossings:true,actors};
fs.writeFileSync(path.join(run,'observation-audit.json'),JSON.stringify(out,null,2));console.log(JSON.stringify(out,null,2));
