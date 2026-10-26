const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const [run,dest]=process.argv.slice(2);if(!dest)throw Error('usage: audit_mb_routes.cjs RUN DEST');
const s=JSON.parse(fs.readFileSync(path.join(run,'narrow/run/summary.json'),'utf8'));
const result={measurement:s.measurement,actors:{}};
for(const [actor,m] of Object.entries(s.mb_map)){
 const r=m.routes;assert.ok(r.events.length<=64);assert.ok(Object.keys(r.stats).length<=256);
 if(r.decisions){assert.ok(r.decisions.length<=64);for(const d of r.decisions){const ps=Object.values(d.mass);assert.ok(ps.every(p=>p>=0 && p<=1));assert.ok(Math.abs(ps.reduce((a,b)=>a+b,0)-1)<1e-8);}}
 if(r.forecast){assert.ok(r.forecast.records.length<=64);assert.ok(r.forecast.within_estimate<=r.forecast.evaluated);for(const e of r.forecast.records){assert.ok(Number.isInteger(e.increment)&&e.increment>=0);assert.ok(e.lag>=0&&e.energy_excess>=0&&e.contradictions>=0);}}
 const ended=Object.values(r.outcomes).reduce((a,b)=>a+b,0);
 assert.equal(r.started,ended+(r.active===null?0:1));
 for(const e of r.events){assert.ok(e.steps<=e.length && e.verified_steps<=e.steps);assert.ok(e.ended_us>=e.started_us);if(e.outcome!=='success')assert.equal(e.reward,0);}
 result.actors[actor]={started:r.started,outcomes:r.outcomes,active:r.active,forecast:r.forecast,uncertainty:r.uncertainty,controls:r.controls,decisions:r.decisions,stats:r.stats,events:r.events};
}
fs.writeFileSync(dest,JSON.stringify(result,null,2));
console.log(JSON.stringify({measurement:result.measurement,actors:Object.fromEntries(Object.entries(result.actors).map(([a,r])=>[a,{started:r.started,outcomes:r.outcomes,active:r.active,uncertainty:r.uncertainty,controls:r.controls,stats_count:Object.keys(r.stats).length}]))},null,2));
