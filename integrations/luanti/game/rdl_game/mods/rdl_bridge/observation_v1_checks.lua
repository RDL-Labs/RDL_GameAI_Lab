-- Synthetic boundary checks, distinct from the real World acquisition evidence.
return function(arbiter,control,profiles)
    local n=0
    local function check(ok) n=n+1;assert(ok,"OBS9 boundary check " .. n) end
    for k,v in pairs(profiles.npc_a.vision_distant) do check(profiles.npc_b.vision_distant[k]==v) end
    check(profiles.npc_a.audition.gain==1 and profiles.npc_b.audition.gain==0.25)
    local settings={get=function(_,key) return key=="rdl_sensor_profile_a" and "fixture-life-sensory" or "fixture-life-sensory-compact" end}
    local independent=dofile(core.get_modpath("rdl_bridge") .. "/sensor_profiles.lua").load(settings,{"a","b"})
    independent.a.audition.gain=0;check(independent.b.audition.gain==0.25)
    local function frame(id,profile) return {frame_id=id,agent_id="a",sensor_id="eye",channel="vision_distant",profile_id=profile or "fixture-life-sensory",profile_revision=1,
        sensor_model_revision="sampled-surface-v0.2",clock_id="world-sim-v1",status="SAMPLED",coverage="COMPLETE_WITHIN_PLAN",output_limited=false,
        capture_window={kind="instant",start_us=50001,end_us=50001},sampled_world_tick=0,observer_frame_ref="source",
        payload={features={{feature_id="f0",azimuth_interval_deg={30,35},elevation_interval_deg={-5,0},color_band="muted_red"}}}} end
    local req={run_id="r",world_epoch=1,agent_id="a",operation_id="op",purpose="visual_reacquisition_after_yaw",rule_version="obs9-v1",source_frame_id="f",feature_id="f0",color_band="muted_red"}
    local b={now_us=250001,life_busy=false,mapping_valid=true,mapping_expires_us=2050001,translation=0,tilt_deg=0,profile_id="fixture-life-sensory",profile_revision=1,
             source_pose="source",pose_ref="start",source_to_start_deg=0,clock_id="world-sim-v1",measured_right_deg=32.5}
    local function fresh()
        local c=control.new("r",1,"a","obs9-v1");local a=arbiter.new("r",1,"a",c,64)
        a.idle=true;a.admitted.f=frame("f");return a,c
    end
    for _,profile in ipairs({"fixture-life-sensory","fixture-life-sensory-compact"}) do
        local f=frame("f",profile);local body=table.copy(b);body.profile_id=profile
        local c=control.new("r",1,"a","obs9-v1");local e=c.start(req,f,body)
        check(e.operation_status=="validated" and e.plan.command_deg==32.5)
        local old=control.new("r",1,"a");local old_req=table.copy(req);old_req.rule_version="obs8b-v1"
        check(old.start(old_req,f,body).operation_status=="not_executed")
        local old_frame=frame("f","fixture-distant-enabled");body.profile_id="fixture-distant-enabled"
        local old_ok=control.new("r",1,"a").start(old_req,old_frame,body)
        check(old_ok.plan.command_deg==e.plan.command_deg)
        body.profile_id=profile=="fixture-life-sensory" and "fixture-life-sensory-compact" or "fixture-life-sensory"
        check(not c.guard(e,body) and e.reasons[1]=="profile_changed")
    end
    local a,c=fresh()
    for i=1,63 do check(a.enqueue(frame("p" .. i))) end
    local e=a.start(req,frame("f"),b);check(a.reserved==1)
    check(not a.enqueue(frame("overflow")) and #a.pending==63)
    check(c.rotate(e,b,function() end,function() return 32.5 end))
    local later=table.copy(b);later.now_us=1000123
    check(c.sample(e,4,later,function() return frame("target") end)~=nil)
    check(a.enqueue(e.frame,true) and #a.pending==64 and a.reserved==0)
    check(not a.enqueue(frame("overflow2")))
    local before=table.copy(a.pending);local t=a.begin("lost",1100000,false)
    a.lose_response("lost");a.submit("lost",nil,1150000,1150000);a.consume(1150000)
    check(#a.pending==64 and a.pending[1].frame_id==before[1].frame_id)
    local retry=a.begin("retry",1200000,false)
    for i,f in ipairs(t.frames) do check(retry.frames[i].frame_id==f.frame_id) end
    local receipt={agent_id="a",inspection={observation_id="retry"},sensory_receipt={accepted=true,delivery_observation_id="retry",new_frames=0}}
    a.submit("retry",receipt,1250000,1250000);a.consume(1250000)
    check(#a.pending==60 and a.retry_ids==nil)
    for i,f in ipairs(a.pending) do check(f.frame_id==before[i+4].frame_id) end
    a.submit("retry",receipt,1300000,1300000);a.consume(1300000);check(#a.pending==60)
    a,c=fresh();e=a.start(req,frame("f"),b);a.life_intent(500000)
    check(a.reserved==0 and e.operation_status=="aborted")
    local sampler=dofile(core.get_modpath("rdl_bridge") .. "/observation_v1_sampler.lua").new("gap",profiles,nil,nil,nil,{})
    local closed={};sampler.close(750000,function(_,f) closed[#closed+1]=f end,0)
    check(#closed==6)
    for _,f in ipairs(closed) do check(f.coverage=="PARTIAL" and #f.payload.detections==0) end
    sampler.close(750000,function() error("double close") end,750000)
    check(#sampler.frames==6)
    return n
end
