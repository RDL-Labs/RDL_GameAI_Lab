const fs=require('fs'),assert=require('assert');
const root='outputs/enclosed-confirm-departure-diagnostic-20261027/';
const rows=fs.readFileSync(root+'gate-decisions.jsonl','utf8').trim().split('\n').filter(Boolean).map(JSON.parse);
const out={actors:{}};
for(const [actor,start] of [['npc_a',46440],['npc_b',39240],['npc_c',37380]]){
 const candidates=rows.filter(x=>x.actor===actor&&x.stage==='candidates'&&x.sec>=start&&x.sec<start+120);
 const selected=rows.filter(x=>x.actor===actor&&x.stage==='selected'&&x.sec>=start&&x.sec<start+120);
 const rh={},reasons={};for(const x of candidates){rh[x.rho.rho]=(rh[x.rho.rho]||0)+1;reasons[x.distance.reason]=(reasons[x.distance.reason]||0)+1;assert(Math.abs(x.candidates.reduce((s,c)=>s+c.probability,0)-1)<1e-8);}
 const details=candidates.slice(0,16).map(x=>{const sel=selected.find(s=>s.sec===x.sec);const sorted=[...x.candidates].sort((a,b)=>b.probability-a.probability);return {sec:x.sec,position:x.position,yaw:x.yaw,rho:x.rho.rho,reason:x.distance.reason,uncertainty:x.distance.uncertainty,parentH:x.parent_H,home:x.home,count:x.candidates.length,selected:sel?.plan,chosenRank:sorted.findIndex(c=>c.method===sel?.plan.method)+1,top:sorted.slice(0,3)};});
 out.actors[actor]={candidateFrames:candidates.length,selectedFrames:selected.length,rhoCounts:rh,reasons,details};
}
if(fs.existsSync(root+'ordinary/positions.json')){
 const original=JSON.parse(fs.readFileSync('outputs/enclosed-narrow-bonfire-confirm-3d-20261027/ordinary/positions.json'));
 const replay=JSON.parse(fs.readFileSync(root+'ordinary/positions.json'));assert.deepStrictEqual(replay,original.slice(0,replay.length));out.matchingPositionSamples=replay.length;
}
fs.writeFileSync('experiments/rock_gate/confirm_departure_diagnostics_summary.json',JSON.stringify(out,null,2));
for(const [a,v] of Object.entries(out.actors))console.log(a,JSON.stringify({frames:v.candidateFrames,rho:v.rhoCounts,reasons:v.reasons,details:v.details.map(d=>({sec:d.sec,rho:d.rho,H:d.parentH,home:d.home,count:d.count,selected:d.selected?.method,p:d.selected?.selection_probability,rank:d.chosenRank,yaw:d.yaw,angle:d.selected?.approach_angle,top:d.top.map(t=>({method:t.method,p:t.probability,priority:t.priority,reward:t.learned_reward,H:t.method_H,repulsion:t.failure_repulsion_value}))}))}));
console.log('matchingPositions',out.matchingPositionSamples);
