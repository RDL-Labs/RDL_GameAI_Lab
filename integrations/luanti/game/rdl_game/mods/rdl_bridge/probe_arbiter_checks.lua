return function(arbiter, control)
    local n=0
    local function check(x) assert(x,"OBS8B arbiter check " .. n);n=n+1 end
    local function fresh() local c=control.new("r",1,"a");return arbiter.new("r",1,"a",c),c end
    local function frame(id) return {frame_id=id,agent_id="a",sensor_id="eye",channel="vision_distant",profile_id="fixture-distant-enabled",profile_revision=1,
        sensor_model_revision="sampled-surface-v0.2",clock_id="world-sim-v1",status="SAMPLED",coverage="COMPLETE_WITHIN_PLAN",output_limited=false,
        capture_window={kind="instant",start_us=50001,end_us=50001},sampled_world_tick=0,observer_frame_ref="source",
        payload={features={{feature_id="f0",azimuth_interval_deg={30,35},elevation_interval_deg={-5,0},color_band="muted_red"}}}} end
    local f=frame("f")
    local req={run_id="r",world_epoch=1,agent_id="a",operation_id="op",purpose="visual_reacquisition_after_yaw",rule_version="obs8b-v1",source_frame_id="f",feature_id="f0",color_band="muted_red"}
    local b={now_us=250001,life_busy=false,mapping_valid=true,mapping_expires_us=2050001,translation=0,tilt_deg=0,profile_id="fixture-distant-enabled",profile_revision=1,
             source_pose="source",pose_ref="start",source_to_start_deg=0,clock_id="world-sim-v1",measured_right_deg=32.5}
    local function receipt(id,new) return {agent_id="a",inspection={observation_id=id},sensory_receipt={accepted=true,delivery_observation_id=id,new_frames=new}} end
    local a,c=fresh();a.life_intent(0);a.enqueue(f);a.begin("old",50001,true);a.submit("old",receipt("old",1),70000,1200000)
    check(a.consume(1000000)==nil);check(#a.pending==1)
    a.enqueue(frame("new"));a.invalidate("new_life_generation",900000)
    local result=a.consume(1200000);check(not a.authorized(result));check(#a.pending==1 and a.pending[1].frame_id=="new")
    check(a.admitted.f~=nil);a.begin("new-delivery",1250000,true)
    a.submit("old",receipt("old",0),1300000,1300000);result=a.consume(1300000)
    check(a.in_flight=="new-delivery");check(#a.pending==1);check(not a.authorized(result))
    local wrong_receipt=receipt("new-delivery",1);wrong_receipt.sensory_receipt.delivery_observation_id="wrong-id"
    a.submit("new-delivery",wrong_receipt,1350000,1350000);result=a.consume(1350000)
    check(#a.pending==1);check(a.authorized(result));check(not a.authorized(result))
    a.begin("last",1400000,true);a.submit("last",receipt("last",1),1450000,1450000);a.stop(1440000)
    result=a.consume(1450000);check(not a.authorized(result));check(#a.pending==0)
    a,c=fresh();a.admitted.f=f
    local refused=a.start(req,f,b);check(refused.operation_status=="not_executed") -- explicit idle required
    for i=1,8 do a.enqueue(frame("p" .. i)) end
    check(a.start(req,f,b).reasons[1]=="life_busy") -- replay cannot rewrite a terminal reason
    a,c=fresh();a.idle=true;a.admitted.f=f;a.result_waiting=true
    check(a.start(req,f,b).operation_status=="not_executed")
    a,c=fresh();a.idle=true;a.admitted.f=f;a.begin("pending",0,true)
    check(a.start(req,f,b).operation_status=="not_executed")
    a,c=fresh();a.idle=true;a.admitted.f=f
    for i=1,8 do check(a.enqueue(frame("p" .. i))) end
    check(not a.enqueue(frame("overflow")))
    check(a.start(req,f,b).reasons[1]=="pending_capacity")
    a,c=fresh();a.idle=true;a.admitted.f=f
    for i=1,7 do a.enqueue(frame("p" .. i)) end
    local e,fresh_entry=a.start(req,f,b);check(fresh_entry and a.reserved==1)
    check(not a.enqueue(frame("ordinary")))
    check(c.rotate(e,b,function() end,function() return 32.5 end))
    local later=table.copy(b);later.now_us=1000123
    check(c.sample(e,4,later,function() return frame("target") end)~=nil)
    check(a.enqueue(e.frame,true));check(#a.pending==8 and a.reserved==0)
    local replay,is_new=a.start(req,f,later);check(replay==e and not is_new and e.samples==1)
    a,c=fresh();a.idle=true;a.admitted.f=f;e=a.start(req,f,b)
    c.rotate(e,b,function() end,function() return 32.5 end)
    a.life_intent(1000123);check(e.operation_status=="aborted" and e.samples==0);check(a.reserved==0)
    check(a.slot(4));check(not a.slot(4));check(not a.slot(5));check(a.slot(8))
    a,c=fresh();a.idle=true;a.admitted.f=f;e=a.start(req,f,b)
    c.rotate(e,b,function() end,function() return nil end);a.reconcile();check(a.reserved==0 and a.active==nil)
    a,c=fresh();a.idle=true;a.admitted.f=f;e=a.start(req,f,b)
    c.rotate(e,b,function() end,function() return 32.5 end)
    later.now_us=1750123;check(c.sample(e,7,later,function() error("fabricated catch-up") end)==nil and e.operation_status=="aborted")
    a,c=fresh();a.admitted.f=f
    for i=1,16 do local r=table.copy(req);r.operation_id="op" .. i;a.start(r,f,b) end
    check(not pcall(a.start,req,f,b))
    a,c=fresh();a.admitted.f=f;a.start(req,f,b)
    local changed=table.copy(req);changed.rule_version="wrong";check(not pcall(a.start,changed,f,b))
    changed=table.copy(req);changed.run_id="old";check(not pcall(a.start,changed,f,b))
    a,c=fresh();a.idle=true;check(not pcall(a.start,req,f,b))
    a.admitted.f=f;local stale=table.copy(b);stale.now_us=2050002;check(a.start(req,f,stale).operation_status=="not_executed")
    a,c=fresh();a.idle=true;a.admitted.f=f
    e=a.start(req,f,b);c.rotate(e,b,function() end,function() return 32.5 end)
    a.stop(6000000);check(e.operation_status=="aborted" and a.reserved==0)
    a.begin("drain",6000001,false);a.submit("drain",receipt("drain",0),6000002,6000002);check(not a.authorized(a.consume(6000002)))
    a,c=fresh();a.life_intent(0);a.enqueue(f);a.begin("id",1,true)
    a.submit("id",receipt("other",1),2,2);result=a.consume(2)
    check(not a.authorized(result) and #a.pending==1)
    return n
end
