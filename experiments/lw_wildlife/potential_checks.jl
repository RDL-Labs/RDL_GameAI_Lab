using JSON3, Serialization, Statistics, Test
include("../../src/ecology/lw_grazing/LWGrazing.jl")
const G=LWGrazing
const ROOT=normpath(joinpath(@__DIR__,"../.."))
const AUDIT=joinpath(ROOT,"outputs/rabbit-nursing-audit-20261106")
const OUT=joinpath(ROOT,"outputs/rabbit-potential-check-20261106")
mkpath(OUT)
input=JSON3.read(read(joinpath(AUDIT,"../rabbit-breeding-90d-20261106-v2/input.json"),String))
const HUMANS=[(Float64(p[1]),Float64(p[2])) for p in input.scene.positions]
function trial(enabled; ticks=3600, trace=false)
    world=deserialize(joinpath(AUDIT,"first-block.jls"))
    start=world.ticks; initial_blocked=world.animals.blocked[12]
    initial_nursed=world.life.nursed_day[61]
    first_nursing=nothing; path=Any[]
    stats=@timed for t in start:start+ticks-1
        t!=start && G.prepare!(world,HUMANS,t)
        G.advance!(world,t;nursing_potential=enabled)
        if trace && (t-start<100 || (t-start)%60==0)
            push!(path,(tick=t,x=world.animals.x[12],z=world.animals.z[12]))
        end
        if first_nursing===nothing && world.life.nursed_day[61]>initial_nursed
            first_nursing=(after_ticks=t-start+1,energy=copy(world.animals.energy[61:64]))
        end
    end
    @test all(i->G.H.clear(world.world,(world.animals.x[i],world.animals.z[i]),(world.animals.x[i],world.animals.z[i])),eachindex(world.alive))
    (enabled=enabled,seconds=stats.time,bytes=stats.bytes,first_nursing=first_nursing,
        blocked=world.animals.blocked[12]-initial_blocked,
        children_alive=copy(world.alive[61:64]),children_energy=copy(world.animals.energy[61:64]),path=path)
end
println("Conditions: exact first-block checkpoint; same rocks/humans; 3600 ticks; nursing unchanged; potential on/off; warmup then alternating 7 repeats")
trial(false);trial(true)
rows=Any[]
for rep in 1:7
    for enabled in (isodd(rep) ? (false,true) : (true,false))
        push!(rows,trial(enabled;trace=rep==1))
    end
end
baseline=filter(r->!r.enabled,rows);potential=filter(r->r.enabled,rows)
@test all(r->r.first_nursing===nothing && r.blocked==3600,baseline)
@test all(r->r.first_nursing!==nothing && r.first_nursing.after_ticks<100,potential)
summary=(baseline_median=median(r.seconds for r in baseline),potential_median=median(r.seconds for r in potential),
 baseline_blocked=baseline[1].blocked,potential_blocked=potential[1].blocked,first_nursing=potential[1].first_nursing)
continuations=(baseline=trial(false;ticks=3*G.RABBIT_LIFE.day_ticks),
    potential=trial(true;ticks=3*G.RABBIT_LIFE.day_ticks))
write(joinpath(OUT,"result.json"),JSON3.write((summary=summary,runs=rows,three_days=continuations)))
println(JSON3.write(summary))
println(JSON3.write(continuations))
