const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const [run,dest]=process.argv.slice(2);if(!dest)throw Error('usage: audit_mb_map.cjs RUN DEST');
const read=p=>JSON.parse(fs.readFileSync(p,'utf8').replace(/^\uFEFF/,''));
const summary=read(path.join(run,'narrow/run/summary.json'));
const input=read(path.join(run,'narrow/input.json'));
assert.equal(input.config.mb_simulation,'on');
const actors=Object.fromEntries(Object.entries(summary.mb_map).map(([a,m])=>{
 const nodes=Object.values(m.nodes),edges=Object.values(m.edges);
 assert.ok(nodes.length<=1280 && edges.length<=5120 && m.records.length<=32);
 assert.equal(m.observations,summary.ended_us/1e6);
 assert.ok(m.expanded<=64*m.searches);
 for(const e of edges){assert.ok(m.nodes[e.from] && m.nodes[e.to]);assert.ok(e.samples>0 && e.energy_sum>=0 && Number.isFinite(e.energy_sum));}
 for(const r of m.records){assert.ok(r.expanded<=64 && r.path.length<=4);}
 return [a,{nodes:nodes.length,edges:edges.length,home_nodes:nodes.filter(n=>n.home).length,food_nodes:nodes.filter(n=>n.food).length,
  observations:m.observations,searches:m.searches,expanded:m.expanded,mean_expanded:m.searches?m.expanded/m.searches:0,
  proposals:m.proposals,selected:m.selected,prediction_match:m.prediction_match,prediction_miss:m.prediction_miss,prediction_unknown:m.prediction_unknown,
  evictions:m.evictions,search_records:m.records}];
}));
const out={days:summary.ended_us/input.clock.day_us,measurement:summary.measurement,limits:{nodes:1280,edges:5120,depth:4,expansions:64},actors};
fs.writeFileSync(dest,JSON.stringify(out,null,2));
console.log(JSON.stringify({...out,actors:Object.fromEntries(Object.entries(actors).map(([a,m])=>[a,{...m,search_records:undefined}]))},null,2));
