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
function simulate(n;days=10)
    w,a=H.build(scenario(n);seed=SEED); alive=trues(n)
    demand=zeros(length(w.grass)); ratio=similar(demand); req=zeros(n); active=Int[]
    rows=NamedTuple[]; first_death=-1; deaths=zeros(Int,n)
    lastgrown=0.; lasteaten=0.; lastcounts=zeros(Int,5)
    function record(t)
        for k in eachindex(w.grass); H.grass!(w,k,t); end
        counts=vec(sum(a.counts,dims=1)); energies=a.energy[alive]
        r=(day=t/17280,alive=count(alive),deaths=count(!,alive),grass=sum(w.grass),
            grass_fraction=sum(w.grass)/w.initial,depleted_cells=count(k->w.capacity[k]>0 && w.grass[k]<.005,eachindex(w.grass)),
            eaten=w.eaten,grown=w.grown,interval_eaten=w.eaten-lasteaten,interval_grown=w.grown-lastgrown,
            energy_mean=isempty(energies) ? nothing : sum(energies)/length(energies),
            interval_state_ticks=counts-lastcounts)
        @assert isapprox(w.initial+w.grown,sum(w.grass)+w.eaten;atol=1e-5,rtol=1e-9)
        push!(rows,r); lastgrown=w.grown; lasteaten=w.eaten; lastcounts=counts
        r
    end
    record(0)
    for t in 0:days*17280-1
        H.step!(w,a,t,demand,ratio,req,active;alive)
        for i in eachindex(alive)
            if alive[i] && a.energy[i]<=0
                alive[i]=false; deaths[i]=t+1
                first_death<0 && (first_death=t+1)
            end
        end
        if (t+1)%4320==0
            r=record(t+1)
            if (t+1)%17280==0
                println(JSON3.write((initial=n,day=r.day,alive=r.alive,grass_pct=100r.grass_fraction)))
                flush(stdout)
            end
        end
    end
    @assert isapprox(w.eaten,sum(a.consumed);atol=1e-5)
    @assert isapprox(sum(a.consumed),sum(a.gut)+sum(a.digested);atol=1e-5)
    @assert all(sum(a.counts[i,:])==(alive[i] ? days*17280 : deaths[i]) for i in 1:n)
    (initial=n,days=days,seed=SEED,grass_capacity=w.initial,maximum_regrowth_per_day=w.initial/2,
        first_death_day=first_death<0 ? nothing : first_death/17280,
        survivors=count(alive),rows=rows,death_ticks=deaths)
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
