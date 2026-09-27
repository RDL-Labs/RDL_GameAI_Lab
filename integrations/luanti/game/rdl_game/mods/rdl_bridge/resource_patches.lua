-- L14A private finite stock. No stock, tree identities or coordinates enter packets.
local M={texture="rdl_l14_acorn.png"}
local prefix="rdl_bridge:exploration_"
local sites={{18,18},{-18,-17},{-20,7},{7,-20},{20,-6},{-7,18},{17,-18},{-17,-24}}
function M.register(natural,landmarks)
    for _,color in ipairs({"brown","gray"}) do
        local name="patch_" .. color
        core.register_node(prefix .. name,{description="L14A observed bark surface",
            tiles={"rdl_l13_gray.png^[colorize:" .. (color=="brown" and "#884d28" or "#93988f") .. ":200"},
            walkable=true,pointable=false})
        natural.register_surface(name,color);landmarks.register_surface(name,color)
    end
end
function M.build(run,natural,control)
    local patches,trees={},{}
    local positions=control and {{0,3},{5,3}} or sites
    local function tree(x,z,color)
        local y=natural.height(x,z)
        for h=y+1,y+4 do core.set_node({x=x,y=h,z=z},{name=prefix .. "patch_" .. color}) end
        for xx=x-1,x+1 do for zz=z-1,z+1 do
            core.set_node({x=xx,y=y+4,z=zz},{name=prefix .. "leaves"})
        end end
        trees[#trees+1]={position={x=x,y=y+1,z=z},color=color,
            readback=core.get_node({x=x,y=y+1,z=z}).name}
    end
    for i,p in ipairs(positions) do
        local pos={x=p[1],y=natural.height(p[1],p[2])+1,z=p[2]}
        assert(core.get_node(pos).name=="air","predeclared resource site obstructed")
        local ref=run .. ":material:" .. i
        local obj=assert(core.add_entity(pos,"rdl_bridge:food",ref))
        obj:set_properties({textures={M.texture},visual_size={x=.65,y=.65}})
        patches[i]={object=obj,ref=ref,initial=2,remaining=2,position=vector.new(pos)}
        tree(p[1],p[2]+1,i<=6 and "brown" or "gray")
    end
    if not control then
        for i,p in ipairs({{-6,-12},{12,8},{-25,19},{26,23}}) do tree(p[1],p[2],i<=2 and "brown" or "gray") end
    end
    return patches,trees
end
function M.audit(patches)
    local out={}
    for _,p in ipairs(patches) do
        assert(p.remaining==0 or (p.object and p.object:get_pos()),"live stock object lost")
        out[#out+1]={ref=p.ref,position=vector.new(p.position),initial=p.initial,remaining=p.remaining,
            present=p.object~=nil and p.object:get_pos()~=nil}
    end
    return out
end
function M.appearance(obj)
    local props=obj:get_properties()
    assert(props.visual=="sprite" and props.textures[1]==M.texture,"unrecognized material rendering")
    return "brown_capped_ovoid"
end
function M.sample(patches,position,yaw,visibility)
    local visible,audit,coverage={},{},"complete"
    local f=core.yaw_to_dir(yaw);local r={x=f.z,y=0,z=-f.x}
    for _,p in ipairs(patches) do
        assert(p.remaining==0 or (p.object and p.object:get_pos()),"live stock object lost")
        if p.object and p.object:get_pos() then
            local delta=vector.subtract(p.object:get_pos(),position);local distance=vector.length(delta)
            local seen,status=false,"complete"
            if distance<=12 then seen,status=visibility(vector.add(position,{x=0,y=.5,z=0}),p.object:get_pos()) end
            audit[#audit+1]={ref=p.ref,distance=distance,in_range=distance<=12,line_of_sight=seen,coverage=status}
            if status~="complete" then coverage="partial" end
            if distance<=12 and seen then visible[#visible+1]={ref=p.ref,distance=distance,
                forward=vector.dot(delta,f),right=vector.dot(delta,r),up=delta.y,appearance=M.appearance(p.object)} end
        end
    end
    table.sort(visible,function(a,b) if a.distance==b.distance then return a.ref<b.ref end;return a.distance<b.distance end)
    if #visible>5 then coverage="partial";while #visible>5 do table.remove(visible) end end
    return visible,coverage,audit
end
function M.pickup(patches,ref,position)
    for _,p in ipairs(patches) do
        if p.ref==ref and p.remaining>0 and p.object and p.object:get_pos()
                and vector.distance(position,p.object:get_pos())<=1.25 then
            p.remaining=p.remaining-1
            if p.remaining==0 then p.object:remove();assert(p.object:get_pos()==nil);p.object=nil end
            return true
        end
    end
    return false
end
function M.teach(run,natural,npc)
    local pos=vector.add(npc:get_pos(),{x=0,y=0,z=2})
    local sample=assert(core.add_entity(pos,"rdl_bridge:food",run .. ":statue-sample"))
    sample:set_properties({textures={M.texture},visual_size={x=.65,y=.65}})
    local statue=vector.add(npc:get_pos(),{x=-2,y=0,z=2})
    core.set_node(vector.round(statue),{name=prefix .. "patch_gray"})
    local seen,coverage=natural.visibility(vector.add(npc:get_pos(),{x=0,y=.5,z=0}),pos,core.get_node_or_nil)
    assert(seen and coverage=="complete","sample not observed")
    local teaching={statement_id=run .. ":teaching",source="god_statue",sample_observation=run .. ":sample-observation",
        appearance=M.appearance(sample),predicate="food_after_known_processing"}
    local audit={sample_position=pos,observer_position=npc:get_pos(),distance=vector.distance(pos,npc:get_pos()),
        sample_texture=sample:get_properties().textures[1],line_of_sight=seen,coverage=coverage,
        statue_position=statue,statue_readback=core.get_node(vector.round(statue)).name}
    sample:remove() -- demonstration is not harvestable stock or an acquisition Experience
    return teaching,audit
end
return M
