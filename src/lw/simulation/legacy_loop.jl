using JSON3
include(joinpath(@__DIR__, "../../geometry/RDLMigrationProbe.jl"))
using .RDLMigrationProbe

const ANGLES=(-90,-45,0,45,90)
include(joinpath(@__DIR__, "../../body/load.jl"))
include("../../data/lw_agent.jl")
bodydict(b)=Dict("rule"=>"layered-body-human-scale-v1", "burst"=>b.burst,
    "strain"=>b.strain,"reserve"=>b.reserve,"damage"=>b.damage)
state(a)=Dict("x"=>a.x,"z"=>a.z,"yaw"=>a.yaw,"inventory"=>a.inventory,"body"=>bodydict(a.body))

function simulate(scene, trace=false)
    agents=[Agent(p[1],p[2],0.,0,Body(10.,0.,scene.reserve,0.)) for p in scene.agents]
    stock=Int[f.stock for f in scene.food]
    obstacles=[RDLMigrationProbe.Circle(o.x,o.z,o.radius) for o in scene.obstacles]
    rows=Any[]
    counts=Dict(k=>0 for k in ("walk","rest","eat","pickup","blocked_samples","body_limited_samples"))
    for tick in 0:scene.ticks-1, (index,a) in enumerate(agents)
        origin=(a.x,a.z);yaw=deg2rad(a.yaw);s,c=sin(yaw),cos(yaw)
        visible=NamedTuple{(:ref,:forward,:right,:distance),Tuple{Int,Float64,Float64,Float64}}[]
        for (j,f) in enumerate(scene.food)
            dx,dz=f.x-a.x,f.z-a.z
            forward,right=dx*s+dz*c,dx*c-dz*s;distance=hypot(forward,right)
            if stock[j]>0 && distance<=12 && forward>=0 && !any(o->segment_hit(origin,(Float64(f.x),Float64(f.z)),o,0.),obstacles)
                push!(visible,(ref=j-1,forward=forward,right=right,distance=distance))
            end
        end
        sort!(visible,by=v->(v.distance,v.ref));resize!(visible,min(5,length(visible)))
        target=isempty(visible) ? nothing : visible[1]
        candidates=Any[];chosen=-1;best=Inf
        for (j,angle) in enumerate(ANGLES)
            theta=deg2rad(a.yaw+angle);endpoint=(a.x+sin(theta),a.z+cos(theta))
            clear=!any(o->segment_hit(origin,endpoint,o,.2),obstacles)
            goal=target===nothing ? 1.0+abs(angle)/90 : min(10.,hypot(target.forward-cos(deg2rad(Float64(angle))),target.right-sin(deg2rad(Float64(angle)))))
            _,status,_,delta=step(a.body,"walk",a.inventory,scene.resistance,clear)
            cost=status=="performed" ? goal-delta["reserve"]/max(a.body.reserve,.001)-delta["burst"]/max(a.body.burst,.001)+delta["strain"] : nothing
            counts["blocked_samples"]+=status=="blocked"
            counts["body_limited_samples"]+=status=="body_limited"
            if cost!==nothing && cost<best
                best=cost;chosen=j-1
            end
            if trace
                push!(candidates,Dict("ref"=>string(j-1),"action"=>"walk","clear"=>clear,
                    "resistance"=>scene.resistance,"goal_cost"=>goal,"status"=>status,
                    "cost"=>cost,"expected_delta"=>delta))
            end
        end
        if a.inventory>0 && a.body.reserve<80
            action="eat";a.body,status,_,_=step(a.body,action,a.inventory);a.inventory-=1;chosen=-1
        elseif target!==nothing && target.distance<=1.25
            action="pickup";status="picked_up";stock[target.ref+1]-=1;a.inventory+=1;chosen=-1
        elseif chosen<0
            action="rest";a.body,status,_,_=step(a.body,action,a.inventory)
        else
            action="walk";a.yaw=mod(a.yaw+ANGLES[chosen+1]+180,360)-180
            a.body,status,distance,_=step(a.body,action,a.inventory,scene.resistance)
            theta=deg2rad(a.yaw);a.x+=sin(theta)*distance;a.z+=cos(theta)*distance
        end
        counts[action]+=1
        trace && push!(rows,Dict("tick"=>tick,"agent"=>index-1,"visible"=>visible,
            "candidates"=>candidates,"action"=>action,"chosen"=>chosen,"status"=>status,
            "state"=>state(a),"stock"=>copy(stock)))
    end
    @assert sum(stock)+sum(a.inventory for a in agents)+counts["eat"]==sum(f.stock for f in scene.food)
    Dict("agents"=>state.(agents),"stock"=>stock,"counts"=>counts,"trace"=>rows)
end

function main()
    mode,input,output=ARGS
    scenes=JSON3.read(read(input,String));results=Dict{String,Any}()
    for scene in scenes
        if mode=="trace"
            results[scene.name]=simulate(scene,true)
        else
            simulate(scene)
            times=Float64[];result=nothing
            for _ in 1:3
                start=time_ns();result=simulate(scene);push!(times,(time_ns()-start)/1e9)
            end
            results[scene.name]=Dict("seconds"=>times,"counts"=>result["counts"])
        end
    end
    open(output,"w") do io
        JSON3.write(io,results)
    end
end
