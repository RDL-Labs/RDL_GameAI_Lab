using JSON3, Serialization, Test
include("../../src/lw/LW.jl")
const G=LW.LWGrazing;const H=G.H;const P=G.P
include("../../src/lw/configured_paths/predator_animal_trial.jl")
include("../../src/lw/configured_paths/predator_physiology.jl")
include("../../src/lw/configured_paths/predator_marking.jl")
include("../../src/lw/configured_paths/prey_scent.jl")
include("../../src/ecology/lw_grazing/predator_cognition.jl")
include("../../src/lw/configured_paths/predator_local_hunt.jl")
function animal_trial_world(;adult_rabbits=30,boundary_gradient=true)
    input=JSON3.read(read(joinpath(@__DIR__,"predator_3d_spec.json"),String))
    wildlife=merge((;pairs(input.scene.wildlife)...),(predator_count=0,count=adult_rabbits,boundary_gradient=boundary_gradient))
    scene=merge((;pairs(input.scene)...),(positions=Tuple{Float64,Float64}[],wildlife=wildlife))
    s=G.build(scene,input.clock)
    cells=findall(s.world.walkable)
    centers=[H.center(s.world,cells[argmin([hypot(H.center(s.world,k)[1]-x,H.center(s.world,k)[2]-6) for k in cells])]) for x in (-8.,8.)]
    predators=[configured_trial_predator(s,centers[i],20261106+i) for i in 1:2]
    s,predators
end
function animal_trial_step!(s,predators,t;scents=nothing,minds=nothing,prey_nutrition=1.,prey_scents=nothing,motion_speed=false,local_hunts=nothing,physiology=nothing)
    scents!==nothing && configured_scent_tick!(scents,predators,t)
    for (i,p) in enumerate(predators)
        if minds===nothing
            configured_trial_plan!(s,p,predators,t;territory_evidence=scents===nothing ? nothing : scents.observed[i])
            scents!==nothing && configured_scent_choice!(scents,p,i,t)
        else
            attention=prey_scents===nothing ? nothing : prey_scents.active_target[i]
            physical=physiology===nothing ? nothing : physiology[i]
            planner=local_hunts===nothing ? nothing : (proxy,observations,tick)->configured_local_hunt_plan!(local_hunts[i],proxy,observations,tick;physiology=physical)
            predator_mind_plan!(s,p,predators,minds[i],t;scents,index=i,search_attention=attention,local_planner=planner,physiology=physical)
        end
    end
    if prey_scents!==nothing
        configured_prey_scent_tick!(prey_scents,s,predators,t)
        for (i,p) in enumerate(predators);configured_prey_scent_steer!(prey_scents,p,i,t);end
    end
    G.prepare!(s,Tuple{Float64,Float64}[],t;additional_predators=[p.visual for p in predators],
        additional_predator_alive=[p.alive for p in predators],motion_speed)
    G.advance!(s,t)
    # Alternate contact resolution order to avoid permanent first-predator privilege.
    for i in (iseven(t) ? eachindex(predators) : reverse(eachindex(predators)))
        search_speed=prey_scents!==nothing && prey_scents.active_target[i]!==nothing ? PREY_SCENT_CAUTION.speed : nothing
        attack_speed=local_hunts===nothing ? 1. : local_hunts[i].attack_speed
        movement_speed=local_hunts===nothing ? nothing : local_hunts[i].movement_speed
        if local_hunts!==nothing && local_hunts[i].wait_trial!==nothing && isnan(local_hunts[i].wait_spent)
            local_hunts[i].wait_spent=predators[i].spent
        end
        configured_trial_advance!(s,predators[i],t;physiology=physiology===nothing ? nothing : physiology[i],prey_nutrition,search_speed,attack_speed,movement_speed,probabilistic_capture=local_hunts!==nothing && local_hunts[i].probabilistic_capture,scent_speed=minds!==nothing ? PREDATOR_COGNITION.move_speed : scents===nothing ? 0. : PREDATOR_MARKING.speed)
        local_hunts!==nothing && configured_local_hunt_finish!(local_hunts[i],predators[i])
    end
end
function animal_trial_report(s,predators;scents=nothing,minds=nothing)
    captures=sum(p.visual.body.captures for p in predators)
    report=(ambient_vision=G.AmbientVision.RULE,rabbits=G.snapshot(s;additional_predation_deaths=captures),predators=trial_predator_report.(predators))
    scents!==nothing && (report=merge(report,(scent=scent_report(scents),)))
    minds===nothing ? report : merge(report,(cognition=predator_mind_report.(minds),))
end
function main()
    checks_only="--checks-only" in ARGS
    marking="--marking" in ARGS
    cognition="--cognition" in ARGS
    population_option=filter(arg->startswith(arg,"--adult-rabbits="),ARGS)
    length(population_option)<=1 || error("duplicate adult rabbit count")
    adult_rabbits=isempty(population_option) ? 30 : parse(Int,split(only(population_option),'=';limit=2)[2])
    1<=adult_rabbits<=10000 || error("adult rabbit count must be 1..10000")
    nutrition_option=filter(arg->startswith(arg,"--prey-nutrition="),ARGS)
    length(nutrition_option)<=1 || error("duplicate prey nutrition")
    prey_nutrition=isempty(nutrition_option) ? 1. : parse(Float64,split(only(nutrition_option),'=';limit=2)[2])
    isfinite(prey_nutrition) && prey_nutrition>0 || error("prey nutrition must be finite and positive")
    days=checks_only || length(ARGS)<2 ? 3 : parse(Int,ARGS[2])
    days>0 || error("days must be positive")
    out=checks_only ? joinpath(mktempdir(),"checks") : length(ARGS)>0 ? ARGS[1] : "outputs/animals-only-3d"
    ispath(out) && error("output already exists")
    mkpath(out)
    conditions=(days=days,stop_on_predator_extinction=true,humans=0,adult_rabbits=adult_rabbits,initial_young=5,predators=2,
        boundary_gradient=true,boundary_rule=H.WILDLIFE_BOUNDARY,rule=PREDATOR_ANIMAL_TRIAL,prey_nutrition=prey_nutrition,adult_food_equivalent=PREDATOR_ANIMAL_TRIAL.adult_food*prey_nutrition,
        marking=marking,marking_rule=marking ? PREDATOR_MARKING : nothing,
        cognition=cognition,cognition_rule=cognition ? PREDATOR_COGNITION : nothing,
        fixed=cognition ? "shared human selection; provisional candidate priors, exact self-position memory, episode horizons, zero rest benefit, warning cap and instantaneous meals; no fatigue or predator breeding" :
            "territory centers when marking OFF; local scent identity/intervals/choices when ON; visual warning/retreat, instantaneous meals; no predator breeding or combat")
    write(joinpath(out,"conditions.json"),JSON3.write(conditions));println(JSON3.write(conditions))
    s,predators=animal_trial_world()
    @testset "animal trial boundaries" begin
        @test isempty(s.previous_humans) && s.predator===nothing
        configured_trial_plan!(s,predators[1],[predators[1]],0)
        @test predators[1].mode==:rest
        predators[1].food=100.
        configured_trial_plan!(s,predators[1],[predators[1]],0)
        @test predators[1].mode==:hunt
        s,predators=animal_trial_world()
        empty!(s.world.obstacles);s.world.traits.density.=0.
        p,q=predators
        p.visual.body.x=-10.;p.visual.body.z=6.;p.visual.gaze=0.;p.center=(-10.,6.)
        q.visual.body.x=-8.;q.visual.body.z=6.;q.visual.gaze=pi;q.center=(30.,6.)
        configured_trial_plan!(s,p,predators,0);configured_trial_plan!(s,q,predators,0)
        @test p.mode==:warn # A fed resident still defends its center.
        @test q.mode==:retreat
        p.mode=:hunt;p.visual.body.state=P.ATTACK;p.visual.body.timer=1
        s.animals.x.=-20.;s.animals.z.=20.;s.animals.x[1]=-9.5;s.animals.z[1]=6.
        s.animals.state[1]=H.REST
        for t in 0:100
            p.visual.body.captures>0 && break
            p.visual.body.x=-10.;p.visual.body.z=6.;p.visual.body.heading=0.
            p.visual.body.state=P.ATTACK;p.visual.body.timer=1;p.visual.body.attacks+=1
            configured_trial_advance!(s,p,t)
        end
        @test p.visual.body.captures==1 && p.eaten==900.
        @test p.visual.body.timer==0
        @test trial_predator_report(p).food>1700.
        s,predators=animal_trial_world()
        for t in 0:9999;animal_trial_step!(s,predators,t);end
        io=IOBuffer();serialize(io,(s,predators));seekstart(io);copy_s,copy_p=deserialize(io)
        for t in 10000:19999
            animal_trial_step!(s,predators,t);animal_trial_step!(copy_s,copy_p,t)
        end
        @test animal_trial_report(s,predators)==animal_trial_report(copy_s,copy_p)
    end
    @testset "bounded warning and reentry" begin
        s,predators=animal_trial_world();p,q=predators
        empty!(s.world.obstacles);s.world.traits.density.=0.
        p.visual.body.x=-10.;p.visual.body.z=6.;p.visual.gaze=0.;p.center=(-10.,6.)
        q.visual.body.x=-8.;q.visual.body.z=6.
        warnings=0
        for t in 0:59
            configured_trial_plan!(s,p,predators,t)
            warnings+=p.mode==:warn
        end
        @test warnings==60
        configured_trial_plan!(s,p,predators,60)
        @test p.mode==:rest && p.warning_blocked_until==660 && p.warning_timeouts==1
        p.food=100.
        configured_trial_plan!(s,p,predators,61)
        @test p.mode==:hunt
        io=IOBuffer();serialize(io,p);seekstart(io);restored=deserialize(io)
        @test restored.warning_blocked_until==660 && restored.warning_started==-1
        p.food=900.;p.visual.body.state=P.REST;p.visual.gaze=0.
        configured_trial_plan!(s,p,predators,659)
        @test p.mode==:rest
        p.visual.gaze=0.
        configured_trial_plan!(s,p,predators,660)
        @test p.mode==:warn && p.warning_started==660
        configured_trial_plan!(s,p,[p],680)
        p.visual.gaze=0.
        configured_trial_plan!(s,p,predators,719)
        @test p.mode==:warn && p.warning_started==660
        configured_trial_plan!(s,p,predators,720)
        @test p.mode==:rest && p.warning_timeouts==2
    end
    @testset "local scent, memory and continuation" begin
        s,predators=animal_trial_world();p,q=predators;scents=PredatorScentWorld(2)
        p.visual.body.x=-10.;p.visual.body.z=6.;q.visual.body.x=30.;q.visual.body.z=6.
        configured_scent_deposit!(scents,p,1,0);configured_scent_observe!(scents,p,1,0)
        @test scents.observed[1].own>0 && scents.observed[1].foreign==0
        configured_scent_deposit!(scents,q,2,0);configured_scent_observe!(scents,p,1,0)
        @test all(k->k[3]==1,keys(scents.memory[1])) # Far marks are not known.
        q.visual.body.x=-9.;configured_scent_observe!(scents,q,2,0)
        @test scents.observed[2].foreign>0
        configured_scent_deposit!(scents,q,2,0)
        @test any(k->k[3]==1,keys(scents.marks)) && any(k->k[3]==2,keys(scents.marks))
        old_memory=deepcopy(scents.memory[1]);configured_scent_deposit!(scents,p,1,1)
        @test scents.memory[1]==old_memory
        @test scent_strength(first(values(scents.marks)),4*17280)==0
        p.visual.body.x=-18.;configured_scent_observe!(scents,p,1,30)
        p.mode=:rest;p.visual.body.state=P.REST
        configured_scent_choice!(scents,p,1,30)
        @test p.mode==:scent_return
        q.mode=:rest;q.visual.body.state=P.REST
        configured_scent_choice!(scents,q,2,0)
        @test q.mode==:scent_avoid
        s,predators=animal_trial_world();scents=PredatorScentWorld(2)
        for t in 0:9999;animal_trial_step!(s,predators,t;scents);end
        io=IOBuffer();serialize(io,(s,predators,scents));seekstart(io);copy_s,copy_p,copy_scents=deserialize(io)
        for t in 10000:11999
            animal_trial_step!(s,predators,t;scents)
            animal_trial_step!(copy_s,copy_p,t;scents=copy_scents)
        end
        @test animal_trial_report(s,predators;scents)==animal_trial_report(copy_s,copy_p;scents=copy_scents)
        @test scents.marks==copy_scents.marks && scents.memory==copy_scents.memory
    end
    @testset "shared human cognition adapter" begin
        s,predators=animal_trial_world();minds=[PredatorMind(i) for i in 1:2]
        @test minds[1].loop isa LW.BasicLoop
        @test isempty(minds[1].places)
        m=minds[1];p=predators[1]
        c=LW.D("method"=>"visit:fixture","action"=>:visit_food,"question"=>"local_arrival",
            "priority"=>1.,"forecast"=>10.,"expected"=>.5,"target"=>(p.visual.body.x,p.visual.body.z),"site"=>"fixture")
        m.selected=LW.choose_method!(m.loop,[c],1);m.loop.H=3.
        m.trial=LW.action_trial(1,c["method"],c["question"],10.)
        m.start_spent=p.spent;m.start_eaten=p.eaten;m.start_capture=p.visual.body.captures
        predator_mind_close!(m,p,(actor=nothing,distance=Inf),1)
        @test m.loop.H==3. && isempty(m.places) # Arrival is not food or parent success.
        s,predators=animal_trial_world();minds=[PredatorMind(i) for i in 1:2]
        for t in 0:1999;animal_trial_step!(s,predators,t;minds);end
        @test all(m->m.completed>0 && !isempty(m.loop.methods),minds)
        @test all(m->all(r->isfinite(r["H"]),m.records),minds)
        io=IOBuffer();serialize(io,(s,predators,minds));seekstart(io);copy_s,copy_p,copy_m=deserialize(io)
        for t in 2000:2999
            animal_trial_step!(s,predators,t;minds)
            animal_trial_step!(copy_s,copy_p,t;minds=copy_m)
        end
        @test animal_trial_report(s,predators;minds)==animal_trial_report(copy_s,copy_p;minds=copy_m)
    end
    @testset "prey nutrition and capacity" begin
        s,predators=animal_trial_world();p=predators[1]
        empty!(s.world.obstacles);s.world.traits.density.=0.
        s.animals.x.=-20.;s.animals.z.=20.;s.animals.x[1]=-9.5;s.animals.z[1]=6.;s.animals.state[1]=H.REST
        for t in 0:100
            p.visual.body.captures>0 && break
            p.mode=:hunt;p.visual.body.x=-10.;p.visual.body.z=6.;p.visual.body.heading=0.
            p.visual.body.state=P.ATTACK;p.visual.body.timer=1;p.visual.body.attacks+=1
            configured_trial_advance!(s,p,t;prey_nutrition=1.5)
        end
        @test p.visual.body.captures==1
        @test isapprox(p.eaten+p.discarded,1350.)
        @test p.food<=PREDATOR_ANIMAL_TRIAL.capacity && p.discarded>0
        @test trial_predator_report(p).alive
    end
    checks_only && return
    frozen=joinpath(out,"source")
    mkpath(joinpath(frozen,"experiments","lw_wildlife"))
    cp(joinpath(@__DIR__,"../../src"),joinpath(frozen,"src"))
    for name in ("animals_only.jl","predator_3d_spec.json")
        cp(joinpath(@__DIR__,name),joinpath(frozen,"experiments","lw_wildlife",name))
    end
    cp(joinpath(@__DIR__,"../../Project.toml"),joinpath(frozen,"Project.toml"))
    s,predators=animal_trial_world(;adult_rabbits);daily=Any[];scents=marking ? PredatorScentWorld(2) : nothing
    @assert length(s.alive)==adult_rabbits+conditions.initial_young
    minds=cognition ? [PredatorMind(i) for i in 1:2] : nothing
    stop_reason="duration_reached"
    elapsed=@elapsed for t in 0:days*17280-1
        animal_trial_step!(s,predators,t;scents,minds,prey_nutrition)
        extinct=all(p->!p.alive,predators)
        if extinct
            stop_reason="predator_extinction"
            # Final action killed the last predator: close its outstanding trial
            # at this boundary without advancing rabbits/world an extra tick.
            if minds!==nothing
                for (i,p) in enumerate(predators)
                    minds[i].trial===nothing || predator_mind_plan!(s,p,predators,minds[i],t+1;scents,index=i)
                end
            end
        end
        if (t+1)%17280==0
            day=div(t+1,17280);report=animal_trial_report(s,predators;scents,minds)
            push!(daily,(day=day,report=report))
            serialize(joinpath(out,"day-$day.jls"),minds!==nothing ? (s,predators,scents,minds) : scents===nothing ? (s,predators) : (s,predators,scents))
            println(JSON3.write((day=day,rabbits=report.rabbits.alive,predators=report.predators)))
        end
        extinct && break
    end
    final_state=animal_trial_report(s,predators;scents,minds)
    serialize(joinpath(out,"final.jls"),minds!==nothing ? (s,predators,scents,minds) : scents===nothing ? (s,predators) : (s,predators,scents))
    completion=(stop_reason=stop_reason,executed_ticks=s.ticks,completed_days=div(s.ticks,17280),
        stopped_in_day=cld(s.ticks,17280),elapsed_simulation_days=s.ticks/17280)
    write(joinpath(out,"result.json"),JSON3.write((conditions=conditions,elapsed_seconds=elapsed,
        completion=completion,daily=daily,final_state=final_state)))
    println("COMPLETE seconds=",elapsed," ",JSON3.write(completion))
end
abspath(PROGRAM_FILE)==(@__FILE__) && main()
