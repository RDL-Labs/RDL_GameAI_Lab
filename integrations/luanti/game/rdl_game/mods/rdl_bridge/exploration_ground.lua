-- Fixed downward acquisition plan. No path list or destination is consulted.
local M = {}
M.cells = {{"center",0,0},{"front1",1,0},{"front2",2,0},{"right1",0,1},{"right2",0,2},
    {"left1",0,-1},{"left2",0,-2},{"back1",-1,0},{"back2",-2,0}}
function M.sample(position, yaw, read)
    local forward=core.yaw_to_dir(yaw)
    local right={x=forward.z,y=0,z=-forward.x}
    local eye=vector.add(position,{x=0,y=.5,z=0})
    local out={model="l13a-ground-nine-v1",profile="l13a-ground-fixed-v1",coverage="complete",cells={}}
    for _,spec in ipairs(M.cells) do
        local point=vector.add(position,vector.add(vector.multiply(forward,spec[2]),vector.multiply(right,spec[3])))
        local floor={x=math.floor(point.x+.5),y=0,z=math.floor(point.z+.5)}
        local target={x=floor.x,y=.51,z=floor.z}
        local delta=vector.subtract(target,eye)
        local n=math.ceil(vector.length(delta)/.25)
        local color,status="unknown","sampled"
        for i=1,n do
            local node=read(vector.round(vector.add(eye,vector.multiply(delta,i/n))))
            if not node or node.name=="ignore" then status="unloaded";break end
            if node.name~="air" and node.name~="rdl_bridge:observation_space" then status="occluded";break end
        end
        if status=="sampled" then
            local node=read(floor)
            if not node or node.name=="ignore" then status="unloaded"
            elseif node.name=="rdl_bridge:exploration_blue" then color="blue"
            elseif node.name=="rdl_bridge:exploration_gray" then color="gray"
            else status="no_surface" end
        end
        if status~="sampled" then out.coverage="partial" end
        out.cells[#out.cells+1]={cell_id=spec[1],color=color,status=status}
    end
    return out
end
return M
