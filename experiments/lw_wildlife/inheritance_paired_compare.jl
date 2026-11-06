include("predator_generations.jl")
using SHA, Statistics
function physical_content(x)
    x===nothing && return nothing
    x isa Union{Number,AbstractString,Bool} && return x
    x isa Symbol && return string(x)
    # RNG cache storage and serialization metadata need not have identical bytes.
    # Compare a non-consuming sample of the actual stream instead.
    x isa Random.AbstractRNG && return rand(deepcopy(x),UInt64,64)
    x isa AbstractDict && return [(string(k),physical_content(x[k])) for k in sort!(collect(keys(x));by=string)]
    x isa AbstractArray && return (size=size(x),values=[physical_content(v) for v in x])
    x isa Tuple && return [physical_content(v) for v in x]
    [(string(name),physical_content(getfield(x,name))) for name in fieldnames(typeof(x))]
end
function initial_digest(s,predators)
    bytes2hex(sha256(JSON3.write(physical_content((s,predators)))))
end
function paired_summary(rows)
    pairs=Any[]
    for code in sort!(unique(r.seed_code for r in rows))
        group=filter(r->r.seed_code==code,rows)
        length(group)==2 || continue
        fresh=only(filter(r->!r.inherited,group));inherited=only(filter(r->r.inherited,group))
        push!(pairs,(seed_code=code,fresh_mean=mean(fresh.lifetimes_days),
            inherited_mean=mean(inherited.lifetimes_days),difference=mean(inherited.lifetimes_days)-mean(fresh.lifetimes_days)))
    end
    isempty(pairs) && return nothing
    differences=[p.difference for p in pairs];n=length(pairs)
    # Pair, not individual, is the unit: the two actors share a world.
    rng=MersenneTwister(20261107)
    bootstrap=sort!([mean(differences[rand(rng,1:n,n)]) for _ in 1:10000])
    observed=abs(mean(differences))
    extreme=sum(abs(sum((isodd(mask >> (i-1)) ? 1 : -1)*differences[i] for i in 1:n)/n)>=observed-1e-12 for mask in 0:(2^n-1))
    (pairs=pairs,mean_difference=mean(differences),positive_pairs=count(>(0),differences),
        bootstrap_95=(bootstrap[250],bootstrap[9750]),sign_flip_two_sided=extreme/2^n,
        note="exploratory pair-level inference; fixed donor/map; shared seeds diverge after different actions")
end
function paired_main()
    source_run=abspath(ARGS[1]);out=abspath(ARGS[2])
    ispath(out) && error("output exists");mkpath(out)
    state=deserialize(joinpath(source_run,"final.jls"));winner=configured_survivor_index(state[2])
    donor_mind=state[4][winner];donor_local=state[6][winner];donor_tick=state[1].ticks
    inheritance_checks(donor_mind,donor_local,donor_tick)
    conditions=(source=source_run,donor=winner,pairs=10,seed_codes=collect(101:110),days=30,
        early_death_days=3,actors_per_run=2,adults=95,young=5,nutrition=1.5,
        boundary_gradient=true,probabilistic_capture=true,rest_reward=false,
        fixed="fixed generation-23 winner copied; no further selection; same map/rabbit initial seed; independently reset worlds",
        pairing="same body, positions, world, decision and capture RNG seeds within pair; only inherited MB differs",
        analysis="mean per actor restricted to 30d; pair is statistical unit; early death <=3d; 10000 paired bootstrap, exact sign flip")
    write(joinpath(out,"conditions.json"),JSON3.write(conditions));println(JSON3.write(conditions));flush(stdout)
    frozen=joinpath(out,"source");mkpath(joinpath(frozen,"experiments/lw_wildlife"))
    cp(joinpath(@__DIR__,"../../src"),joinpath(frozen,"src"))
    for name in ("inheritance_paired_compare.jl","predator_generations.jl","animals_only.jl","prey_scent_compare.jl","predator_3d_spec.json")
        cp(joinpath(@__DIR__,name),joinpath(frozen,"experiments/lw_wildlife",name))
    end
    cp(joinpath(@__DIR__,"../../Project.toml"),joinpath(frozen,"Project.toml"))
    rows=Any[]
    for code in conditions.seed_codes
        physical_digest=nothing;loop_seeds=nothing
        for inherited in (iseven(code) ? (true,false) : (false,true))
            run_out=joinpath(out,"seed-$code-"*(inherited ? "inherited" : "fresh"));mkpath(run_out)
            function initialize(s,predators,minds,locals)
                for actor in 1:2
                    if inherited
                        minds[actor],locals[actor]=configured_predator_mb_inherit(donor_mind,donor_local,actor,code,donor_tick)
                    else
                        minds[actor].loop=LW.BasicLoop("predator:$actor:maintain";probabilistic=true,seed=20261106+1000*code+actor)
                        locals[actor].loop=LW.BasicLoop("predator:$actor:capture";probabilistic=true,seed=20261107+1000*code+actor)
                        @assert isempty(minds[actor].places) && isempty(locals[actor].capture_experience)
                    end
                    Random.seed!(predators[actor].visual.rng,20261106+1000*code+actor)
                end
                digest=initial_digest(s,predators)
                seeds=[(minds[i].loop.seed,locals[i].loop.seed) for i in 1:2]
                physical_digest===nothing ? (physical_digest=digest) : (@assert physical_digest==digest)
                loop_seeds===nothing ? (loop_seeds=seeds) : (@assert loop_seeds==seeds)
                serialize(joinpath(run_out,"initial.jls"),(s,predators,minds,locals))
            end
            result=scent_run(true;days=conditions.days,cautious=true,motion_speed=true,checkpoint_dir=run_out,
                local_hunt=true,boundary_gradient=true,probabilistic_capture=true,initialize_minds=initialize)
            final=deserialize(joinpath(run_out,"final.jls"))
            lifetimes=configured_predator_lifetime.(final[2])./17280
            row=(seed_code=code,inherited=inherited,initial_digest=physical_digest,loop_seeds=loop_seeds,
                lifetimes_days=lifetimes,early_deaths=count(<=(conditions.early_death_days),lifetimes),
                survivors=count(p->p.alive,final[2]),captures=[p.visual.body.captures for p in final[2]],seconds=result.seconds)
            write(joinpath(run_out,"result.json"),JSON3.write((summary=row,result=result)))
            push!(rows,row);write(joinpath(out,"result.json"),JSON3.write((conditions=conditions,runs=rows,analysis=paired_summary(rows))))
            println("RUN_COMPLETE ",JSON3.write(row));flush(stdout)
        end
    end
end
abspath(PROGRAM_FILE)==(@__FILE__) && paired_main()
