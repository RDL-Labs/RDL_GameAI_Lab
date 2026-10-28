using JSON3, Serialization, SHA, Test
const root=abspath(ARGS[1]);const out=abspath(ARGS[2]);mkpath(out)
include(joinpath(root,"source/integrations/lightweight_julia/native.jl"))
Base.include_string(Main,read(joinpath(@__DIR__,"../../src/lw/learning/mb_sleep.jl"),String))
const old=read(abspath(ARGS[3]),String)
const new=read(joinpath(@__DIR__,"../../src/lw/learning/mb_map.jl"),String)
function trial(base,day)
 maps=deepcopy(base)
 for m in values(maps);mb_sleep_freeze!(m,day*17_280_000_000);end
 GC.gc()
 started=time_ns()
 for m in values(maps);Base.invokelatest(mb_sleep_review!,m,day+1,day*17_280_000_000+1);end
 seconds=(time_ns()-started)/1e9
 io=IOBuffer();serialize(io,maps)
 D("seconds"=>seconds,"sha256"=>bytes2hex(sha256(take!(io))))
end
results=Any[]
for day in (1,44,89)
 c=deserialize(joinpath(root,"ordinary/checkpoints/day-"*lpad(day,3,'0')*".jls"))
 @assert c.code==checkpoint_code_hash()
 base=c.state[:mb_maps];c=nothing
 row=D("checkpoint_day"=>day,"scope"=>"fresh sleep review of saved actor graphs; cloning and freezing excluded")
 for (name,source) in (("before",old),("after",new))
  Base.include_string(Main,source)
  trial(base,day) # Warm identical operation before measurement.
  row[name]=[trial(base,day) for _ in 1:3]
  println(day," ",name," ",JSON3.write(row[name]));flush(stdout)
 end
 @test length(unique(x["sha256"] for name in ("before","after") for x in row[name]))==1
 push!(results,row);write(joinpath(out,"comparison.json"),JSON3.write(results))
end

