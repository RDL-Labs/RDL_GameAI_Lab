# Sequential whole-run comparison; each child is a fresh Julia process.
using JSON3
root=abspath(ARGS[1]);project=abspath(ARGS[2]);days=parse(Int,ARGS[3])
for variant in ("baseline","optimized")
    isfile(joinpath(root,"STOP")) && exit(0)
    destination=joinpath(root,variant)
    write(joinpath(root,"phase.json"),JSON3.write((;variant,status="running",days)))
    command=`$(Base.julia_cmd()) --project=$project $(joinpath(root,"runner.jl")) $(joinpath(destination,"source")) $(joinpath(destination,"run")) 1 boxes $days`
    run(pipeline(command;stdout=joinpath(destination,"stdout.log"),stderr=joinpath(destination,"stderr.log")))
    result=JSON3.read(read(joinpath(destination,"run/completed.json"),String))
    if !result.completed
        write(joinpath(root,"phase.json"),JSON3.write((;variant,status="stopped",last_day=result.last_day)))
        exit(0)
    end
    @assert result.last_day==days
end
run(`$(Base.julia_cmd()) --project=$project $(joinpath(root,"compare.jl")) $root $days`)
write(joinpath(root,"phase.json"),JSON3.write((status="completed",days=days)))
