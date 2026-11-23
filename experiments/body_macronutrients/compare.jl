include("run.jl")
using Test
# Experiment inputs, not physiology or learned preferences. C/P/F energy shares.
const DIET_COMPARISON=(mixed=(0.50,0.25,0.25),carbohydrate=(0.70,0.15,0.15),
                       fat=(0.15,0.15,0.70),protein=(0.15,0.70,0.15))
function compare_main()
    1<=length(ARGS)<=2 || error("usage: compare.jl NEW_OUTPUT [DAYS=10]")
    days=length(ARGS)==2 ? parse(Int,ARGS[2]) : CONFIGURED_BODY_CYCLE.days
    days>0 || error("days must be positive")
    out=abspath(ARGS[1]); ispath(out) && error("output already exists")
    mkpath(out); results=Dict{String,Any}()
    @testset "equal energy diet comparison" begin
        @test_throws ArgumentError simulate(meal_shares=(1.0,1.0,0.0))
        for (name,shares) in pairs(DIET_COMPARISON)
            simulate(days=1,meal_shares=shares)
            measured=@timed simulate(days=days,meal_shares=shares)
            run=measured.value
            @test run.final.ingested==days*CONFIGURED_BODY_CYCLE.meal_energy
            @test run.final.rejected==0.0
            @test run.max_relative_energy_error<1e-10
            @test run.max_step_energy_error<1e-8
            fine=simulate(days=days,dt=1/24,meal_shares=shares)
            @test abs(fine.final.sugar-run.final.sugar)<1.0
            @test abs(fine.final.fat-run.final.fat)<1.0
            daily_sums=zeros(days);daily_samples=zeros(Int,days)
            for row in run.timeline
                row.phase in ("before_meal","end") && continue
                daily_sums[row.day]+=row.body_demand;daily_samples[row.day]+=1
            end
            daily=[merge(row,(body_demand_mean=daily_sums[row.day]/daily_samples[row.day],)) for row in run.daily]
            folder=joinpath(out,string(name));mkpath(folder)
            write_csv(joinpath(folder,"timeline.csv"),run.timeline)
            write_csv(joinpath(folder,"daily.csv"),daily)
            write_csv(joinpath(folder,"final_day_timeline.csv"),filter(x->x.day==days,run.timeline))
            results[string(name)]=(;shares,final=run.final,daily,
                max_energy_error=run.max_energy_error,seconds=measured.time,bytes=measured.bytes,
                max_step_energy_error=run.max_step_energy_error,max_relative_energy_error=run.max_relative_energy_error,
                half_step_difference=(sugar=fine.final.sugar-run.final.sugar,fat=fine.final.fat-run.final.fat))
            println(name," ",JSON3.write((;final=run.final,final_day=last(daily))))
            flush(stdout)
        end
    end
    parameters=Dict(string(k)=>getfield(MacroParameters(),k) for k in fieldnames(MacroParameters))
    write(joinpath(out,"comparison.json"),JSON3.write((;cycle=merge(CONFIGURED_BODY_CYCLE,(;days)),parameters,
        initial=body_snapshot(MacroBody(),MacroParameters()),results,
        note="Same ingested E, not equal retained E: conversion losses differ. No biological calibration.")))
    write(joinpath(out,"completed.json"),JSON3.write((;days,conditions=length(results))))
end
abspath(PROGRAM_FILE)==(@__FILE__) && compare_main()
