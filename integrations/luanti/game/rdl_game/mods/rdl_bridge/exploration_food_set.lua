-- L13W bounded local observation of five independent World resources.
local M={}
function M.sample(foods,position,yaw,visibility)
    local visible,audit,coverage={},{},"complete"
    local f=core.yaw_to_dir(yaw);local r={x=f.z,y=0,z=-f.x}
    for i=1,5 do
        local obj=foods[i]
        if obj and obj:get_pos() then
            local delta=vector.subtract(obj:get_pos(),position);local distance=vector.length(delta)
            local seen,status=false,"complete"
            if distance<=12 then seen,status=visibility(vector.add(position,{x=0,y=.5,z=0}),obj:get_pos()) end
            local ref=obj:get_luaentity().rdl_id
            audit[#audit+1]={ref=ref,distance=distance,in_range=distance<=12,line_of_sight=seen,coverage=status}
            if status~="complete" then coverage="partial" end
            if distance<=12 and seen then
                visible[#visible+1]={ref=ref,distance=distance,forward=vector.dot(delta,f),right=vector.dot(delta,r),up=delta.y}
            end
        end
    end
    table.sort(visible,function(a,b) if a.distance==b.distance then return a.ref<b.ref end;return a.distance<b.distance end)
    return visible,coverage,audit
end
function M.pickup(foods,ref,position)
    for i=1,5 do
        local f=foods[i]
        if f and f:get_pos() and f:get_luaentity().rdl_id==ref and vector.distance(position,f:get_pos())<=1.25 then
            f:remove();assert(f:get_pos()==nil);foods[i]=nil
            return true
        end
    end
    return false
end
return M
