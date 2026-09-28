-- Sensor-only synthetic controls, executed under real Luanti; not World acceptance.
return function(sensor)
    local count=0
    local function check(ok) assert(ok,"movement surface check " .. count+1);count=count+1 end
    local packet={run_id="check",world_epoch=1,agent_id="npc_a",clock_id="world-sim-v1",
        observation_id="check:obs",capture_us=0,pose_ref="check:pose",body_revision=0}
    local function sample(read) return sensor.sample(packet,{x=0,y=1,z=0},0,read) end
    local function floor(p) return {name=p.y<=0 and "rdl_bridge:exploration_grass" or "air"} end
    local s,a=sample(floor)
    check(s.ground.coverage=="complete" and s.obstacles.coverage=="complete")
    check(#s.ground.samples==5 and #s.obstacles.items==0)
    for _,row in ipairs(s.ground.samples) do check(row.status=="sampled" and row.height_delta==0) end
    check(a.reads<=547 and #a.ground==5 and #a.obstacles==8)
    s,a=sample(function() return {name="air"} end)
    check(a.reads==547)
    check(s.ground.samples[3].status=="no_surface" and s.ground.samples[3].height_delta==sensor.missing)
    s=sample(function() return nil end)
    check(s.ground.coverage=="partial" and s.obstacles.coverage=="partial")
    check(s.ground.samples[1].status=="unavailable" and #s.obstacles.items==0)
    local counts={}
    for _,sign in ipairs({-1,1}) do
        s=sample(function(p)
            if p.x==sign and p.z==2 and p.y==1 then return {name="rdl_bridge:exploration_trunk"} end
            return floor(p)
        end)
        check(#s.obstacles.items>0)
        for _,o in ipairs(s.obstacles.items) do check(o.right*sign>0 and o.forward>=0) end
        counts[#counts+1]=#s.obstacles.items
    end
    check(counts[1]==counts[2])
    s=sample(function() return {name="rdl_bridge:exploration_trunk"} end)
    check(#s.obstacles.items==8 and s.ground.samples[3].status=="blocked")
    check(s.ground.source.pose_ref==packet.pose_ref and s.obstacles.source.agent_id==packet.agent_id)
    return count
end
