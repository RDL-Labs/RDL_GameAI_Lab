return function(controller,ground)
    local count=0
    local function check(ok) count=count+1;assert(ok,"L13 check " .. count) end
    local function fixture()
        local b={position={x=0,y=1,z=0},yaw=0,revision=0,pose_ref="pose0"}
        local n=0
        local ctl=controller.new("r",{body=function() return table.copy(b) end,execute=function(c)
            n=n+1;b.position.z=b.position.z+1;b.revision=b.revision+1;b.pose_ref="pose" .. b.revision;return "moved"
        end})
        local p={run_id="r",world_epoch=1,agent_id="npc_a",clock_id="world-sim-v1",observation_id="o",
            capture_us=0,pose_ref="pose0",body_revision=0,food={coverage="complete",visible={}}}
        local c={run_id="r",world_epoch=1,agent_id="npc_a",operation_id="op:o",source_id="o",capture_us=0,
            pose_ref="pose0",body_revision=0,expires_us=500000,kind="move",amount=1,target_ref="",reason="test"}
        return ctl,p,c,b,function()return n end
    end
    local ctl,p,c,b,n=fixture()
    local r,new=ctl:consume(c,p,1);check(new and r.status=="moved" and n()==1)
    check(r.forward==1 and r.right==0 and r.after_revision==1)
    local _,again=ctl:consume(c,p,2);check(not again and n()==1)
    local changed=table.copy(c);changed.reason="changed";check(not pcall(ctl.consume,ctl,changed,p,3))
    for _,field in ipairs({"run_id","agent_id","source_id","pose_ref","operation_id"}) do
        local x=table.copy(c);x[field]="foreign";check(not pcall(ctl.consume,ctl,x,p,3))
    end
    local x=table.copy(c);x.amount=2;check(not pcall(ctl.consume,ctl,x,p,3))
    x=table.copy(c);x.kind="pickup";x.amount=0;x.target_ref="unseen";check(not pcall(ctl.consume,ctl,x,p,3))
    ctl,p,c,b,n=fixture();r=ctl:consume(c,p,500000);check(r.status=="expired" and n()==0)
    ctl,p,c,b,n=fixture();b.revision=1;b.pose_ref="other";r=ctl:consume(c,p,1);check(r.status=="stale" and n()==0)
    ctl,p,c,b,n=fixture();ctl.stopped=true;r=ctl:consume(c,p,16000000);check(r.status=="stopped" and n()==0)
    ctl,p,c,b,n=fixture();ctl.count=64;check(not pcall(ctl.consume,ctl,c,p,1) and n()==0)
    local function read(pos)
        return {name=pos.y==0 and (pos.x==0 and "rdl_bridge:exploration_blue" or "rdl_bridge:exploration_gray") or "air"}
    end
    local g=ground.sample({x=0,y=1,z=0},0,read)
    check(#g.cells==9 and g.coverage=="complete")
    check(g.cells[2].color=="blue" and g.cells[4].color=="gray")
    g=ground.sample({x=0,y=1,z=0},math.pi/2,read)
    check(g.cells[2].color=="gray" and g.cells[4].color=="blue")
    g=ground.sample({x=0,y=1,z=0},0,function()return nil end)
    check(g.coverage=="partial" and g.cells[2].status=="unloaded" and g.cells[2].color=="unknown")
    g=ground.sample({x=0,y=1,z=0},0,function(pos)
        if pos.z==1 and pos.y==1 then return {name="rdl_bridge:opaque_wall"} end
        return read(pos)
    end)
    check(g.coverage=="partial" and g.cells[2].status=="occluded")
    g=ground.sample({x=0,y=1,z=0},0,function()return {name="air"} end)
    check(g.coverage=="partial" and g.cells[1].status=="no_surface")
    ctl,p,c,b,n=fixture();p.agent_id="npc_b";check(not pcall(ctl.consume,ctl,c,p,1) and n()==0)
    -- Reentry during the body effect sees the reserved operation, never a fresh permit.
    local calls=0
    ctl,p,c,b=fixture()
    local reentrant
    reentrant=controller.new("r",{body=function()return table.copy(b)end,execute=function(cmd)
        calls=calls+1;local _,fresh=reentrant:consume(cmd,p,1);check(not fresh)
        b.position.z=1;b.revision=1;b.pose_ref="pose1";return "moved"
    end})
    reentrant:consume(c,p,1);check(calls==1 and reentrant.count==1)
    return count
end
