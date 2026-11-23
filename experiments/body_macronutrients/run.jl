using JSON3
include("../../src/body/macronutrients.jl")
using .Macronutrients
include("../../src/lw/configured_paths/body_local_cycle.jl")

function simulate(;days=CONFIGURED_BODY_CYCLE.days,dt=CONFIGURED_BODY_CYCLE.step_hours,meal_scale=1.0,
                  meal_shares=CONFIGURED_BODY_CYCLE.meal_shares,parameters=MacroParameters())
    length(meal_shares)==3 && all(x->isfinite(x) && x>=0,meal_shares) &&
        isapprox(sum(meal_shares),1.0) || throw(ArgumentError("C/P/F energy shares must sum to one"))
    p=parameters; b=MacroBody(); initial_energy=nutrient_energy(b)
    timeline=NamedTuple[]; daily=NamedTuple[]; max_error=0.0; max_step_error=0.0; max_relative_error=0.0
    cycle=CONFIGURED_BODY_CYCLE
    steps=round(Int,cycle.day_hours/dt)
    @assert isapprox(steps*dt,cycle.day_hours)
    @assert isapprox(round(cycle.return_end/dt)*dt,cycle.return_end)
    for day in 1:days
        first_row=length(timeline)+1
        start=body_snapshot(b,p)
        for step in 0:steps-1
            local_hour=step*dt
            hour=(day-1)*cycle.day_hours+local_hour
            phase=configured_body_phase(local_hour)
            # Snapshot before and after feeding at the same timestamp: shows satiety
            # independently of subsequent absorption. Exactly one meal per day.
            meal=0.0
            if b.alive && step==round(Int,cycle.return_end/dt)
                push!(timeline,(;hour,day,phase="before_meal",meal=0.0,body_snapshot(b,p)...))
                meal=feed!(b,ntuple(i->cycle.meal_energy*meal_shares[i]*meal_scale,3),p)
            end
            push!(timeline,(;hour,day,phase=phase.phase,meal,body_snapshot(b,p)...))
            before_energy=nutrient_energy(b)
            before_sinks=(b.spent,b.conversion_loss,b.excreted)
            advance!(b,p,dt;intensity=phase.intensity,sleeping=phase.sleeping)
            step_error=before_energy-nutrient_energy(b)-(b.spent-before_sinks[1])-
                       (b.conversion_loss-before_sinks[2])-(b.excreted-before_sinks[3])
            max_step_error=max(max_step_error,abs(step_error))
            @assert abs(step_error)<1e-8 "single update energy ledger"
            error=initial_energy+b.ingested-nutrient_energy(b)-b.spent-b.conversion_loss-b.excreted
            max_error=max(max_error,abs(error))
            relative_error=abs(error)/max(1.0,initial_energy+b.ingested)
            max_relative_error=max(max_relative_error,relative_error)
            # Diagnostic tolerance only: long runs accumulate Float64 sink sums.
            # Do not inject energy or adjust physical state to close this ledger.
            @assert abs(error)<1e-7 || relative_error<1e-10 "cumulative energy ledger"
            @assert all(x->isfinite(x) && x>=-1e-9,(b.sugar,b.fat,b.tissue,b.amino,b.gut...))
            @assert b.sugar<=p.sugar_capacity+1e-9 && b.fat<=p.fat_capacity+1e-9
        end
        finish=body_snapshot(b,p)
        rows=@view timeline[first_row:end]
        push!(daily,(;day,sugar=finish.sugar,fat=finish.fat,tissue=finish.tissue,amino=finish.amino,
            gut=finish.gut,body_demand_min=minimum(x.body_demand for x in rows),body_demand_max=maximum(x.body_demand for x in rows),
            sugar_min=minimum(x.sugar for x in rows),sugar_max=maximum(x.sugar for x in rows),
            tissue_min=minimum(x.tissue for x in rows),intake=finish.ingested-start.ingested,
            spent=finish.spent-start.spent,conversion_loss=finish.conversion_loss-start.conversion_loss,
            excreted=finish.excreted-start.excreted,unmet=finish.unmet-start.unmet,
            repaired=finish.repaired-start.repaired,energy_delta=finish.energy-start.energy))
    end
    push!(timeline,(;hour=days*cycle.day_hours,day=days,phase="end",meal=0.0,body_snapshot(b,p)...))
    (;timeline,daily,final=body_snapshot(b,p),initial_energy,max_energy_error=max_error,
      max_step_energy_error=max_step_error,max_relative_energy_error=max_relative_error)
end

function write_csv(path,rows)
    open(path,"w") do io
        println(io,join(string.(keys(first(rows))),","))
        for row in rows; println(io,join(string.(values(row)),",")); end
    end
end

function main()
    out=isempty(ARGS) ? joinpath(@__DIR__,"results","mixed10") : abspath(ARGS[1])
    isdir(out) && !isempty(readdir(out)) && error("output must be empty: $out")
    mkpath(out)
    simulate(days=1) # compile outside measured 10-day run
    measured=@timed simulate()
    run=measured.value
    write_csv(joinpath(out,"timeline.csv"),run.timeline)
    write_csv(joinpath(out,"daily.csv"),run.daily)
    parameters=Dict(string(k)=>getfield(MacroParameters(),k) for k in fieldnames(MacroParameters))
    summary=(;days=CONFIGURED_BODY_CYCLE.days,units="abstract energy-equivalent E, hours; not blood glucose",
        configured_cycle=CONFIGURED_BODY_CYCLE,parameters,initial=body_snapshot(MacroBody(),MacroParameters()),
        final=run.final,daily=run.daily,max_energy_error=run.max_energy_error,
        measurement=(seconds=measured.time,bytes=measured.bytes,gc_seconds=measured.gctime,
                     scope="warmed simulation including in-memory observation; excludes files and plots"))
    write(joinpath(out,"summary.json"),JSON3.write(summary))
    println(JSON3.write(summary))
end
abspath(PROGRAM_FILE)==(@__FILE__) && main()
