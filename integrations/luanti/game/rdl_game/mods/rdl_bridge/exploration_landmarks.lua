-- Bounded first-surface fan. Coordinates/node names are returned only as audit.
local M={}
local colors={grass="green",dirt="brown",stone="gray",trunk="brown",leaves="green",water="blue",
    rock_gray="gray",rock_red="red"}
function M.sample(position,yaw,read)
    local eye=vector.add(position,{x=0,y=.5,z=0})
    local frame={model="l13u-horizontal-surface-fan-v1",profile="l13u-landmark-fixed-v1",
        coverage="complete",output_limited=false,features={}}
    local audit={};local previous_ray=-2
    for index=0,12 do
        local angle=-90+15*index
        local dir=core.yaw_to_dir(yaw-math.rad(angle))
        local ray={angle=angle,status="empty",samples=0}
        for step=1,192 do
            local distance=step*.125
            local pos=vector.round(vector.add(eye,vector.multiply(dir,distance)))
            local node=read(pos);ray.samples=step
            if not node or node.name=="ignore" then ray.status="unloaded";frame.coverage="partial";break end
            if node.name~="air" then
                local color=colors[node.name:match("^rdl_bridge:exploration_(.+)$")]
                ray.hit={position=pos,node=node.name,distance=distance}
                if not color then ray.status="unclassified";frame.coverage="partial";break end
                ray.status="sampled"
                local band=distance<=3 and "near" or (distance<=12 and "mid" or "far")
                local lo,hi=math.max(-90,angle-7.5),math.min(90,angle+7.5)
                local last=frame.features[#frame.features]
                if previous_ray==index-1 and last and last.color==color and last.range_band==band then
                    last.azimuth[2]=hi
                else
                    frame.features[#frame.features+1]={ref="patch" .. #frame.features,color=color,azimuth={lo,hi},range_band=band}
                end
                previous_ray=index;break
            end
        end
        audit[#audit+1]=ray
    end
    return frame,audit
end
return M
