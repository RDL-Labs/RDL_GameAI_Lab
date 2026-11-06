# Isolated ecology run on the current LW terrain; humans remain at initial positions.
using JSON3, SHA
length(ARGS) in 2:3 || error("OUTPUT DAYS [GRASS_SCALE]")
output=abspath(ARGS[1]);days=parse(Int,ARGS[2]);scale=length(ARGS)==3 ? parse(Float64,ARGS[3]) : 1.
1<=days<=365 && isfinite(scale) && scale>0 || error("invalid ecology run settings")
ispath(output) && error("fresh output required")
mkpath(output)
repo=normpath(joinpath(@__DIR__,"../.."))
cp(joinpath(repo,"src"),joinpath(output,"source"))
cp(@__FILE__,joinpath(output,"runner.jl"))
input_path=joinpath(repo,"outputs/aid-resource-30d-20261106/input.json")
cp(input_path,joinpath(output,"input.json"))
input=JSON3.read(read(input_path,String))
include(joinpath(output,"source/ecology/lw_grazing/LWGrazing.jl"))
scene=merge((;pairs(input.scene)...),(wildlife=(enabled=true,count=30,seed=20261028,reproduction=true,grass_scale=scale),))
world=LWGrazing.build(scene,input.clock)
humans=[(Float64(p[1]),Float64(p[2])) for p in scene.positions]
write(joinpath(output,"conditions.json"),JSON3.write((days=days,wildlife=scene.wildlife,
    human_motion="fixed initial positions; ecology-only trial, not human-life outcome",
    predators=false,fixed="infant nest wait; maternal return with local potential; daily mating encounter sample",
    nursing_potential=true,potential_rules=LWGrazing.RABBIT_POTENTIAL,
    rules=LWGrazing.RABBIT_LIFE,input_sha256=bytes2hex(sha256(read(input_path))))))
started=time();ecology_previous_wall=Ref(time());daily=Any[]
for tick in 0:days*LWGrazing.RABBIT_LIFE.day_ticks-1
    LWGrazing.prepare!(world,humans,tick);LWGrazing.advance!(world,tick)
    if (tick+1)%LWGrazing.RABBIT_LIFE.day_ticks==0
        report=LWGrazing.snapshot(world);wall=time()
        row=(day=div(tick+1,LWGrazing.RABBIT_LIFE.day_ticks),alive=report.alive,
            total=report.count,deaths=report.starvation_deaths,reproduction=report.reproduction,
            grass=report.grass_remaining,eaten=report.grass_eaten,seconds=wall-ecology_previous_wall[])
        push!(daily,row);ecology_previous_wall[]=wall
        write(joinpath(output,"progress.json"),JSON3.write(row))
        open(joinpath(output,"daily.jsonl"),"a") do io;println(io,JSON3.write(row));end
    end
end
result=(elapsed_seconds=time()-started,days=days,daily=daily,final=LWGrazing.snapshot(world))
write(joinpath(output,"result.json"),JSON3.write(result))
write(joinpath(output,"completed.json"),JSON3.write((days=days,verified=true)))
println(JSON3.write((elapsed_seconds=result.elapsed_seconds,alive=result.final.alive,
    births=result.final.reproduction.births,deaths=result.final.starvation_deaths)))
