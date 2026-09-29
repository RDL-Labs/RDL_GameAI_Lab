/* Pure read-only indexing. No Runtime access and no simulation updates. */
(function(root){
  function parse(text){
    const lines=text.split(/\r?\n/),rows=[];let truncated=false;
    for(let i=0;i<lines.length;i++){
      if(!lines[i].trim())continue;
      try{rows.push(JSON.parse(lines[i]));}catch(e){
        if(lines.slice(i+1).some(s=>s.trim()))throw Error('途中のJSON行が壊れています');
        truncated=true;
      }
    }
    const manifest=rows[0];
    if(manifest?.type!=='manifest'||manifest.version!=='lw-planar-world-v1')throw Error('未対応のログ形式');
    const groups=[];let group;
    for(const r of rows.filter(r=>r.type==='step')){
      if(!manifest.agents[r.packet.agent_id]||r.result.operation_id!==r.command.operation_id)throw Error('個体・操作参照が不正です');
      const t=r.packet.capture_us;
      if(!Number.isFinite(t)||t<0||(group&&t<group.time))throw Error('時刻順序が不正です');
      if(!group||group.time!==t){group={time:t,steps:{}};groups.push(group);}
      if(group.steps[r.packet.agent_id])throw Error('同一取得枠の重複です');
      group.steps[r.packet.agent_id]=r;
    }
    // Only expose complete population slots. Partial tail remains incomplete.
    const ids=Object.keys(manifest.agents);
    const partial=groups.some(g=>ids.some(id=>!g.steps[id]));
    if(groups.slice(0,-1).some(g=>ids.some(id=>!g.steps[id])))throw Error('途中の個体記録が欠落しています');
    if(partial)groups.pop();
    if(!groups.length)throw Error('完全な観測枠がありません');
    const summary=rows.find(r=>r.type==='summary');
    return {manifest,groups,summary,complete:!!summary&&!truncated&&!partial};
  }
  function agentView(data,index,id){
    const r=data.groups[index].steps[id];
    // Explicit allowlist: never supply manifest objects, body or stock to this view.
    return {packet:r.packet,command:r.command,result:r.result,model_ref:r.model_ref,learning_count:r.learning_count};
  }
  function worldView(data,index){
    const bodies=JSON.parse(JSON.stringify(data.manifest.agents)),trails={};
    for(const id of Object.keys(bodies))trails[id]=[{x:bodies[id].x,z:bodies[id].z}];
    const counts={},patches=data.manifest.resources.map(r=>({...r}));
    for(let i=0;i<=index;i++)for(const [id,r] of Object.entries(data.groups[i].steps)){
      bodies[id]=r.body;trails[id].push({x:r.body.x,z:r.body.z});
      if(r.result.acquired){
        counts[id]=(counts[id]||0)+1;
        // Match the observed body-relative target to experimenter geometry, not handle parsing.
        const item=r.packet.food.visible.find(v=>v.ref===r.command.target_ref);
        if(item){const a=r.body.yaw*Math.PI/180;const x=r.body.x+item.forward*Math.sin(a)+item.right*Math.cos(a),z=r.body.z+item.forward*Math.cos(a)-item.right*Math.sin(a);
          const candidates=patches.filter(p=>Math.hypot(p.x-x,p.z-z)<1e-5);if(candidates.length===1)candidates[0].stock--;}
      }
    }
    return {bodies,trails,patches,counts,objects:data.manifest.objects};
  }
  const api={parse,agentView,worldView};if(typeof module!=='undefined')module.exports=api;root.LWReplay=api;
})(globalThis);
