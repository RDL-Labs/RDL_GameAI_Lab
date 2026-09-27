return function(natural,controller)
    local count=0
    local function check(ok) count=count+1;assert(ok,"L13T check " .. count) end
    local function scene(height,obstacle)
        return function(p)
            if obstacle then local n=obstacle(p);if n then return {name=n} end end
            local h=height(p.x,p.z)
            return {name=p.y<=h and "rdl_bridge:exploration_grass" or "air"}
        end
    end
    local p={x=0,y=1,z=0};local dir={x=0,y=0,z=1}
    local flat=scene(function()return 0 end)
    local step=scene(function(_,z)return z>=1 and 1 or 0 end)
    local dest,audit=natural.destination(p,dir,flat)
    check(dest.y==1 and dest.z==1 and audit.reason=="supported_step")
    dest=natural.destination(p,dir,step);check(dest.y==2 and dest.z==1)
    dest=natural.destination({x=0,y=2,z=1},{x=0,y=0,z=-1},step);check(dest.y==1)
    dest=natural.destination(p,dir,scene(function(_,z)return z>=1 and 2 or 0 end));check(dest==nil)
    dest=natural.destination(p,dir,scene(function(_,z)return z>=1 and -2 or 0 end));check(dest==nil)
    dest=natural.destination(p,dir,scene(function()return 0 end,function(q)
        if q.z==1 and q.y>=1 and q.y<=4 then return "rdl_bridge:exploration_trunk" end
    end));check(dest==nil)
    dest=natural.destination(p,dir,scene(function()return 0 end,function(q)
        if q.z==1 and q.y==0 then return "rdl_bridge:exploration_water" end
    end));check(dest==nil)
    dest=natural.destination(p,dir,function()return nil end);check(dest==nil)
    dest=natural.destination({x=0,y=1,z=32},dir,flat);check(dest==nil)
    local g=natural.sample(p,0,flat);check(g.coverage=="complete" and #g.cells==9 and g.cells[1].color=="green")
    g=natural.sample(p,0,function()return nil end);check(g.coverage=="partial" and g.cells[1].status=="unloaded")
    g=natural.sample(p,0,function()return {name="air"}end);check(g.coverage=="partial" and g.cells[1].status=="no_surface")
    g=natural.sample(p,0,function()return {name="rdl_bridge:exploration_trunk"}end)
    check(g.coverage=="complete" and g.cells[1].color=="brown")
    local seen,coverage=natural.visibility(p,{x=0,y=1,z=4},flat);check(seen and coverage=="complete")
    seen,coverage=natural.visibility(p,{x=0,y=1,z=4},scene(function()return 0 end,function(q)
        if q.z==2 then return "rdl_bridge:exploration_stone" end
    end));check(not seen and coverage=="complete")
    seen,coverage=natural.visibility(p,{x=0,y=1,z=4},function()return nil end);check(not seen and coverage=="partial")
    -- Measured vertical change and duplicate operation are independently checked.
    local body={position=vector.new(p),yaw=0,revision=0,pose_ref="p0"};local calls=0
    local ctl=controller.new("r",{natural=true,body=function()return table.copy(body)end,execute=function()
        calls=calls+1;body.position={x=0,y=2,z=1};body.revision=1;body.pose_ref="p1";return "moved"
    end})
    local packet={run_id="r",world_epoch=1,agent_id="npc_a",clock_id="world-sim-v1",observation_id="o",
        capture_us=0,pose_ref="p0",body_revision=0}
    local command={run_id="r",world_epoch=1,agent_id="npc_a",source_id="o",operation_id="op:o",capture_us=0,
        pose_ref="p0",body_revision=0,expires_us=500000,kind="move",amount=1,target_ref=""}
    local r=ctl:consume(command,packet,1);check(r.up==1 and r.forward==1 and math.abs(ctl.distance-math.sqrt(2))<.00001)
    local again,fresh=ctl:consume(command,packet,2);check(not fresh and again.up==1 and calls==1)
    return count
end
