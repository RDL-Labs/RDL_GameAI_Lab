return function(sensor,controller)
    local count=0
    local function check(ok)count=count+1;assert(ok,"L13U check " .. count)end
    local p={x=0,y=1,z=0}
    local frame,rays=sensor.sample(p,0,function(q)
        if q.z==6 then return {name="rdl_bridge:exploration_stone"} end
        return {name="air"}
    end)
    check(frame.coverage=="complete" and #rays==13)
    check(#frame.features>0 and rays[7].hit.position.z==6 and rays[7].hit.node=="rdl_bridge:exploration_stone")
    check(rays[7].hit.distance<=6 and rays[7].hit.distance>5)
    check(frame.features[1].ref=="patch0" and frame.features[1].color=="gray")
    frame,rays=sensor.sample(p,0,function(q)
        if q.z==2 then return {name="rdl_bridge:exploration_trunk"} end
        if q.z==6 then return {name="rdl_bridge:exploration_stone"} end
        return {name="air"}
    end)
    check(rays[7].hit.node=="rdl_bridge:exploration_trunk" and rays[7].hit.distance<=3)
    frame=sensor.sample(p,0,function()return nil end)
    check(frame.coverage=="partial" and #frame.features==0)
    frame,rays=sensor.sample(p,0,function()return {name="air"}end)
    check(frame.coverage=="complete" and #frame.features==0 and rays[7].samples==192)
    local body={position=p,yaw=0,revision=0,pose_ref="p0"};local calls=0
    local ctl=controller.new("r",{natural=true,landmarks=true,body=function()return table.copy(body)end,execute=function(c)
        calls=calls+1;body.yaw=body.yaw-math.rad(c.amount);body.revision=1;body.pose_ref="p1";return "turned"
    end})
    local packet={run_id="r",world_epoch=1,agent_id="npc_a",clock_id="world-sim-v1",observation_id="o",
        capture_us=0,pose_ref="p0",body_revision=0}
    local command={run_id="r",world_epoch=1,agent_id="npc_a",source_id="o",operation_id="op:o",capture_us=0,
        pose_ref="p0",body_revision=0,expires_us=500000,kind="turn",amount=25,target_ref=""}
    local r=ctl:consume(command,packet,1);check(math.abs(r.yaw-25)<.001 and r.up==0)
    local _,fresh=ctl:consume(command,packet,2);check(not fresh and calls==1)
    local bad=table.copy(command);bad.amount=26
    check(not pcall(ctl.consume,ctl,bad,packet,3))
    return count
end
