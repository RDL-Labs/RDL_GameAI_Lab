# Read-only diagnostics injected into the frozen selection implementation.
const AUDIT_ROOT=abspath(ARGS[1])
include(joinpath(AUDIT_ROOT,"source/experiments/lw_wildlife/animals_only.jl"))
Core.eval(LW,:(const AUDIT_SELECTION_CALLBACK=Ref{Any}(nothing)))
source=read(joinpath(AUDIT_ROOT,"source/src/lw/decision/basic_loop.jl"),String)
first_index=findfirst("function choose_method!",source).start
end_index=findnext("function resolve_method!",source,first_index).start
selection_source=source[first_index:prevind(source,end_index)]
selection_source=replace(selection_source,"    selected=if probabilities===nothing"=>
    "    AUDIT_SELECTION_CALLBACK[]===nothing || AUDIT_SELECTION_CALLBACK[](s,candidates,probabilities)\n    selected=if probabilities===nothing")
Base.include_string(LW,selection_source,"audited_frozen_choose_method")
function audit_case(code,actor)
    run=joinpath(AUDIT_ROOT,"seed-$code-inherited")
    result=JSON3.read(read(joinpath(run,"result.json"),String))
    death_day=result.summary.lifetimes_days[actor]
    start_day=max(1,floor(Int,death_day)-2);end_day=ceil(Int,death_day)
    s,ps,scents,minds,prey_scents,locals=deserialize(joinpath(run,"day-$start_day.jls"))
    tick=Ref(s.ticks);pending=Ref{Any}(nothing);choices=Any[];events=Any[]
    buckets=Dict{String,Dict{Symbol,Int}}();hunt=Dict("ticks"=>0,"tracked_ticks"=>0,"nearby_truth_ticks"=>0)
    p=ps[actor];m=minds[actor];b=p.visual.body
    LW.AUDIT_SELECTION_CALLBACK[]=(loop,candidates,probabilities)->begin
        loop===m.loop || return
        pending[]=(tick=tick[],food=p.food,H=loop.H,places=length(m.places),
            rows=[(method=c["method"],action=c["action"],priority=c["priority"],probability=probabilities[i],
                reward=loop.methods[c["method"]].reward,method_H=loop.methods[c["method"]].H,
                failure_repulsion=LW.failure_repulsion(loop.methods[c["method"]])) for (i,c) in enumerate(candidates)])
    end
    for t in s.ticks:end_day*17280-1
        tick[]=t;pending[]=nothing;food=p.food;alive=p.alive;captures=b.captures;misses=b.misses
        animal_trial_step!(s,ps,t;scents,minds,prey_nutrition=1.5,prey_scents,motion_speed=true,local_hunts=locals)
        if alive
            band=food<300 ? "below300" : food<600 ? "300to600" : "above600"
            bucket=get!(()->Dict{Symbol,Int}(),buckets,band);bucket[p.mode]=get(bucket,p.mode,0)+1
            if p.mode==:hunt
                hunt["ticks"]+=1
                b.target!=0 && t<b.expires && (hunt["tracked_ticks"]+=1)
                any(i->s.alive[i] && hypot(s.animals.x[i]-b.x,s.animals.z[i]-b.z)<LOCAL_HUNT.radius,eachindex(s.alive)) && (hunt["nearby_truth_ticks"]+=1)
            end
        end
        pending[]===nothing || push!(choices,merge(pending[],(selected=m.selected["method"],action=m.selected["action"],forecast=m.selected["forecast"])))
        if b.captures>captures || b.misses>misses
            push!(events,(event=last(p.visual.events),food_before=food,food_after=p.food))
        end
        if alive && !p.alive
            push!(events,(death_tick=t,food_before=food,mode=p.mode,position=(b.x,b.z)))
        end
        if (t+1)%17280==0
            @assert JSON3.read(JSON3.write(animal_trial_report(s,ps;scents,minds)))==result.result.daily[div(t+1,17280)]
        end
    end
    expected=deserialize(joinpath(run,"day-$end_day.jls"))
    @assert JSON3.read(JSON3.write(predator_mind_report.(minds)))==JSON3.read(JSON3.write(predator_mind_report.(expected[4])))
    @assert JSON3.read(JSON3.write(local_hunt_report.(locals)))==JSON3.read(JSON3.write(local_hunt_report.(expected[6])))
    LW.AUDIT_SELECTION_CALLBACK[]=nothing
    (seed=code,actor=actor,death_day=death_day,matched_days=collect(start_day+1:end_day),
        choices=choices,events=events,buckets=buckets,hunt=hunt)
end
rows=Any[]
for code in (105,103,102)
    row=audit_case(code,2);push!(rows,row)
    println("MATCH seed=",code," choices=",length(row.choices));flush(stdout)
end
write(ARGS[2],JSON3.write((cases=rows,note="nearby_truth is diagnostic world proximity, not actor knowledge; no policy/RNG changes")))
