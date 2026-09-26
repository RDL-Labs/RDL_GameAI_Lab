-- Pure controller boundaries executed inside Luanti's Lua runtime.
return function(probe)
    local count = 0
    local frame={frame_id="f",agent_id="npc_a",sensor_id="eye",channel="vision_distant",profile_id="fixture-distant-enabled",profile_revision=1,
        sensor_model_revision="sampled-surface-v0.2",clock_id="world-sim-v1",status="SAMPLED",coverage="COMPLETE_WITHIN_PLAN",output_limited=false,
        capture_window={kind="instant",start_us=0,end_us=0},observer_frame_ref="source",
        payload={features={{feature_id="f0",azimuth_interval_deg={30,35},elevation_interval_deg={-5,0},color_band="muted_red"}}}}
    local req={run_id="r",world_epoch=1,agent_id="npc_a",operation_id="op",purpose="visual_reacquisition_after_yaw",rule_version="obs8-v1",source_frame_id="f",feature_id="f0",color_band="muted_red"}
    local base={now_us=250000,life_busy=false,mapping_valid=true,mapping_expires_us=2000000,translation=0,tilt_deg=0,profile_id="fixture-distant-enabled",profile_revision=1,
        source_pose="source",pose_ref="start",source_to_start_deg=0,clock_id="world-sim-v1",measured_right_deg=32.5}
    local function verify(ok) assert(ok,"OBS8 controller check " .. count); count=count+1 end
    for _,case in ipairs({{"now_us",2000000,true},{"now_us",2000001,false},{"now_us",-1,false},{"life_busy",true,false},
                         {"mapping_valid",false,false},{"mapping_expires_us",249999,false},{"translation",0.00001,false},
                         {"tilt_deg",0.02,false},{"profile_revision",2,false},{"clock_id","other",false},
                         {"source_to_start_deg",-12.5,true},{"source_to_start_deg",-12.6,false}}) do
        local b=table.copy(base); b[case[1]]=case[2]
        local p=probe.plan(frame,frame.payload.features[1],req,b); verify((p~=nil)==case[3])
    end
    for _,case in ipairs({{"now_us",1750000,true},{"now_us",1750001,false},{"now_us",2000001,false},
                         {"life_busy",true,false},{"mapping_valid",false,false},{"translation",0.001,false},
                         {"profile_revision",2,false},{"measured_right_deg",34,false}}) do
        local c=probe.new("r",1,"npc_a");local e=c.start(req,frame,base)
        local calls=0
        verify(c.rotate(e,base,function() calls=calls+1 end,function() return 32.5 end))
        local b=table.copy(base);b[case[1]]=case[2]
        verify(c.guard(e,b)==case[3]); verify(calls==1)
    end
    for _,actual in ipairs({32.52,46}) do
        local c=probe.new("r",1,"npc_a");local e=c.start(req,frame,base)
        verify(not c.rotate(e,base,function() end,function() return actual end) and e.operation_status=="aborted")
    end
    local c=probe.new("r",1,"npc_a");local e=c.start(req,frame,base)
    local copy=table.copy(req);copy.operation_id="other"
    verify(c.start(copy,frame,base).reasons[1]=="operation_busy")
    copy=table.copy(req);copy.source_frame_id="missing";verify(not pcall(c.start,copy,frame,base))
    copy=table.copy(req);copy.extra="World-secret";verify(not pcall(c.start,copy,frame,base))
    verify(c.rotate(e,base,function() end,function() return 32.5 end))
    local b=table.copy(base);b.now_us=250000
    verify(c.sample(e,0,b,function() error("same-time sample") end)==nil)
    b.now_us=500000;verify(c.sample(e,2,b,function() error("off-slot sample") end)==nil)
    b.now_us=1000000;verify(c.sample(e,4,b,function() return {frame_id="new"} end).frame_id=="new")
    verify(c.sample(e,8,b,function() error("repeat sample") end)==nil)
    c=probe.new("r",1,"npc_a");e=c.start(req,frame,base)
    verify(not c.rotate(e,base,function() end,function() return nil end) and e.operation_status=="aborted")
    c=probe.new("r",1,"npc_a");e=c.start(req,frame,base)
    b=table.copy(base);b.source_to_start_deg=5
    verify(not c.rotate(e,b,function() error("stale plan") end,function() return 32.5 end))
    local zero=table.copy(base);zero.source_to_start_deg=32.5;zero.measured_right_deg=0
    c=probe.new("r",1,"npc_a");e=c.start(req,frame,zero)
    verify(c.rotate(e,zero,function() error("zero rotation") end,function() return 0 end) and e.rotations==0)
    c=probe.new("r",1,"npc_a");e=c.start(req,frame,base)
    c.rotate(e,base,function() end,function() return 32.5 end)
    b=table.copy(base);b.now_us=1250000
    verify(c.sample(e,5,b,function() error("missed next slot") end)==nil and e.operation_status=="aborted")
    verify(probe.wrap(181)==-179 and probe.wrap(-181)==179)
    return count
end
