const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const [run,dest]=process.argv.slice(2);if(!dest)throw Error('usage: audit_mb_parent.cjs RUN DEST');
const s=JSON.parse(fs.readFileSync(path.join(run,'narrow/run/summary.json'),'utf8'));
const result={measurement:s.measurement,actors:{}};
for(const [actor,m] of Object.entries(s.mb_map)){
 const p=m.parent_mb;assert.ok(Object.keys(p.models).length<=6);assert.ok(Object.keys(p.active).length<=2);assert.ok(p.records.length<=64);
 assert.ok(p.within_estimate<=p.evaluated && p.successes<=p.evaluated);
 assert.equal(Object.values(p.models).reduce((x,m)=>x+m.completed,0),p.successes);
 for(const model of Object.values(p.models)){assert.equal(model.samples,model.completed);assert.ok(model.actions_mean>=0&&model.energy_rate>=0);}
 for(const a of Object.values(p.active)){assert.ok(a.scenes.length<=64);assert.ok(a.estimate.upper_actions>=2&&a.estimate.upper_actions<=4096);assert.ok(a.actions>=0&&a.energy>=0);}
 for(const r of p.records){assert.ok(r.increment>=0&&Number.isInteger(r.increment));if(r.resolved)assert.equal(r.increment,0);}
 result.actors[actor]=p;
}
fs.writeFileSync(dest,JSON.stringify(result,null,2));
console.log(JSON.stringify({measurement:result.measurement,actors:Object.fromEntries(Object.entries(result.actors).map(([a,p])=>[a,{evaluated:p.evaluated,within_estimate:p.within_estimate,H_requested:p.H_requested,successes:p.successes,models:p.models,active:Object.fromEntries(Object.entries(p.active).map(([g,e])=>[g,{actions:e.actions,estimate:e.estimate,charged:e.charged}]))}]))},null,2));
