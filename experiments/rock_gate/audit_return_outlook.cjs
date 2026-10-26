const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const [run,dest]=process.argv.slice(2);
if(!dest)throw Error('usage: audit_return_outlook.cjs RUN DEST');
const s=JSON.parse(fs.readFileSync(path.join(run,'narrow/run/summary.json'),'utf8'));
const report=JSON.parse(fs.readFileSync(path.join(run,'narrow/report.json'),'utf8'));
const result={measurement:s.measurement,actors:{}};
for(const [a,m] of Object.entries(s.mb_map)){
 const r=m.return_outlook;assert.ok(r && r.evaluated>0);
 assert.ok(Object.keys(r.paths).length<=256 && r.records.length<=64);
 assert.ok(r.selected<=r.evaluated && r.builds<=r.evaluated);
 for(const p of Object.values(r.paths)){
  assert.ok(p.path.length<=32 && p.energy>=0 && Number.isFinite(p.energy));
  // Cached paths may have been pruned since the last rebuild; lookup rejects these.
 }
 for(const x of r.records)assert.ok(x.known>=0 && x.unknown>=0 && Number.isFinite(x.reserve));
 result.actors[a]={reserve:report.actors[a].reserve,out:report.actors[a].outward,in:report.actors[a].inward,
  evaluated:r.evaluated,builds:r.builds,knownCandidates:r.known,unknownCandidates:r.unknown,
  returnLinkSelected:r.selected,cachedNodes:Object.keys(r.paths).length,
  routeStarted:m.routes.started,outcomes:m.routes.outcomes,chunks:m.chunk_formations,
  parentSuccesses:m.parent_mb.successes,records:r.records};
}
fs.writeFileSync(dest,JSON.stringify(result,null,2)+'\n');
console.log(JSON.stringify({...result,actors:Object.fromEntries(Object.entries(result.actors).map(([a,r])=>[a,{...r,records:undefined}]))},null,2));
