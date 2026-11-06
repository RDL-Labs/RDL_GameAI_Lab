using Statistics
include("animals_only.jl")
function scent_run(enabled;days=3)
    s,predators=animal_trial_world(;adult_rabbits=95)
    scents=PredatorScentWorld(2);minds=[PredatorMind(i) for i in 1:2]
    prey_scents=enabled ? PreyScentWorld(2) : nothing;daily=Any[]
    timing=@timed for t in 0:days*17280-1
        animal_trial_step!(s,predators,t;scents,minds,prey_nutrition=1.5,prey_scents)
        if all(p->!p.alive,predators)
            for (i,p) in enumerate(predators)
                minds[i].trial===nothing || predator_mind_plan!(s,p,predators,minds[i],t+1;scents,index=i)
            end
            break
        end
        (t+1)%17280==0 && push!(daily,animal_trial_report(s,predators;scents,minds))
    end
    final_state=animal_trial_report(s,predators;scents,minds)
    (enabled=enabled,seconds=timing.time,bytes=timing.bytes,gc_seconds=timing.gctime,
        ticks=s.ticks,daily=daily,final_state=final_state,scent=prey_scent_report(prey_scents))
end
function scent_checks()
    @testset "local prey trace boundaries" begin
        s,predators=animal_trial_world();p=predators[1];b=p.visual.body
        s.alive.=false;p.mode=:hunt;b.state=P.SEARCH;b.x=0.;b.z=0.
        scent=PreyScentWorld(2);scent.marks[(10,10)]=(strength=4.,tick=0)
        configured_prey_scent_tick!(scent,s,predators,0)
        @test scent.observed[1]===nothing # Distant world information is not observed.
        scent.marks[(0,0)]=(strength=4.,tick=0)
        configured_prey_scent_tick!(scent,s,predators,30)
        @test scent.observed[1].target==(2.,2.) # Cell center, not actual prey location/identity.
        observation=scent.observed[1];scent.marks[(0,0)]=(strength=0.,tick=30)
        @test scent.observed[1]==observation # No live reference into the world.
        b.heading=0.;configured_prey_scent_steer!(scent,p,1,30)
        @test b.heading≈pi/4
        b.state=P.ATTACK;b.heading=0.;configured_prey_scent_steer!(scent,p,1,30)
        @test b.heading==0.
        b.state=P.SEARCH;configured_prey_scent_steer!(scent,p,1,60)
        @test b.heading==0. # Expired observation cannot steer.
        @test prey_scent_strength((strength=4.,tick=0),PREY_SCENT.lifetime)==0.
        s.alive[1]=true;s.animals.x[1]=0.;s.animals.z[1]=0.
        configured_prey_scent_tick!(scent,s,predators,60)
        @test scent.deposits==1
        io=IOBuffer();serialize(io,scent);seekstart(io)
        @test prey_scent_report(deserialize(io))==prey_scent_report(scent)
    end
end
function scent_compare_main()
    out=abspath(ARGS[1]);ispath(out) && error("output exists");mkpath(out)
    conditions=(days=3,adult_rabbits=95,initial_young=5,predators=2,humans=0,
        nutrition=1.5,marking=true,cognition=true,prey_scent=PREY_SCENT,
        fixed="mixed ground trace; fixed nearby sniff and search-heading aid; no wind/diffusion; no human connection",
        measurement="warm both modes for one day; sequential OFF ON ON OFF; no file IO inside timing")
    println(JSON3.write(conditions));write(joinpath(out,"conditions.json"),JSON3.write(conditions))
    frozen=joinpath(out,"source");mkpath(joinpath(frozen,"experiments/lw_wildlife"))
    cp(joinpath(@__DIR__,"../../src"),joinpath(frozen,"src"))
    for name in ("animals_only.jl","prey_scent_compare.jl","predator_3d_spec.json")
        cp(joinpath(@__DIR__,name),joinpath(frozen,"experiments/lw_wildlife",name))
    end
    cp(joinpath(@__DIR__,"../../Project.toml"),joinpath(frozen,"Project.toml"))
    scent_checks()
    scent_run(false;days=1);scent_run(true;days=1)
    runs=Any[]
    for enabled in (false,true,true,false)
        GC.gc();record=scent_run(enabled);push!(runs,record)
        println(JSON3.write((enabled=enabled,seconds=record.seconds,captures=[p.captures for p in record.final_state.predators],scent=record.scent)))
    end
    @test runs[1].final_state==runs[4].final_state
    @test runs[2].final_state==runs[3].final_state
    @test runs[2].scent==runs[3].scent
    # Historical OFF branch must retain its saved daily trajectory.
    reference=joinpath(@__DIR__,"../../outputs/predator-100rabbits-nutrition15-v2-20261106/result.json")
    if isfile(reference)
        expected=JSON3.read(read(reference,String))
        for day in 1:3
            @test JSON3.read(JSON3.write(runs[1].daily[day]))==expected.daily[day].report
        end
    end
    write(joinpath(out,"result.json"),JSON3.write((conditions=conditions,runs=runs)))
end
abspath(PROGRAM_FILE)==(@__FILE__) && scent_compare_main()
