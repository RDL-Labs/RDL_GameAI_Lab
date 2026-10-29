// Audit retained owner evidence and cumulative transfer conservation separately.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const [dir,destination]=process.argv.slice(2);
if(!dir||!destination)throw Error('usage: node unified_audit.cjs EXPERIMENT_DIR OUTPUT.json');
const load=name=>JSON.parse(fs.readFileSync(path.join(dir,name),'utf8'));
const r=load('run/result.json'),summary=load('run/summary.json'),resumed=load('resumed/result.json');
assert.deepEqual(r,resumed,'full result must equal continuation');
const sum=xs=>xs.reduce((a,b)=>a+b,0),values=Object.values;
const actors={},edges=[];let checked=0;
function check(condition,message){checked++;assert.ok(condition,message);}
for(const [actor,s] of Object.entries(r.social_relationships)){
 const aid=s.aid,old=r.final_agents[actor].social,m=s.mb;
 check(aid.resolved===sum(values(aid.outcome_counts).map(v=>sum(values(v)))),`${actor} cumulative aid`);
 check(values(old.records).length+old.records_pruned===aid.resolved,`${actor} retained versus pruned`);
 check(values(old.records).length<=128&&aid.records.length<=32,`${actor} bounded logs`);
 check(values(old.model).length===0,`${actor} legacy model disabled`);
 for(const [other,p] of Object.entries(s.peers)){
  for(const [outcome,n] of Object.entries(p.aid_received))
   check(n===(aid.outcome_counts[other]?.[outcome]||0),`${actor}->${other} ${outcome}`);
  const sent=r.social_relationships[other].peers[actor]?.aid_given.transferred||0;
  check(sent===p.aid_received.given,`${other}->${actor} world-confirmed transfers`);
  edges.push({owner:actor,other,aid:p.aid_received,aid_given:p.aid_given,trade_offer:p.trade_offer,
   trade_response:p.trade_response,trade_value_sum:p.trade_value_sum});
 }
 for(const e of aid.records){
  if(e.outcome==='given')check(e.actual===e.forecast.values[e.received_kind-1],`${actor} frozen personal value`);
  if(e.evaluated)check(Math.abs(e.H_after-Math.min(32,Math.max(0,e.H_before-e.reward)+e.pressure))<1e-10,`${actor} continuous H`);
  else check(e.H_after===e.H_before,`${actor} deferred H`);
 }
 const nodes=[...values(m.nodes),...values(m.pending),...values(m.frozen?.candidates||{})];
 check(values(m.nodes).length<=96&&values(m.pending).length<=128,`${actor} bounded MB`);
 if(!m.admission_blocked&&!m.evicted&&!m.provisional_evicted)
  check(sum(nodes.map(n=>n.samples))===m.events-m.unknown,`${actor} retained evidence mass`);
 check(nodes.every(n=>n.samples===n.source_count),`${actor} MB source count`);
 check(m.reviews.length>0,`${actor} real Sleep reviews`);
 actors[actor]={reserve:r.final_agents[actor].body.reserve,position:r.final_agents[actor].position,
  inventory:r.final_agents[actor].inventory,personal_stock:r.final_agents[actor].personal_stock,
  aid:{forecasts:aid.forecasts,resolved:aid.resolved,deferred:aid.deferred,H:aid.parent.H,outcomes:aid.outcome_counts,
   pruned:old.records_pruned,retained:values(old.records).length},
  relation_mb:{events:m.events,unknown:m.unknown,adopted:values(m.nodes).length,pending:values(m.pending).length,
   evidence_samples:sum(nodes.map(n=>n.samples)),merged:m.merged,admission_blocked:m.admission_blocked,
   evicted:m.evicted,provisional_evicted:m.provisional_evicted,metric:m.metric.weights,metric_updates:m.metric.updates,reviews:m.reviews},
  approach:{proposed:s.approach.proposed,selected:s.approach.selected,contacts:s.approach.contacts}};
}
const daily=r.daily.map((d,i)=>{
 check(r.initial_food+d.replenished_food===d.ground+d.shared_stock+d.consumed+
  sum(values(d.physical).map(a=>a.inventory+a.personal_stock)),`day ${i+1} conservation`);
 const previous=i?r.daily[i-1].food_exchange.world.counts:{};
 return {day:i+1,trade:Object.fromEntries(Object.entries(d.food_exchange.world.counts).map(([k,v])=>[k,v-(previous[k]||0)])),
  actors:Object.fromEntries(Object.entries(d.social_relationships).map(([a,s])=>[a,{aid_resolved:s.aid.resolved,
   aid_H:s.aid.parent.H,relation_nodes:values(s.mb.nodes).length,sleep_reviews:s.mb.reviews.length,
   approach_selected:s.approach.selected,approach_contacts:s.approach.contacts}]))};
});
const out={rule:'unified-social-owner-evidence-v1',input_sha256:load('origin.json').sha256,
 checks_passed:checked,continuation_identical:true,measurement:summary.measurement,
 resumed_measurement:load('resumed/summary.json').measurement,config:summary.config,
 food:summary.food,food_resources:{consumed:r.food_resources.consumed,processed_inputs:r.food_resources.processed_inputs,
  personal:r.food_resources.personal},wildlife:{alive:r.wildlife.alive,starvation_deaths:r.wildlife.starvation_deaths},
 trade:r.food_exchange.world.counts,actors,edges,daily,
 scope:'Cumulative directed aid counts match world-confirmed giver receipts. Value/H assertions inspect retained records only; pruned detail is not reconstructed. MB predictions use owner experience, not ground-truth intent.'};
fs.mkdirSync(path.dirname(destination),{recursive:true});fs.writeFileSync(destination,JSON.stringify(out,null,2));
console.log(JSON.stringify({checks_passed:checked,continuation_identical:true,trade:out.trade,actors},null,2));
