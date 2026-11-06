include("prey_scent_compare.jl")
function caution_checks()
    scent_checks()
    @testset "cautious scent search" begin
        s,ps=animal_trial_world();p=ps[1];b=p.visual.body
        p.mode=:hunt;b.state=P.SEARCH;b.x=0.;b.z=0.
        scent=PreyScentWorld(2;cautious=true)
        scent.observed[1]=(target=(2.,2.),signal=1.,tick=0)
        configured_prey_scent_steer!(scent,p,1,0)
        @test scent.active_target[1]==(2.,2.)
        b.state=P.CHASE;configured_prey_scent_steer!(scent,p,1,1)
        @test scent.active_target[1]===nothing && scent.unconfirmed[1]==0
        b.state=P.SEARCH
        for t in 1:PREY_SCENT_CAUTION.unconfirmed_ticks
            scent.observed[1]=(target=(2.,2.),signal=1.,tick=t)
            configured_prey_scent_steer!(scent,p,1,t)
        end
        @test scent.rejected==1 && scent.active_target[1]===nothing
        configured_prey_scent_steer!(scent,p,1,121)
        @test scent.active_target[1]===nothing
        b.x=-10.;b.z=6.;b.heading=0.;empty!(s.world.obstacles)
        prior_distance=b.distance
        configured_trial_advance!(s,p,0;search_speed=PREY_SCENT_CAUTION.speed)
        @test b.distance-prior_distance≈PREY_SCENT_CAUTION.speed
        scent.observed[1]=(target=(6.,2.),signal=.1,tick=122)
        configured_prey_scent_steer!(scent,p,1,122)
        @test scent.active_target[1]===nothing
    end
end
function caution_main()
    out=abspath(ARGS[1]);ispath(out) && error("output exists");mkpath(out)
    conditions=(days=3,adult_rabbits=95,young=5,predators=2,humans=0,nutrition=1.5,
        marking=true,cognition=true,prey_scent=PREY_SCENT,caution=PREY_SCENT_CAUTION,
        fixed="strong scent: slow SEARCH and orient existing visual scan, no extra sensory range; unconfirmed evidence expires; chase/attack unchanged",
        measurement="warm each mode one day; OFF OLD CAUTIOUS CAUTIOUS OLD OFF, sequential one thread")
    write(joinpath(out,"conditions.json"),JSON3.write(conditions));println(JSON3.write(conditions))
    frozen=joinpath(out,"source");mkpath(joinpath(frozen,"experiments/lw_wildlife"))
    cp(joinpath(@__DIR__,"../../src"),joinpath(frozen,"src"))
    for name in ("animals_only.jl","prey_scent_compare.jl","prey_scent_caution_compare.jl","predator_3d_spec.json")
        cp(joinpath(@__DIR__,name),joinpath(frozen,"experiments/lw_wildlife",name))
    end
    cp(joinpath(@__DIR__,"../../Project.toml"),joinpath(frozen,"Project.toml"))
    caution_checks()
    for (enabled,cautious) in ((false,false),(true,false),(true,true))
        scent_run(enabled;days=1,cautious)
    end
    runs=Any[]
    for (enabled,cautious) in ((false,false),(true,false),(true,true),(true,true),(true,false),(false,false))
        GC.gc();r=scent_run(enabled;cautious);push!(runs,r)
        println(JSON3.write((enabled=enabled,cautious=cautious,seconds=r.seconds,
            captures=[p.captures for p in r.final_state.predators],alive=[p.alive for p in r.final_state.predators],scent=r.scent)))
    end
    @testset "repeat and historical trajectories" begin
        for (a,b) in ((1,6),(2,5),(3,4))
            @test runs[a].final_state==runs[b].final_state
            @test runs[a].scent==runs[b].scent
        end
        prior=joinpath(@__DIR__,"../../outputs/prey-scent-3d-20261107/result.json")
        if isfile(prior)
            old=JSON3.read(read(prior,String))
            @test JSON3.read(JSON3.write(runs[1].final_state))==old.runs[1].final_state
            @test JSON3.read(JSON3.write(runs[2].final_state))==old.runs[2].final_state
        end
    end
    write(joinpath(out,"result.json"),JSON3.write((conditions=conditions,runs=runs)))
end
caution_main()
