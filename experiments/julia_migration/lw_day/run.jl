using Test
include(joinpath(@__DIR__,"hazard.jl"))
include(joinpath(@__DIR__,"ground.jl"))
include(joinpath(@__DIR__,"climbing.jl"))
include(joinpath(@__DIR__,"../moving_social/run.jl"))
include(joinpath(@__DIR__,"basic_loop.jl"))
include(joinpath(@__DIR__,"landmark_routes.jl"))
include(joinpath(@__DIR__,"harvest_learning.jl"))
include(joinpath(@__DIR__,"harvest_field.jl"))
include(joinpath(@__DIR__,"harvest_review.jl"))
include(joinpath(@__DIR__,"harvest_relearn.jl"))

# B0 lifecycle scaffold. Current observed relative beacon only; no stored home coordinate in policy.
function home_observation(w,a,yaw,home;visual_obstacles=w.obstacles)
    p=w.positions[a];dx,dz=home[1]-p[1],home[2]-p[2]
    s,c=sincos(deg2rad(yaw[a]));f,r=dx*s+dz*c,dx*c-dz*s
    d=hypot(dx,dz)
    if d<=60 && (f>=0 || d<=1.25) && !any(o->segment_hit(p,(Float64(home[1]),Float64(home[2])),o,0.),visual_obstacles)
        return D("forward"=>f,"right"=>r,"distance"=>d)
    end
    nothing
end

function replenish_food!(stock,food)
    added=0
    for (i,f) in enumerate(food)
        amount=max(0,Int(f.stock)-stock[i]);stock[i]+=amount;added+=amount
    end
    added
end

function lw_day(spec,clock;days=1,basic_loop=false,landmark_routes=false,harvest_sleep=false,model_field=false,model_review=false,model_relearn=false,renewable_food=false,hazard_mode=false,ground_mode="flat",running=false,climbing=false,low_obstacles=false)
    check(days isa Int && 1<=days<=4,"lw_days")
    check(!landmark_routes || basic_loop,"landmark_loop_required")
    check(!model_field || (harvest_sleep && basic_loop),"harvest_field_requires_learning_loop")
    check(!model_review || harvest_sleep,"harvest_review_requires_learning")
    check(!model_relearn || model_review,"harvest_relearn_requires_review")
    w=moving_world(spec);w.capacity=100_000
    high=copy(w.obstacles);low=low_obstacles ? spec.low_obstacles : Any[]
    append!(w.obstacles,[RDLMigrationProbe.Circle(o.x,o.z,o.radius) for o in low])
    climb_stats=Dict(a=>D("attempts"=>0,"performed"=>0,"distance"=>0.,"delta_mismatches"=>0,"records"=>Any[]) for a in IDS)
    safety=Dict(a=>safety_state() for a in IDS)
    check(ground_mode in ("flat","patches","shadow"),"ground_mode")
    patches=ground_mode=="flat" ? Any[] : spec.ground_patches
    resistance_at=p->ground_resistance(p,patches)
    ground_stats=Dict(a=>D("walks"=>0,"high_resistance_walks"=>0,"projection_decisions"=>0,"delta_mismatches"=>0,"records"=>Any[]) for a in IDS)
    yaw=Dict(a=>0. for a in IDS);stock=Int[f.stock for f in spec.food]
    stores=Dict(a=>0 for a in IDS);states=Dict(a=>social_initial() for a in IDS)
    live=Dict(a=>live_aid(a) for a in IDS);results=Dict(a=>D() for a in IDS)
    answered=Dict(a=>Set{String}() for a in IDS);learning=Dict(a=>sleeper(0) for a in IDS)
    counts=Dict(a=>Dict{String,Int}() for a in IDS);events=Any[];previous=Dict{String,Any}()
    distance=Dict(a=>0. for a in IDS)
    run_stats=Dict(a=>D("attempts"=>0,"performed"=>0,"distance"=>0.,"delta_mismatches"=>0,"records"=>Any[]) for a in IDS)
    routes=Dict(a=>route_memory() for a in IDS)
    harvest=Dict(a=>harvest_state(a) for a in IDS);harvest_pending=Dict{String,Any}()
    model_relearn && foreach(a->(harvest[a]["relearn_enabled"]=true),IDS)
    field_stats=Dict(a=>D("applied"=>0,"selection_changes"=>0,"examples"=>Any[],"by_model"=>D()) for a in IDS)
    cargo=Dict(a=>Union{Nothing,String}[] for a in IDS)
    max_radius=Dict(a=>0. for a in IDS)
    loops=Dict(a=>Dict(f=>BasicLoop(a*":"*f;parent=a*":food-security") for f in ("food","home")) for a in IDS)
    pending=Dict{String,Any}();daily=Any[];day_starts=Any[]
    physical()=D(a=>D("position"=>collect(w.positions[a]),"yaw"=>yaw[a],"body"=>bodydict(w.bodies[a]),
        "inventory"=>w.inventory[a],"personal_stock"=>stores[a],"social_count"=>length(states[a]["records"]),
        "social_model"=>deepcopy(states[a]["model"]),"loops"=>D(f=>loop_snapshot(s) for (f,s) in loops[a]),
        "routes"=>landmark_routes ? deepcopy(routes[a]) : nothing,"max_radius_observer_only"=>max_radius[a],
        "harvest"=>harvest_sleep ? deepcopy(harvest[a]) : nothing) for a in IDS)
    for (i,a) in enumerate(IDS)
        w.inventory[a]=spec.initial_inventory[i];w.bodies[a]=Body(10.,0.,spec.reserve[i],0.)
        append!(cargo[a],fill(nothing,w.inventory[a]))
        hasproperty(spec,:initial_personal_stock) && (stores[a]=spec.initial_personal_stock[i])
    end
    initial=sum(stock)+sum(values(w.inventory))+sum(values(stores));bounds=Int.(clock.phase_boundaries_us)
    replenished=0;replenishments=Any[]
    integrate(a,now,obs)=begin
        before=length(states[a]["records"])
        if states[a]["pending"]!==nothing
            states[a]=ingest(states[a],D("agent_id"=>a,"capture_us"=>now,
                "observation_id"=>"ob:$now:$a","social"=>obs),results[a])
        end
        pressure_poll!(live[a],states[a]["records"],before)
    end
    for sec in 0:days*div(clock.day_us,1_000_000)-1
        now=sec*1_000_000;w.seconds=sec
        day=div(now,clock.day_us);local_us=mod(now,clock.day_us)
        if local_us==0
            push!(day_starts,physical())
            if day>0
                learning=Dict(a=>sleeper(day) for a in IDS)
                if renewable_food
                    added=replenish_food!(stock,spec.food);replenished+=added
                    push!(replenishments,D("day"=>day,"us"=>now,"added"=>added))
                end
            end
        end
        phase=local_us<bounds[1] ? "orientation" : local_us<bounds[2] ? "exploration" : local_us<bounds[3] ? "return" : "night"
        obs=Dict(a=>observe(w,a) for a in IDS)
        moves=Dict(a=>movement_observation(w,a,yaw,spec.food,stock;resistance_at=resistance_at,running=running,visual_obstacles=high) for a in IDS)
        homes=Dict(a=>home_observation(w,a,yaw,spec.home;visual_obstacles=high) for a in IDS)
        sections=harvest_sleep ? Dict(a=>harvest_section(moves[a],"ob:$now:$a",now) for a in IDS) : nothing
        if harvest_sleep
            for a in IDS
                harvest_observe!(harvest[a],sections[a])
                if haskey(harvest_pending,a)
                    t=pop!(harvest_pending,a)
                    model_relearn && replacement_result!(harvest[a],a,t.op,t.before,t.status,t.executed,sections[a];
                        pose=t.position==w.positions[a] && t.yaw==yaw[a])
                    harvest_result!(harvest[a],a,t.op,t.before,t.status,t.executed,sections[a])
                    if model_review
                        review_harvest!(harvest[a],a,t.op,t.prediction,t.before,t.status,t.executed,sections[a];
                            pose=t.position==w.positions[a] && t.yaw==yaw[a])
                    end
                end
                prediction=harvest_predict(harvest[a],sections[a])
                harvest[a]["prediction_counts"][prediction["status"]]+=1
                if prediction["status"]=="known"
                    bymodel=get!(harvest[a],"prediction_by_model",D());ref=prediction["model_ref"]
                    bymodel[ref]=get(bymodel,ref,0)+1
                end
                if prediction["status"]=="known" && harvest[a]["first_known"]===nothing
                    harvest[a]["first_known"]=merge(prediction,D("capture_us"=>now))
                end
            end
        end
        landmarks=landmark_routes ? Dict(a=>landmark_fan(spec.obstacles,w.positions[a],yaw[a],"ob:$now:$a") for a in IDS) : nothing
        climbs=climbing ? Dict(a=>[climb_sample(w,a,yaw[a],i,low,high,resistance_at) for i in 0:4] for a in IDS) : nothing
        plans=D()
        for a in IDS
            integrate(a,now,obs[a]);o=obs[a];plan=nothing;home=homes[a]
            at_home=home!==nothing && home["distance"]<=1.25
            if basic_loop && haskey(pending,a)
                t=pop!(pending,a);s=loops[a][t.family]
                target=t.family=="home" ? home : isempty(moves[a]["visible"]) ? nothing : first(moves[a]["visible"])
                same=target!==nothing && (t.family=="home" || t.ref===nothing || target["ref"]==t.ref)
                value=t.question=="landmark_progress" ? t.status=="performed" : t.question=="acquired" ? t.status=="picked_up" : t.question=="home_confirmed" ? at_home && t.status=="performed" : t.question=="target_observed" ? target!==nothing :
                    same ? target["distance"]<t.distance : nothing
                # No move/turn result is credited as acquired food or confirmed home.
                goal=t.family=="home" ? at_home : t.status=="picked_up"
                resolve_method!(s,t.source,t.phase==phase || value===true ? value : nothing,t.phase==phase || goal ? goal : nothing)
            end
            messages=[m for m in reverse(o["messages"]) if !(m["id"] in answered[a]) && m["kind"] in ("request","warn","reach")]
            if hazard_mode
                plan=safety_plan!(safety[a],hazard_observation(w,a,yaw, spec.hazards,sec;visual_obstacles=high),moves[a];running=running)
            end
            if plan!==nothing
                # Safety has authority before social, food and night priorities.
            elseif !isempty(messages)
                m=first(messages);act,t,r=response(merge(copy(o),D("messages"=>[m])),a!="npc_b")
                plan=D("action"=>act,"target"=>t,"reply_to"=>r);push!(answered[a],m["id"])
            elseif w.bodies[a].reserve<80 && w.inventory[a]>0
                plan=D("action"=>"eat")
            elseif at_home && w.bodies[a].reserve<80 && stores[a]>0
                plan=D("action"=>"retrieve")
            elseif phase=="night" && local_us>=clock.quiet_night_us
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
                elseif basic_loop
                    family=returning ? "home" : "food"
                    visible=moves[a]["visible"];target=returning ? home : isempty(visible) ? nothing : first(visible)
                    if !returning && target!==nothing && target["distance"]<=1.25
                        plan=D("action"=>"pickup","food_ref"=>target["ref"])
                    else
                        s=loops[a][family];source="op:$now:$a"
                        candidates=search_candidates(moves[a],target,s)
                        climbing && append!(candidates,climb_candidates(climbs[a],moves[a],target,s))
                        if landmark_routes
                            if routes[a]["day"]!=day
                                empty!(routes[a]["cursors"]);routes[a]["day"]=day
                            end
                            # Direct currently observed goal wins over remembered detours.
                            if target===nothing
                                append!(candidates,landmark_candidates(moves[a],landmarks[a],routes[a],family,landmarks[a]["source"]))
                            end
                        end
                        if ground_mode=="patches"
                            candidates=ground_candidates(candidates,moves[a],w.inventory[a])
                            ground_stats[a]["projection_decisions"]+=1
                        end
                        counterfactual=nothing;field_trace=nothing
                        if model_field && family=="food"
                            projected,field_trace=harvest_field(candidates,moves[a],harvest[a],a,now;enabled=true)
                            if field_trace["applied"]
                                counterfactual=choose_method!(deepcopy(s),candidates,source)
                                candidates=projected;field_stats[a]["applied"]+=1
                                m=get!(field_stats[a]["by_model"],field_trace["model_ref"],D("applied"=>0,"selection_changes"=>0))
                                m["applied"]+=1
                            end
                        end
                        plan=choose_method!(s,candidates,source)
                        if counterfactual!==nothing && counterfactual["method"]!=plan["method"]
                            field_stats[a]["selection_changes"]+=1
                            field_stats[a]["by_model"][field_trace["model_ref"]]["selection_changes"]+=1
                            if length(field_stats[a]["examples"])<8
                                push!(field_stats[a]["examples"],D("source"=>"ob:$now:$a","without"=>counterfactual["method"],
                                    "with"=>plan["method"],"field"=>field_trace))
                            end
                        end
                        landmark_routes && get(plan,"route",nothing)!==nothing && (routes[a]["selections"]+=1)
                        pending[a]=(family=family,source=source,phase=phase,question=plan["question"],
                            distance=target===nothing ? nothing : target["distance"],
                            ref=target===nothing || returning ? nothing : target["ref"],status="unexecuted")
                    end
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
            if basic_loop && !haskey(pending,a) && (plan["action"] in ("pickup","deposit") || (at_home && plan["action"]=="rest" && loops[a]["home"].H>0))
                family=plan["action"]=="pickup" ? "food" : "home"
                question=family=="food" ? "acquired" : "home_confirmed"
                source="op:$now:$a"
                plan=choose_method!(loops[a][family],[merge(plan,D("method"=>"work","priority"=>5.,"question"=>question))],source)
                pending[a]=(family=family,source=source,phase=phase,question=question,distance=nothing,ref=nothing,status="unexecuted")
            end
            plans[a]=plan
        end
        w.seconds=sec+1
        for a in IDS
            plan=plans[a];action=plan["action"];op="op:$now:$a";p=w.positions[a];status="performed"
            frozen_prediction=harvest_sleep && action=="pickup" ? harvest_predict(harvest[a],sections[a]) : nothing
            leg=phase in ("return","night") || w.inventory[a]>=6 ? "home" : "food"
            delivered=String[]
            # Exactly one body update per simulated second, including non-movement actions.
            if action=="climb"
                actual=climb_sample(w,a,yaw[a],plan["direction"],low,high,resistance_at)
                expected=climbs[a][plan["direction"]+1]
                yaw[a]=mod(yaw[a]+ANGLES[plan["direction"]+1]+180,360)-180
                s,c=sincos(deg2rad(yaw[a]))
                w.bodies[a],status,d,delta=step(w.bodies[a],"climb",w.inventory[a],actual["resistance"],actual["clear"])
                w.positions[a]=(p[1]+s*d,p[2]+c*d);distance[a]+=d
                g=climb_stats[a];g["attempts"]+=1;g["distance"]+=d
                status=="performed" && (g["performed"]+=1)
                comparable=expected["load"]==w.inventory[a] && expected["clear"]==actual["clear"]
                comparable && expected["expected_delta"]!=delta && (g["delta_mismatches"]+=1)
                push!(g["records"],D("source"=>op,"status"=>status,"height"=>actual["height"],"capacity"=>actual["capacity"],
                    "load"=>w.inventory[a],"resistance"=>actual["resistance"],"distance"=>d,"expected_delta"=>expected["expected_delta"],"actual_delta"=>delta))
                length(g["records"])>32 && popfirst!(g["records"])
            elseif action in ("walk","run")
                yaw[a]=mod(yaw[a]+ANGLES[plan["direction"]+1]+180,360)-180
                s,c=sincos(deg2rad(yaw[a]))
                span=action=="run" ? 1.5*(1-w.bodies[a].damage) : .5
                q=(p[1]+s*span,p[2]+c*span)
                clear=!any(o->segment_hit(p,q,o,.2),w.obstacles)
                sample_span=(action=="run" ? 1.5 : .5)*(1-w.bodies[a].damage)
                midpoint=(p[1]+s*sample_span/2,p[2]+c*sample_span/2)
                resistance=resistance_at(midpoint)
                expected=(action=="run" ? moves[a]["run_rows"] : moves[a]["energy"]["rows"])[plan["direction"]+1]
                w.bodies[a],status,d,delta=step(w.bodies[a],action,w.inventory[a],resistance,clear)
                if action=="run"
                    g=run_stats[a];g["attempts"]+=1;g["distance"]+=d
                    status=="performed" && (g["performed"]+=1)
                    comparable=expected["load"]==w.inventory[a] && expected["clear"]==clear
                    comparable && expected["expected_delta"]!=delta && (g["delta_mismatches"]+=1)
                    push!(g["records"],D("source"=>op,"status"=>status,"load"=>w.inventory[a],"resistance"=>resistance,
                        "distance"=>d,"expected_delta"=>deepcopy(expected["expected_delta"]),"actual_delta"=>delta,"comparable"=>comparable))
                    length(g["records"])>32 && popfirst!(g["records"])
                elseif ground_mode!="flat"
                    g=ground_stats[a];g["walks"]+=1
                    resistance>1.5 && (g["high_resistance_walks"]+=1)
                    # The observed clearance horizon is 1 unit, execution is at most .5.
                    # Compare matching clearance only; distinguish that geometric boundary.
                    comparable=expected["clear"]==clear && expected["load"]==w.inventory[a]
                    match=comparable && expected["expected_delta"]==delta && expected["resistance"]==resistance
                    comparable && !match && (g["delta_mismatches"]+=1)
                    push!(g["records"],D("source"=>op,"load"=>w.inventory[a],"resistance"=>resistance,
                        "status"=>status,"expected_delta"=>deepcopy(expected["expected_delta"]),"actual_delta"=>delta,
                        "comparable"=>comparable,"matches"=>match))
                    length(g["records"])>32 && popfirst!(g["records"])
                end
                w.positions[a]=(p[1]+s*d,p[2]+c*d);distance[a]+=d
            elseif action in ("eat","request","give","refuse","warn","withdraw","wait")
                r=communicate!(w,a,op,action,get(plan,"target",nothing),get(plan,"reply_to",nothing));status=r["status"]
                if status=="ate"
                    popfirst!(cargo[a])
                elseif status=="transferred"
                    push!(cargo[plan["target"]],popfirst!(cargo[a]))
                end
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
                    if legal;stock[j]-=1;w.inventory[a]+=1;push!(cargo[a],op);end
                    status=legal ? "picked_up" : "not_found"
                elseif action in ("deposit","retrieve")
                    legal=hypot(p[1]-spec.home[1],p[2]-spec.home[2])<=1.25
                    if legal && action=="deposit"
                        delivered=String[id for id in cargo[a] if id!==nothing];empty!(cargo[a])
                        stores[a]+=w.inventory[a];w.inventory[a]=0
                    elseif legal && stores[a]>0
                        stores[a]-=1;w.inventory[a]+=1
                        push!(cargo[a],nothing)
                    else
                        status="unavailable"
                    end
                end
            end
            @assert all(length(cargo[x])==w.inventory[x] for x in IDS)
            max_radius[a]=max(max_radius[a],hypot(w.positions[a][1]-spec.home[1],w.positions[a][2]-spec.home[2]))
            if landmark_routes && !get(plan,"safety",false)
                near=homes[a]!==nothing && homes[a]["distance"]<=1.25
                route_result!(routes[a],landmarks[a],op,action,status,leg,near,get(plan,"route",nothing);delivered=delivered)
            end
            if phase=="night"
                cycle=learning[a]["sleep"]["cycle"]
                harvest_sleep && action=="rest" && freeze_harvest!(harvest[a],cycle,now)
                callback=harvest_sleep ? ((c,t)->consolidate_harvest!(harvest[a],c,t)) : nothing
                receipt!(learning[a],now;phase=phase,kind=action=="rest" ? "wait" : action,status=action=="rest" ? "waited" : status,on_complete=callback)
            end
            if harvest_sleep && action=="pickup"
                harvest_pending[a]=(op=op,before=deepcopy(sections[a]),status=status,executed=now+1_000_000,
                    prediction=frozen_prediction,position=p,yaw=yaw[a])
            end
            if haskey(pending,a)
                pending[a]=merge(pending[a],(status=status,))
            end
            counts[a][action]=get(counts[a],action,0)+1
            sig=(phase,action,get(plan,"target",nothing),status,get(plan,"method",nothing),get(plan,"direction",nothing),get(plan,"selection_mode",nothing))
            if get(previous,a,nothing)!=sig
                push!(events,D("us"=>now,"actor"=>a,"phase"=>phase,"action"=>action,"status"=>status,"target"=>get(plan,"target",nothing),
                    "method"=>get(plan,"method",nothing),"direction"=>get(plan,"direction",nothing),"selection_mode"=>get(plan,"selection_mode",nothing),
                    "route"=>get(plan,"route",nothing),"landmark_color"=>get(plan,"landmark_color",nothing)))
                previous[a]=sig
            end
        end
        @assert sum(stock)+sum(values(w.inventory))+sum(values(stores))+w.consumed==initial+replenished
        if mod(now+1_000_000,clock.day_us)==0
            for a in IDS
                integrate(a,now+1_000_000,observe(w,a))
                cycle=learning[a]["sleep"]["cycle"]
                states[a]=consolidate_social(states[a],merge(copy(cycle),D("formation_us"=>now+1_000_000)),a)
            end
            push!(daily,D("physical"=>physical(),"sleep"=>deepcopy(learning),"counts"=>deepcopy(counts),
                "ground"=>sum(stock),"consumed"=>w.consumed,"replenished_food"=>replenished))
        end
    end
    terminal=D()
    for a in IDS
        integrate(a,Int(days*clock.day_us),observe(w,a))
        cycle=learning[a]["sleep"]["cycle"]
        states[a]=consolidate_social(states[a],merge(copy(cycle),D("formation_us"=>Int(days*clock.day_us))),a)
        terminal[a]=D("position"=>collect(w.positions[a]),"body"=>bodydict(w.bodies[a]),"inventory"=>w.inventory[a],
            "personal_stock"=>stores[a],"sleep"=>learning[a],"social"=>states[a],"aid"=>pressure_snapshot(live[a]),"distance"=>distance[a],
            "routes"=>landmark_routes ? deepcopy(routes[a]) : nothing,"max_radius_observer_only"=>max_radius[a],
            "harvest"=>harvest_sleep ? deepcopy(harvest[a]) : nothing,"model_field"=>field_stats[a])
    end
    D("ended_us"=>days*clock.day_us,"initial_food"=>initial,"ground"=>sum(stock),"consumed"=>w.consumed,
        "replenished_food"=>replenished,"replenishments"=>replenishments,
        "climbing"=>climbing ? climb_stats : nothing,"running"=>running ? run_stats : nothing,"ground_effects"=>ground_mode=="flat" ? nothing : ground_stats,"safety"=>hazard_mode ? deepcopy(safety) : nothing,"counts"=>counts,"events"=>events,"final_agents"=>terminal,"daily"=>daily,"day_starts"=>day_starts)
end

if abspath(PROGRAM_FILE)==@__FILE__
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
end
