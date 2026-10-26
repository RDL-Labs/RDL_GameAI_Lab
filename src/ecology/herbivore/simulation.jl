function simulate(spec;days=3,seed=20261005,grass_scale=1.,rich=false,out=nothing,policy=StateMachinePolicy())
    w,a=build(spec;seed,grass_scale,rich); n=length(a.x)
    demand=zeros(length(w.grass)); ratio=similar(demand); requests=zeros(n); active=Int[]
    initial=copy(w.grass); rows=Any[]; samples=Any[]
    ticks=days*div(Int(spec.clock.day_us),1_000_000)
    for t in 0:ticks-1
        step!(w,a,t,demand,ratio,requests,active;policy)
        if t%60==0
            for i in 1:n; push!(samples,(t,i,a.x[i],a.z[i],a.state[i],a.energy[i],a.gut[i],a.sleepy[i])); end
        end
        if (t+1)%17280==0
            push!(rows,(day=div(t+1,17280),energy_min=minimum(a.energy),energy_mean=sum(a.energy)/n,eaten=w.eaten,distance=sum(a.distance),starvation_ticks=sum(a.starvation_ticks),state_ticks=vec(sum(a.counts,dims=1))))
        end
    end
    for k in eachindex(w.grass); grass!(w,k,ticks); end
    @assert isapprox(w.initial+w.grown,sum(w.grass)+w.eaten;atol=1e-6,rtol=1e-10)
    @assert isapprox(w.eaten,sum(a.consumed);atol=1e-6)
    @assert isapprox(sum(a.consumed),sum(a.gut)+sum(a.digested);atol=1e-6)
    @assert all(sum(a.counts[i,:])==ticks for i in 1:n)
    @assert all(isfinite,a.energy) && all(x->0<=x<=100,a.energy)
    @assert all(i->clear(w,(a.x[i],a.z[i]),(a.x[i],a.z[i])),1:n)
    report=(agents=n,days=days,ticks=ticks,agent_updates=n*ticks,grass_cells=count(>(0),w.capacity),cells=length(w.grass),grass_initial=w.initial,grass_grown=w.grown,grass_remaining=sum(w.grass),grass_eaten=w.eaten,state_names=STATES,daily=rows,final=[(id=i,x=a.x[i],z=a.z[i],energy=a.energy[i],gut=a.gut[i],distance=a.distance[i],eaten=a.consumed[i],starvation_ticks=a.starvation_ticks[i],blocked=a.blocked[i],state_ticks=a.counts[i,:]) for i in 1:n])
    if out!==nothing
        mkpath(out)
        open(joinpath(out,"result.json"),"w") do io; JSON3.write(io,report); end
        open(joinpath(out,"grass.csv"),"w") do io
            println(io,"x,z,material,walkable,initial,final,capacity")
            for k in eachindex(w.grass); x,z=center(w,k); println(io,join((x,z,w.material[k],Int(w.walkable[k]),initial[k],w.grass[k],w.capacity[k]),',')); end
        end
        open(joinpath(out,"trajectory.csv"),"w") do io
            println(io,"tick,id,x,z,state,energy,gut,sleepy")
            for row in samples; println(io,join(row,',')); end
        end
    end
    report
end
