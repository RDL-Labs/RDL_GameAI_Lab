include("prey_scent_compare.jl")
function scent_motion_longrun()
    out=abspath(ARGS[1]);days=length(ARGS)>1 ? parse(Int,ARGS[2]) : 30
    days>0 || error("days must be positive")
    ispath(out) && error("output exists");mkpath(out)
    conditions=(days=days,adults=95,young=5,predators=2,humans=0,nutrition=1.5,
        marking=true,cognition=true,prey_scent=true,cautious=true,motion_speed=true,
        stop_on_predator_extinction=true,prey_rule=PREY_SCENT,caution_rule=PREY_SCENT_CAUTION,
        motion_rule=G.MOTION_VISIBILITY,
        fixed="same provisional scent steering/caution and speed perception as the three-day trial; no sound, wind, human actors or revised attack geometry")
    write(joinpath(out,"conditions.json"),JSON3.write(conditions));println(JSON3.write(conditions));flush(stdout)
    frozen=joinpath(out,"source");mkpath(joinpath(frozen,"experiments/lw_wildlife"))
    cp(joinpath(@__DIR__,"../../src"),joinpath(frozen,"src"))
    for name in ("animals_only.jl","prey_scent_compare.jl","scent_motion_longrun.jl","predator_3d_spec.json")
        cp(joinpath(@__DIR__,name),joinpath(frozen,"experiments/lw_wildlife",name))
    end
    cp(joinpath(@__DIR__,"../../Project.toml"),joinpath(frozen,"Project.toml"))
    result=scent_run(true;days,cautious=true,motion_speed=true,checkpoint_dir=out)
    completion=(reason=all(p->!p.alive,result.final_state.predators) ? "predator_extinction" : "duration_reached",
        elapsed_days=result.ticks/17280,completed_days=length(result.daily),stopped_in_day=cld(result.ticks,17280))
    write(joinpath(out,"result.json"),JSON3.write((conditions=conditions,completion=completion,result=result)))
    reference=joinpath(@__DIR__,"../../outputs/motion-speed-3d-20261107/result.json")
    if isfile(reference) && length(result.daily)>=3
        prior=JSON3.read(read(reference,String))
        @testset "first three days match" begin
            for day in 1:3
                @test JSON3.read(JSON3.write(result.daily[day]))==prior.runs[2].daily[day]
            end
        end
    end
    println("COMPLETE ",JSON3.write(completion)," seconds=",result.seconds)
end
scent_motion_longrun()
