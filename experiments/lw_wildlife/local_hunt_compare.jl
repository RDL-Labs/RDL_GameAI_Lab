include("prey_scent_compare.jl")
function hunt_checks()
    @testset "local hunt forecast boundaries" begin
        s,ps=animal_trial_world();w=s.world;empty!(w.obstacles)
        state=LocalHunt(1);o=(id=1,x=-9.6,z=6.,distance=.4)
        f=local_hunt_prediction(state,o,1)
        @test f.vx==0 && f.vz==0 # No hidden velocity when only one sighting exists.
        state.memory[1]=(x=-10.,z=6.,tick=0)
        @test local_hunt_prediction(state,o,1).vx≈.4
        @test local_hunt_prediction(state,o,50).vx==0
        step=local_hunt_rollout(w,(-10.,6.),f)
        @test step.speed≈.4 # Stop at predicted position, do not force a full unit.
        push!(w.obstacles,H.RDLMigrationProbe.Circle(-9.8,6.,.1))
        @test local_hunt_rollout(w,(-10.,6.),f)===nothing
        empty!(w.obstacles)
        @test local_hunt_rollout(w,(w.xmax-.3,6.),(x=w.xmax+.5,z=6.,vx=0.,vz=0.))===nothing
        p=ps[1];b=p.visual.body;b.state=P.ATTACK;b.attacks=1;b.target=1
        configured_local_hunt_plan!(state,trial_proxy(s,p),NamedTuple[],0)
        @test b.misses==1 && b.state==P.RECOVER && last(p.visual.events).kind=="abort_unseen"
        @test isempty(state.records)
    end
end
function hunt_main()
    out=abspath(ARGS[1]);ispath(out) && error("output exists");mkpath(out)
    conditions=(days=3,adults=95,young=5,predators=2,nutrition=1.5,marking=true,cognition=true,
        cautious_scent=true,motion_speed=true,local_hunt_rule=LOCAL_HUNT,
        fixed="local exact terrain query; observed prey history only; provisional priorities/horizon; common probabilistic BasicLoop; no rest reward changes",
        measurement="one-day warmup each; OFF ON ON OFF sequential, one thread")
    println(JSON3.write(conditions));write(joinpath(out,"conditions.json"),JSON3.write(conditions))
    frozen=joinpath(out,"source");mkpath(joinpath(frozen,"experiments/lw_wildlife"))
    cp(joinpath(@__DIR__,"../../src"),joinpath(frozen,"src"))
    for name in ("animals_only.jl","prey_scent_compare.jl","local_hunt_compare.jl","predator_3d_spec.json")
        cp(joinpath(@__DIR__,name),joinpath(frozen,"experiments/lw_wildlife",name))
    end
    cp(joinpath(@__DIR__,"../../Project.toml"),joinpath(frozen,"Project.toml"))
    hunt_checks()
    for enabled in (false,true);scent_run(true;days=1,cautious=true,motion_speed=true,local_hunt=enabled);end
    runs=Any[]
    for enabled in (false,true,true,false)
        GC.gc();r=scent_run(true;cautious=true,motion_speed=true,local_hunt=enabled);push!(runs,r)
        println(JSON3.write((local_hunt=enabled,seconds=r.seconds,captures=[p.captures for p in r.final_state.predators],
            attacks=[p.attacks for p in r.final_state.predators],alive=[p.alive for p in r.final_state.predators])))
        flush(stdout)
    end
    @testset "repeat and baseline" begin
        @test runs[1].final_state==runs[4].final_state
        @test runs[2].final_state==runs[3].final_state
        @test runs[2].local_hunt==runs[3].local_hunt
        old=joinpath(@__DIR__,"../../outputs/motion-speed-3d-20261107/result.json")
        if isfile(old)
            prior=JSON3.read(read(old,String));@test JSON3.read(JSON3.write(runs[1].final_state))==prior.runs[2].final_state
        end
    end
    write(joinpath(out,"result.json"),JSON3.write((conditions=conditions,runs=runs)))
end
hunt_main()
