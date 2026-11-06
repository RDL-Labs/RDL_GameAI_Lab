include("prey_scent_compare.jl")
include("../../src/lw/configured_paths/predator_mb_inheritance.jl")
using Random
function inheritance_checks(donor_mind,donor_local,tick)
    @testset "independent inherited MBs" begin
        a,la=configured_predator_mb_inherit(donor_mind,donor_local,1,1,tick)
        b,lb=configured_predator_mb_inherit(donor_mind,donor_local,2,1,tick)
        @test JSON3.write(a.estimates)==JSON3.write(donor_mind.estimates)
        @test la.capture_experience==lb.capture_experience==donor_local.capture_experience
        @test a.loop.goal!=b.loop.goal && a.loop.seed!=b.loop.seed
        @test a.loop.H==0 && la.loop.H==0 && a.trial===nothing && a.loop.trial===nothing
        @test isempty(la.memory) && la.wait_trial===nothing && la.selected===nothing
        @test a.loop.methods!==b.loop.methods && a.loop.methods!==donor_mind.loop.methods
        for key in keys(a.loop.methods)
            @test a.loop.methods[key]!==b.loop.methods[key]
            @test a.loop.methods[key].reward==donor_mind.loop.methods[key].reward
        end
        a.estimates["inheritance_probe"]=-1.
        @test !haskey(b.estimates,"inheritance_probe") && !haskey(donor_mind.estimates,"inheritance_probe")
        la.capture_experience["inheritance_probe"]=(1,1)
        @test !haskey(lb.capture_experience,"inheritance_probe") && !haskey(donor_local.capture_experience,"inheritance_probe")
        @test all(a.places[k].seen==v.seen-tick for (k,v) in donor_mind.places)
        if haskey(a.acquisition,"acquisition")
            @test !haskey(a.acquisition["acquisition"],"last_result_us")
            @test a.acquisition["acquisition"]["active"]===nothing
            @test a.acquisition["acquisition"]["sites"]!==b.acquisition["acquisition"]["sites"]
        end
    end
end
function generations_main()
    source_run=abspath(ARGS[1]);out=abspath(ARGS[2])
    generations=length(ARGS)>2 ? parse(Int,ARGS[3]) : 3
    days=length(ARGS)>3 ? parse(Int,ARGS[4]) : 30
    generations>0 && days>0 || error("positive generations/days required")
    ispath(out) && error("output exists");mkpath(out)
    donor_state=deserialize(joinpath(source_run,"final.jls"))
    donor_index=configured_survivor_index(donor_state[2])
    donor_mind=donor_state[4][donor_index];donor_local=donor_state[6][donor_index]
    donor_tick=donor_state[1].ticks
    donor_local.probabilistic_capture || error("requires probability model donor")
    conditions=(generations=generations,days_per_generation=days,source=basename(source_run),
        initial_donor=donor_index,initial_lifetimes=configured_predator_lifetime.(donor_state[2]),
        selection="longest alive ticks; ties use lower actor index; day-limit survival is censored",
        map="same map and rabbit seed, resources reset",adults=95,young=5,predators=2,
        boundary_gradient=true,probabilistic_capture=true,nutrition=1.5,
        fixed="experimenter selects and copies MB; independent offspring; body, acute H, trials and perceptions reset; no mutation",
        seed_rule="decision seeds 20261106/20261107 + 1000*generation + actor; capture RNG 20261106 + 1000*generation + actor")
    write(joinpath(out,"conditions.json"),JSON3.write(conditions));println(JSON3.write(conditions));flush(stdout)
    frozen=joinpath(out,"source");mkpath(joinpath(frozen,"experiments/lw_wildlife"))
    cp(joinpath(@__DIR__,"../../src"),joinpath(frozen,"src"))
    for name in ("predator_generations.jl","animals_only.jl","prey_scent_compare.jl","predator_3d_spec.json")
        cp(joinpath(@__DIR__,name),joinpath(frozen,"experiments/lw_wildlife",name))
    end
    cp(joinpath(@__DIR__,"../../Project.toml"),joinpath(frozen,"Project.toml"))
    rows=Any[]
    for generation in 1:generations
        inheritance_checks(donor_mind,donor_local,donor_tick)
        generation_out=joinpath(out,"generation-$generation");mkpath(generation_out)
        parent_record=(index=donor_index,methods=length(donor_mind.loop.methods),
            places=length(donor_mind.places),estimates=deepcopy(donor_mind.estimates),capture_experience=deepcopy(donor_local.capture_experience))
        function initialize(s,predators,minds,locals)
            for actor in 1:2
                minds[actor],locals[actor]=configured_predator_mb_inherit(donor_mind,donor_local,actor,generation,donor_tick)
                Random.seed!(predators[actor].visual.rng,20261106+1000*generation+actor)
            end
            serialize(joinpath(generation_out,"initial.jls"),(s,predators,minds,locals))
        end
        result=scent_run(true;days,cautious=true,motion_speed=true,checkpoint_dir=generation_out,
            local_hunt=true,boundary_gradient=true,probabilistic_capture=true,initialize_minds=initialize)
        state=deserialize(joinpath(generation_out,"final.jls"))
        lifetimes=configured_predator_lifetime.(state[2]);winner=configured_survivor_index(state[2])
        row=(generation=generation,parent=parent_record,winner=winner,lifetimes=lifetimes,
            lifetimes_days=lifetimes./17280,censored=[p.alive for p in state[2]],
            captures=[p.visual.body.captures for p in state[2]],elapsed_days=result.ticks/17280,
            seconds=result.seconds,rabbits_alive=result.final_state.rabbits.alive)
        write(joinpath(generation_out,"result.json"),JSON3.write((summary=row,result=result)))
        push!(rows,row);write(joinpath(out,"result.json"),JSON3.write((conditions=conditions,generations=rows)))
        println("GENERATION_COMPLETE ",JSON3.write(row));flush(stdout)
        donor_mind=state[4][winner];donor_local=state[6][winner];donor_tick=state[1].ticks;donor_index=winner
    end
end
abspath(PROGRAM_FILE)==(@__FILE__) && generations_main()
