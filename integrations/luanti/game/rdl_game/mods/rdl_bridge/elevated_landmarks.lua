-- Generic finite first-surface rays. Node/position/distance stay in audit only.
local M={}
local colors={grass="green",dirt="brown",stone="gray",trunk="brown",leaves="green",water="blue",
    rock_gray="gray",rock_red="red",patch_brown="brown",patch_gray="gray",tower="ochre"}
function M.sample(position,yaw,read,source)
    local frame={model="finite-elevated-fan-v1",source=source,coverage="complete",features={}}
    local audit={};local eye=vector.add(position,{x=0,y=.5,z=0})
    for _,elevation in ipairs({0,15,30}) do
        for index=0,12 do
            local angle=-90+15*index
            local horizontal=core.yaw_to_dir(yaw-math.rad(angle))
            local dir=vector.multiply(horizontal,math.cos(math.rad(elevation)));dir.y=math.sin(math.rad(elevation))
            local ray={azimuth=angle,elevation=elevation,status="empty",samples=0}
            for step=1,192 do
                local distance=step*.25
                local pos=vector.round(vector.add(eye,vector.multiply(dir,distance)))
                local node=read(pos);ray.samples=step
                if not node or node.name=="ignore" then ray.status="unloaded";frame.coverage="partial";break end
                if node.name~="air" then
                    local color=colors[node.name:match("^rdl_bridge:exploration_(.+)$")]
                    ray.hit={position=pos,node=node.name,distance=distance}
                    if not color then ray.status="unclassified";frame.coverage="partial";break end
                    ray.status="sampled"
                    frame.features[#frame.features+1]={ref="ray:" .. elevation .. ":" .. index,color=color,
                        azimuth={math.max(-90,angle-7.5),math.min(90,angle+7.5)},elevation=elevation,
                        range_band=distance<=8 and "near" or (distance<=24 and "mid" or "far")}
                    break
                end
            end
            audit[#audit+1]=ray
        end
    end
    return frame,audit
end
return M
