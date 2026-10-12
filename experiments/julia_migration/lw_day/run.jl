using Test
include(joinpath(@__DIR__,"../moving_social/run.jl"))

# B0 lifecycle scaffold. Current observed relative beacon only; no stored home coordinate in policy.
function home_observation(w,a,yaw,home)
    p=w.positions[a];dx,dz=home[1]-p[1],home[2]-p[2]
    s,c=sincos(deg2rad(yaw[a]));f,r=dx*s+dz*c,dx*c-dz*s
    d=hypot(dx,dz)
    if d<=60 && (f>=0 || d<=1.25) && !any(o->segment_hit(p,(Float64(home[1]),Float64(home[2])),o,0.),w.obstacles)
        return D("forward"=>f,"right"=>r,"distance"=>d)
    end
    nothing
end

function lw_day(spec,clock)
    w=moving_world(spec);w.capacity=100_000
    yaw=Dict(a=>0. for a in IDS);stock=Int[f.stock for f in spec.food]
    stores=Dict(a=>0 for a in IDS);states=Dict(a=>social_initial() for a in IDS)
    live=Dict(a=>live_aid(a) for a in IDS);results=Dict(a=>D() for a in IDS)
    answered=Dict(a=>Set{String}() for a in IDS);learning=Dict(a=>sleeper(0) for a in IDS)
    counts=Dict(a=>Dict{String,Int}() for a in IDS);events=Any[];previous=Dict{String,Any}()
    distance=Dict(a=>0. for a in IDS)
    for (i,a) in enumerate(IDS)
        w.inventory[a]=spec.initial_inventory[i];w.bodies[a]=Body(10.,0.,spec.reserve[i],0.)
    end
    initial=sum(stock)+sum(values(w.inventory));bounds=Int.(clock.phase_boundaries_us)
    integrate(a,now,obs)=begin
        before=length(states[a]["records"])
        if states[a]["pending"]!==nothing
            states[a]=ingest(states[a],D("agent_id"=>a,"capture_us"=>now,
                "observation_id"=>"ob:$now:$a","social"=>obs),results[a])
        end
        pressure_poll!(live[a],states[a]["records"],before)
    end
    for sec in 0:div(clock.day_us,1_000_000)-1
        now=sec*1_000_000;w.seconds=sec
        phase=now<bounds[1] ? "orientation" : now<bounds[2] ? "exploration" : now<bounds[3] ? "return" : "night"
        obs=Dict(a=>observe(w,a) for a in IDS)
        moves=Dict(a=>movement_observation(w,a,yaw,spec.food,stock) for a in IDS)
        homes=Dict(a=>home_observation(w,a,yaw,spec.home) for a in IDS)
        plans=D()
        for a in IDS
            integrate(a,now,obs[a]);o=obs[a];plan=nothing;home=homes[a]
            at_home=home!==nothing && home["distance"]<=1.25
            messages=[m for m in reverse(o["messages"]) if !(m["id"] in answered[a]) && m["kind"] in ("request","warn","reach")]
            if !isempty(messages)
                m=first(messages);act,t,r=response(merge(copy(o),D("messages"=>[m])),a!="npc_b")
                plan=D("action"=>act,"target"=>t,"reply_to"=>r);push!(answered[a],m["id"])
            elseif w.bodies[a].reserve<80 && w.inventory[a]>0
                plan=D("action"=>"eat")
            elseif at_home && w.bodies[a].reserve<80 && stores[a]>0
                plan=D("action"=>"retrieve")
            elseif phase=="night" && now>=clock.quiet_night_us
                plan=D("action"=>"rest")
            elseif states[a]["pending"]!==nothing
                plan=D("action"=>"rest")
            elseif w.bodies[a].reserve<80
                targets=[x["ref"] for x in o["others"] if x["holding_food"]]
                target,_=select_target(targets,states[a]["model"],live[a].state)
                if target!==nothing
                    op="op:$now:$a"
                    states[a]["pending"]=D("message_id"=>a*":"*op,"target"=>target,"deadline"=>now+5_000_000,
                        "request_observation_id"=>"ob:$now:$a","operation_id"=>op)
                    plan=D("action"=>"request","target"=>target)
                end
            end
            returning=phase in ("return","night") || w.inventory[a]>=6
            if plan===nothing
                if returning && at_home
                    plan=D("action"=>w.inventory[a]>0 ? "deposit" : "rest")
                elseif phase=="orientation"
                    plan=D("action"=>"rest")
                elseif w.bodies[a].strain>=.8 || w.bodies[a].reserve<=0
                    plan=D("action"=>"rest")
                elseif returning && home===nothing
                    plan=D("action"=>"scan")
                else
                    visible=moves[a]["visible"];target=returning ? home : isempty(visible) ? nothing : first(visible)
                    if !returning && target!==nothing && target["distance"]<=1.25
                        plan=D("action"=>"pickup","food_ref"=>target["ref"])
                    else
                        scored=[r for r in moves[a]["energy"]["rows"] if r["cost"]!==nothing]
                        if isempty(scored)
                            plan=D("action"=>"scan")
                        else
                            # Temporary local steering, not ported LW nested M_B navigation.
                            sort!(scored,by=r->begin
                                ang=deg2rad(Float64(ANGLES[parse(Int,r["ref"])+1]))
                                target===nothing ? r["cost"] : hypot(target["forward"]-cos(ang),target["right"]-sin(ang))
                            end)
                            plan=D("action"=>"walk","direction"=>parse(Int,first(scored)["ref"]))
                        end
                    end
                end
            end
            plans[a]=plan
        end
        w.seconds=sec+1
        for a in IDS
            plan=plans[a];action=plan["action"];op="op:$now:$a";p=w.positions[a];status="performed"
            # Exactly one body update per simulated second, including non-movement actions.
            if action=="walk"
                yaw[a]=mod(yaw[a]+ANGLES[plan["direction"]+1]+180,360)-180
                s,c=sincos(deg2rad(yaw[a]));q=(p[1]+s*.5,p[2]+c*.5)
                clear=!any(o->segment_hit(p,q,o,.2),w.obstacles)
                w.bodies[a],status,d,_=step(w.bodies[a],"walk",w.inventory[a],1.5,clear)
                w.positions[a]=(p[1]+s*d,p[2]+c*d);distance[a]+=d
            elseif action in ("eat","request","give","refuse","warn","withdraw","wait")
                r=communicate!(w,a,op,action,get(plan,"target",nothing),get(plan,"reply_to",nothing));status=r["status"]
                results[a]=D(op=>r)
                if action!="eat"
                    w.bodies[a],_,_,_=step(w.bodies[a],"rest",w.inventory[a])
                end
            else
                w.bodies[a],_,_,_=step(w.bodies[a],"rest",w.inventory[a])
                if action=="scan"
                    yaw[a]=mod(yaw[a]+60+180,360)-180
                elseif action=="pickup"
                    j=plan["food_ref"]+1;f=spec.food[j]
                    legal=stock[j]>0 && hypot(f.x-p[1],f.z-p[2])<=1.25 && !any(o->segment_hit(p,(Float64(f.x),Float64(f.z)),o,0.),w.obstacles)
                    if legal;stock[j]-=1;w.inventory[a]+=1;end
                    status=legal ? "picked_up" : "not_found"
                elseif action in ("deposit","retrieve")
                    legal=hypot(p[1]-spec.home[1],p[2]-spec.home[2])<=1.25
                    if legal && action=="deposit"
                        stores[a]+=w.inventory[a];w.inventory[a]=0
                    elseif legal && stores[a]>0
                        stores[a]-=1;w.inventory[a]+=1
                    else
                        status="unavailable"
                    end
                end
            end
            if phase=="night"
                receipt!(learning[a],now;phase=phase,kind=action=="rest" ? "wait" : action,status=action=="rest" ? "waited" : status)
            end
            counts[a][action]=get(counts[a],action,0)+1
            sig=(phase,action,get(plan,"target",nothing),status)
            if get(previous,a,nothing)!=sig
                push!(events,D("us"=>now,"actor"=>a,"phase"=>phase,"action"=>action,"status"=>status,"target"=>get(plan,"target",nothing)))
                previous[a]=sig
            end
        end
        @assert sum(stock)+sum(values(w.inventory))+sum(values(stores))+w.consumed==initial
    end
    terminal=D()
    for a in IDS
        integrate(a,Int(clock.day_us),observe(w,a))
        cycle=learning[a]["sleep"]["cycle"]
        states[a]=consolidate_social(states[a],merge(copy(cycle),D("formation_us"=>Int(clock.day_us))),a)
        terminal[a]=D("position"=>collect(w.positions[a]),"body"=>bodydict(w.bodies[a]),"inventory"=>w.inventory[a],
            "personal_stock"=>stores[a],"sleep"=>learning[a],"social"=>states[a],"aid"=>pressure_snapshot(live[a]),"distance"=>distance[a])
    end
    D("ended_us"=>clock.day_us,"initial_food"=>initial,"ground"=>sum(stock),"consumed"=>w.consumed,
        "counts"=>counts,"events"=>events,"final_agents"=>terminal)
end

input=JSON3.read(read(ARGS[1],String));report=D("scenes"=>D(),"clock"=>input.clock)
@testset "LW day lifecycle" begin
    for spec in input.scenes
        elapsed=@elapsed r=lw_day(spec,input.clock)
        @test r["ended_us"]==17_280_000_000
        @test all(sum(values(r["counts"][a]))==17_280 for a in IDS)
        @test all(r["final_agents"][a]["sleep"]["sleep"]["cycle"]["status"]=="completed" for a in IDS)
        @test r["ground"]+r["consumed"]+sum(r["final_agents"][a]["inventory"]+r["final_agents"][a]["personal_stock"] for a in IDS)==r["initial_food"]
        @test all(isfinite(r["final_agents"][a]["body"]["reserve"]) for a in IDS)
        report["scenes"][spec.name]=D("elapsed_seconds_including_first_compilation"=>elapsed,"result"=>r)
    end
end
open(ARGS[2],"w") do io;JSON3.write(io,report);end
