# Sequential separate processes: no concurrent simulations distort timing.
using JSON3
const source_run=abspath(ARGS[1]);const pair_out=abspath(ARGS[2])
const first_day=parse(Int,ARGS[3]);const duration=parse(Int,ARGS[4])
mkpath(pair_out)
runner=joinpath(@__DIR__,length(ARGS)>=5 ? ARGS[5] : "profile_human_ecology.jl")
for mode in ("baseline","boxes")
    isfile(joinpath(pair_out,"STOP")) && break
    mode_out=joinpath(pair_out,mode)
    write(joinpath(pair_out,"status.json"),JSON3.write((mode,status="running",first_day,duration)))
    open(joinpath(pair_out,"$mode.stdout.log"),"w") do stdout_io
        open(joinpath(pair_out,"$mode.stderr.log"),"w") do stderr_io
            run(pipeline(`$(Base.julia_cmd()) --project=$(dirname(Base.active_project())) $runner $source_run $mode_out $first_day $mode $duration`,stdout=stdout_io,stderr=stderr_io))
        end
    end
    result=JSON3.read(read(joinpath(mode_out,"completed.json"),String))
    if !result.completed
        write(joinpath(pair_out,"status.json"),JSON3.write((mode,status="stopped",last_day=result.last_day)))
        exit()
    end
end
finished=all(mode->isfile(joinpath(pair_out,mode,"completed.json")) &&
    JSON3.read(read(joinpath(pair_out,mode,"completed.json"),String)).completed,("baseline","boxes"))
write(joinpath(pair_out,"completed.json"),JSON3.write((completed=finished,first_day,duration,modes=["baseline","boxes"])))
write(joinpath(pair_out,"status.json"),JSON3.write((status=finished ? "complete" : "stopped",first_day,duration)))
