// Compare world-confirmed gift receipts with the receiver's attributed aid.
// Ordinary event logs record changes, so report their coverage explicitly.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const args=process.argv.slice(2),strict=args.includes('--require-complete');
const positional=args.filter(x=>x!=='--require-complete');
if(positional.length<1||positional.length>2||positional.some(x=>x.startsWith('--')))
 throw Error('usage: node audit.cjs RUN_DIR [OUTPUT.json] [--require-complete]');
const run=path.resolve(positional[0]);
const output=path.resolve(positional[1]||path.join(run,'social-relationship-audit.json'));
const r=JSON.parse(fs.readFileSync(path.join(run,'result.json'),'utf8'));
assert.ok(r.social_relationships&&r.final_agents&&Array.isArray(r.events),'relationship result required');
const outcomes=['given','refuse','no_response_observed','request_not_executed'];
const sum=x=>Object.values(x).reduce((s,v)=>s+v,0);
const bump=(x,k)=>x[k]=(x[k]||0)+1;
const pair=(giver,receiver)=>`${giver}->${receiver}`;
function startOf(record){
 const match=/^op:(\d+):/.exec(record.operation_id);
 assert.ok(match,`unrecognized request operation: ${record.operation_id}`);
 const start=Number(match[1]);assert.ok(Number.isSafeInteger(start));return start;
}
const records=Object.fromEntries(Object.entries(r.final_agents).map(([a,v])=>[a,Object.values(v.social.records)]));
const rows={};
function edge(giver,receiver){
 return rows[pair(giver,receiver)]??=(
  {giver,receiver,world_transfers:0,received_relation:0,received_records:0,logged_transfers:0});
}
const countDifferences=[],requestOutcomes={};
for(const [actor,state] of Object.entries(r.social_relationships)){
 for(const [other,p] of Object.entries(state.peers)){
  edge(actor,other).world_transfers+=p.aid_given.transferred;
  edge(other,actor).received_relation+=p.aid_received.given;
  for(const outcome of outcomes){
   const actual=records[actor].filter(e=>e.target===other&&e.outcome===outcome).length;
   if(actual!==p.aid_received[outcome])countDifferences.push({actor,other,outcome,record_count:actual,relation_count:p.aid_received[outcome]});
  }
 }
 for(const record of records[actor]){
  bump(requestOutcomes,record.outcome);
  if(record.outcome==='given')edge(record.target,actor).received_records++;
 }
}
const transfers=r.events.filter(e=>e.action==='give'&&e.status==='transferred');
const classifications={},overwrittenBy={},mismatches=[],ambiguous=[],recordMatches=new Map();
const communication=new Set(['eat','request','give','refuse','warn','withdraw','wait']);
for(const transfer of transfers){
 const giver=transfer.actor,receiver=transfer.target;
 edge(giver,receiver).logged_transfers++;
 const candidates=records[receiver].filter(e=>e.target===giver&&startOf(e)<=transfer.us&&
  transfer.us<e.deadline&&e.tick>transfer.us);
 if(candidates.length!==1){
  bump(classifications,candidates.length?'ambiguous_request_window':'no_matching_request_window');
  const entry={giver,receiver,transfer_us:transfer.us,request_ids:candidates.map(e=>e.message_id)};
  (candidates.length?ambiguous:mismatches).push(entry);continue;
 }
 const record=candidates[0];bump(classifications,record.outcome);
 const key=`${receiver}|${record.message_id}`;
 recordMatches.set(key,(recordMatches.get(key)||0)+1);
 if(record.outcome==='given')continue;
 const changed=r.events.filter(e=>e.actor===receiver&&e.us>startOf(record)&&e.us<record.tick&&communication.has(e.action));
 const latest=changed.at(-1);
 if(record.outcome==='request_not_executed')bump(overwrittenBy,latest?.action||'no_logged_overwrite');
 mismatches.push({giver,receiver,request_id:record.message_id,request_us:startOf(record),
  transfer_us:transfer.us,observed_us:record.tick,recorded_outcome:record.outcome,
  last_intervening_communication:latest?{us:latest.us,action:latest.action,status:latest.status}:null});
}
const duplicateMatches=[...recordMatches].filter(([,n])=>n>1).map(([record,count])=>({record,count}));
const unmatchedGiven=[];
for(const [receiver,rs] of Object.entries(records))for(const record of rs)
 if(record.outcome==='given'&&!recordMatches.has(`${receiver}|${record.message_id}`))
  unmatchedGiven.push({receiver,giver:record.target,request_id:record.message_id,observed_us:record.tick});
const edges=Object.values(rows).sort((a,b)=>pair(a.giver,a.receiver).localeCompare(pair(b.giver,b.receiver)));
const totals={world_transfers:sum(Object.fromEntries(edges.map((e,i)=>[i,e.world_transfers]))),
 received_relation:sum(Object.fromEntries(edges.map((e,i)=>[i,e.received_relation]))),
 received_records:sum(Object.fromEntries(edges.map((e,i)=>[i,e.received_records]))),logged_transfers:transfers.length};
const checks={
 relation_counts_match_records:countDifferences.length===0,
 all_transfer_events_logged:edges.every(e=>e.logged_transfers===e.world_transfers),
 every_transfer_attributed_given:edges.every(e=>e.world_transfers===e.received_records)&&mismatches.length===0&&ambiguous.length===0,
 no_duplicate_transfer_attribution:duplicateMatches.length===0,
 every_given_has_logged_transfer:unmatchedGiven.length===0,
};
const audit={rule:'directed-aid-receipt-audit-v1',run,totals,checks,edges,request_outcomes:requestOutcomes,
 transfer_record_classifications:classifications,intervening_receipt_actions:overwrittenBy,
 relation_count_differences:countDifferences,mismatches,ambiguous,duplicate_matches:duplicateMatches,
 unmatched_given:unmatchedGiven,
 scope:'world_transfers uses aid_given.transferred counters updated from execution receipts; event logs are change-compressed and their coverage is checked separately. A matching time window is not a stored reply_to identity.',
};
fs.mkdirSync(path.dirname(output),{recursive:true});fs.writeFileSync(output,JSON.stringify(audit,null,2));
console.log(JSON.stringify({output,totals,checks,transfer_record_classifications:classifications,
 intervening_receipt_actions:overwrittenBy,mismatch_count:mismatches.length,ambiguous_count:ambiguous.length},null,2));
if(strict)assert.ok(Object.values(checks).every(Boolean),'incomplete or inconsistent aid attribution; inspect audit JSON');
