-- L15A bounded first-hit rays. No destination oracle, terrain height function,
-- private obstacle list, resource stock or World coordinates in Runtime payload.
local M={schema="l15a-current-surface-rays-v1",missing="__l15a_missing_height__"}
local angles={-90,-45,0,45,90}
local obstacle_angles={-90,-60,-30,-10,10,30,60,90}
local supports={ ["rdl_bridge:exploration_grass"]=true,
    ["rdl_bridge:exploration_dirt"]=true,["rdl_bridge:exploration_stone"]=true }
local function ray(start,finish,read,steps)
    local delta=vector.subtract(finish,start)
    for i=0,steps do
        local point=vector.add(start,vector.multiply(delta,i/steps))
        local node=read(vector.round(point))
        if not node or node.name=="ignore" then return "unavailable",point,nil,i+1 end
        if node.name~="air" then return "hit",point,node.name,i+1 end
    end
    return "clear",finish,nil,steps+1
end
function M.sample(packet,position,yaw,read)
    local f=core.yaw_to_dir(yaw);local r={x=f.z,y=0,z=-f.x}
    local eye=vector.add(position,{x=0,y=.5,z=0})
    local function offset(angle,distance,up)
        local a=math.rad(angle)
        return {x=distance*(math.cos(a)*f.x+math.sin(a)*r.x),y=up,
                z=distance*(math.cos(a)*f.z+math.sin(a)*r.z)}
    end
    local function channel(name)
        local source={frame_id=packet.observation_id .. ":" .. name}
        for _,key in ipairs({"run_id","world_epoch","agent_id","observation_id","clock_id",
            "capture_us","pose_ref","body_revision"}) do source[key]=packet[key] end
        return {source=source,coverage="complete",output_limited=false}
    end
    local ground,obstacles=channel("ground"),channel("obstacles")
    ground.samples={};obstacles.items={}
    local audit={ground={},obstacles={},reads=0}
    for _,angle in ipairs(angles) do
        local finish=vector.add(position,offset(angle,1,-3))
        local status,hit,name,reads=ray(eye,finish,read,30)
        local height=M.missing
        if status=="hit" then
            if supports[name] then status="sampled";height=math.floor(hit.y+.5)+1-position.y
            else status="blocked" end
        elseif status=="clear" then status="no_surface"
        else ground.coverage="partial" end
        ground.samples[#ground.samples+1]={direction_deg=angle,status=status,height_delta=height}
        audit.ground[#audit.ground+1]={angle=angle,start=eye,finish=finish,hit=hit,node=name,status=status,reads=reads}
        audit.reads=audit.reads+reads
    end
    for index,angle in ipairs(obstacle_angles) do
        local start=vector.add(position,{x=0,y=.25,z=0})
        local finish=vector.add(start,offset(angle,6,0))
        local status,hit,name,reads=ray(start,finish,read,48)
        if status=="unavailable" then obstacles.coverage="partial"
        elseif status=="hit" then
            local delta=vector.subtract(hit,start)
            obstacles.items[#obstacles.items+1]={ref=packet.observation_id .. ":ray:" .. index,
                forward=math.max(0,vector.dot(delta,f)),right=vector.dot(delta,r)}
        end
        audit.obstacles[#audit.obstacles+1]={angle=angle,start=start,finish=finish,hit=hit,node=name,status=status,reads=reads}
        audit.reads=audit.reads+reads
    end
    assert(audit.reads<=547,"ray read budget") -- 5*31 + 8*49
    return {schema=M.schema,ground=ground,obstacles=obstacles},audit
end
return M
