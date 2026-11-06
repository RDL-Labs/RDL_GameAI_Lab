# Read-only diagnostics around the frozen experiment's exact update order.
# No observation/choice mutation, random draws, or changed collision rules.
const RUN=abspath(ARGS[1])
include(joinpath(RUN,"source/experiments/lw_wildlife/animals_only.jl"))
function audit_attacks()
    expected=JSON3.read(read(joinpath(RUN,"result.json"),String))
    s,predators=animal_trial_world(;adult_rabbits=Int(expected.conditions.adult_rabbits))
    scents=PredatorScentWorld(2);minds=[PredatorMind(i) for i in 1:2]
    rows=Any[];pending=[Any[] for _ in 1:2]
    for t in 0:Int(expected.completion.executed_ticks)-1
        configured_scent_tick!(scents,predators,t)
        for (i,p) in enumerate(predators)
            predator_mind_plan!(s,p,predators,minds[i],t;scents,index=i)
        end
        G.prepare!(s,Tuple{Float64,Float64}[],t;additional_predators=[p.visual for p in predators],
            additional_predator_alive=[p.alive for p in predators])
        G.advance!(s,t)
        for i in (iseven(t) ? eachindex(predators) : reverse(eachindex(predators)))
            p=predators[i];b=p.visual.body;w=s.world
            event_count=length(p.visual.events)
            if p.alive && p.mode==:hunt && b.state==P.ATTACK
                start=(b.x,b.z);dest=(b.x+cos(b.heading),b.z+sin(b.heading))
                rocks=[(index=j,x=o.x,z=o.z,radius=o.radius) for (j,o) in enumerate(w.obstacles)
                    if H.RDLMigrationProbe.segment_hit(start,dest,o,.25)]
                boundary=!(w.xmin+.25<=dest[1]<=w.xmax-.25 && w.zmin+.25<=dest[2]<=w.zmax-.25)
                water=H.material(w.phase,dest...)==H.WATER || H.material(w.phase,(start[1]+dest[1])/2,(start[2]+dest[2])/2)==H.WATER
                target=b.target
                push!(pending[i],(tick=t,start=start,destination=dest,heading=b.heading,timer=b.timer,
                    food=p.food,target=target,seen=(b.seen_x,b.seen_z),
                    target_position=target>0 ? (s.animals.x[target],s.animals.z[target]) : nothing,
                    boundary=boundary,water=water,obstacles=rocks,clear=H.clear(w,start,dest)))
            end
            configured_trial_advance!(s,p,t;prey_nutrition=Float64(expected.conditions.prey_nutrition),scent_speed=PREDATOR_COGNITION.move_speed)
            if length(p.visual.events)>event_count
                push!(rows,(actor=i,event=last(p.visual.events),steps=copy(pending[i])))
                empty!(pending[i])
            end
        end
        if all(p->!p.alive,predators)
            for (i,p) in enumerate(predators)
                minds[i].trial===nothing || predator_mind_plan!(s,p,predators,minds[i],t+1;scents,index=i)
            end
        end
        # Original daily snapshot also realizes lazy grass growth; preserve it.
        (t+1)%17280==0 && animal_trial_report(s,predators;scents,minds)
    end
    report=animal_trial_report(s,predators;scents,minds)
    write(ARGS[2]*".replay-final.json",JSON3.write(report))
    @assert JSON3.read(JSON3.write(report))==expected.final_state "Replay diverged"
    write(ARGS[2],JSON3.write((source=basename(RUN),final_state_matches=true,attacks=rows)))
    println("MATCH attacks=",length(rows))
end
audit_attacks()
