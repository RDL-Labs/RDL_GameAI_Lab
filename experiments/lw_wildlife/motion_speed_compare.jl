include("prey_scent_compare.jl")
function motion_checks()
    @testset "speed visibility boundaries and perception" begin
        @test G.configured_motion_visibility(0.,false)==.55
        @test G.configured_motion_visibility(.08,false)≈.622
        @test G.configured_motion_visibility(.22,false)≈.748
        @test G.configured_motion_visibility(.5,false)==1.
        @test G.configured_motion_visibility(2.,false)==1.
        @test G.configured_motion_visibility(0.,true)==1.
        for (speed,tracked,enabled,expected) in ((.08,false,true,false),(.5,false,true,true),(.08,true,true,true),(.08,false,false,true))
            s,ps=animal_trial_world();p=ps[1]
            empty!(s.world.obstacles);s.world.traits.density.=0.;s.alive.=false;s.alive[1]=true
            s.animals.x[1]=-3.;s.animals.z[1]=6.;s.animals.heading[1]=pi;s.gaze[1]=pi
            p.visual.body.x=-10.;p.visual.body.z=6.;p.visual.previous_position=(-10.0-speed,6.)
            if tracked
                s.last_seen[1]=-1;s.seen_actor[1]=1;s.seen_position[1]=(-10.,6.)
            end
            before=p.visual.seen_by_rabbits
            G.prepare!(s,Tuple{Float64,Float64}[],0;additional_predators=[p.visual],additional_predator_alive=[true],motion_speed=enabled)
            @test (p.visual.seen_by_rabbits>before)==expected
        end
    end
end
function motion_main()
    out=abspath(ARGS[1]);ispath(out) && error("output exists");mkpath(out)
    conditions=(days=3,adults=95,young=5,predators=2,humans=0,nutrition=1.5,cautious=true,
        motion=G.MOTION_VISIBILITY,fixed="rabbit vision uses actual displacement per tick; tracked targets retain visibility; no sound or angular-speed model",
        measurement="warm each mode one day; binary continuous continuous binary; sequential one thread")
    println(JSON3.write(conditions));write(joinpath(out,"conditions.json"),JSON3.write(conditions))
    frozen=joinpath(out,"source");mkpath(joinpath(frozen,"experiments/lw_wildlife"))
    cp(joinpath(@__DIR__,"../../src"),joinpath(frozen,"src"))
    for name in ("animals_only.jl","prey_scent_compare.jl","motion_speed_compare.jl","predator_3d_spec.json")
        cp(joinpath(@__DIR__,name),joinpath(frozen,"experiments/lw_wildlife",name))
    end
    cp(joinpath(@__DIR__,"../../Project.toml"),joinpath(frozen,"Project.toml"))
    motion_checks()
    for enabled in (false,true);scent_run(true;days=1,cautious=true,motion_speed=enabled);end
    runs=Any[]
    for enabled in (false,true,true,false)
        GC.gc();r=scent_run(true;cautious=true,motion_speed=enabled);push!(runs,r)
        println(JSON3.write((continuous=enabled,seconds=r.seconds,captures=[p.captures for p in r.final_state.predators],
            alive=[p.alive for p in r.final_state.predators],scent=r.scent)))
    end
    @testset "repeat and baseline" begin
        @test runs[1].final_state==runs[4].final_state
        @test runs[2].final_state==runs[3].final_state
        @test runs[2].scent==runs[3].scent
        prior=joinpath(@__DIR__,"../../outputs/prey-scent-caution-3d-20261107/result.json")
        if isfile(prior)
            old=JSON3.read(read(prior,String))
            @test JSON3.read(JSON3.write(runs[1].final_state))==old.runs[3].final_state
        end
    end
    write(joinpath(out,"result.json"),JSON3.write((conditions=conditions,runs=runs)))
end
motion_main()
