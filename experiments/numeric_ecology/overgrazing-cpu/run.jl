using JSON3, Random
include("Herbivores.jl")
const H=Herbivores
const SEED=20261005
base=JSON3.read(read(joinpath(@__DIR__,"map-spec.json"),String))
prototype,_=H.build(base)
cells=shuffle(MersenneTwister(SEED+10),findall(>(0),prototype.capacity))
function scenario(n)
    raw=JSON3.read(read(joinpath(@__DIR__,"map-spec.json"),String),Dict{String,Any})
    # Nested, broadly distributed starting sites; avoids artificial initial crowding.
    raw["scene"]["positions"]=[collect(H.center(prototype,cells[mod1(i,length(cells))])) for i in 1:n]
    JSON3.read(JSON3.write(raw))
end
include(joinpath(@__DIR__, "../../../src/ecology/overgrazing-cpu/simulation.jl"))
function simulate(n;days=10)
    simulate_overgrazing(scenario(n);days,seed=SEED,progress=r->println(JSON3.write(r)))
end
simulate(1;days=0) # Compile before timing.
allruns=NamedTuple[]
for n in (30,1000,3000)
    m=@timed simulate(n)
    result=(report=m.value,seconds=m.time,peak_rss_bytes=Sys.maxrss())
    write(joinpath(@__DIR__,"result-$(n).json"),JSON3.write(result))
    push!(allruns,result)
end
write(joinpath(@__DIR__,"results.json"),JSON3.write(allruns))
println("All runs and conservation checks completed")
