const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const [run,baseline,dest]=process.argv.slice(2);
if(!dest) throw Error('usage: compare_general_cues.cjs RUN BASELINE DEST');
const read=p=>JSON.parse(fs.readFileSync(p,'utf8').replace(/^\uFEFF/,''));
const input=read(path.join(run,'narrow/input.json')),old=read(path.join(baseline,'narrow/input.json'));
assert.equal(input.config.general_landmarks,'on');
delete input.config.general_landmarks;delete old.config.general_landmarks;
assert.deepEqual(input,old);
const summary=read(path.join(run,'narrow/run/summary.json'));
const result=read(path.join(run,'narrow/run/result.json'));
const cues=summary.observed_cues;
for(const [a,c] of Object.entries(cues)) {
  assert.ok(c.records.length<=32);
  assert.equal(c.selected.reduce((s,v)=>s+v,0),Object.values(c.kinds).reduce((s,v)=>s+v,0));
  c.records.forEach(r=>{assert.ok(r.tier<=Math.min(2,Math.floor(r.H/2)));assert.equal(r.uncertain,r.tier>0)});
  assert.ok(c.selected[1]>0 && c.selected[2]>0);
  assert.ok(c.tower_observations>0);
}
const baselineResult=read(path.join(baseline,'narrow/run/result.json'));
const actions=r=>Object.fromEntries(Object.entries(r.counts).map(([a,c])=>[a,{scan:c.scan,total:Object.values(c).reduce((s,v)=>s+v,0)}]));
const evidence={input_equal_except_general_landmarks:true,baseline,run,observed_cues:cues,actions:{baseline:actions(baselineResult),enabled:actions(result)}};
fs.writeFileSync(dest,JSON.stringify(evidence,null,2));
console.log(JSON.stringify({...evidence,observed_cues:Object.fromEntries(Object.entries(cues).map(([a,c])=>[a,{...c,records:undefined}]))},null,2));
