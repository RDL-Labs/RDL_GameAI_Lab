# Diagnostic replay of frozen source. Identical rollout arithmetic, with trace only.
const RUN=abspath(ARGS[1])
include(joinpath(RUN,"source/experiments/lw_wildlife/animals_only.jl"))
const AUDIT_PREDATORS=Ref{Any}(nothing)
const AUDIT_LOCAL=Ref{Any}(nothing)
const AUDIT_TICK=Ref(0)
const AUDIT_ROWS=Any[]
function local_hunt_rollout(w,origin,forecast)
    actor=AUDIT_PREDATORS[]===nothing ? nothing : findfirst(p->p.visual.body.state==P.ATTACK && (p.visual.body.x,p.visual.body.z)==origin,AUDIT_PREDATORS[])
    steps=Any[];p=origin;first_step=nothing
    for k in 1:LOCAL_HUNT.horizon
        target=(forecast.x+k*forecast.vx,forecast.z+k*forecast.vz)
        dx=target[1]-p[1];dz=target[2]-p[2];distance=hypot(dx,dz)
        speed=min(LOCAL_HUNT.attack_speed,distance)
        q=distance>0 ? (p[1]+speed*dx/distance,p[2]+speed*dz/distance) : p
        clear=H.clear(w,p,q)
        actor!==nothing && push!(steps,(step=k,start=p,destination=q,predicted_prey=target,clear=clear,
            gap=hypot(q[1]-target[1],q[2]-target[2]),
            boundary=!(w.xmin+.25<=q[1]<=w.xmax-.25 && w.zmin+.25<=q[2]<=w.zmax-.25),
            water=H.material(w.phase,q...)==H.WATER || H.material(w.phase,(p[1]+q[1])/2,(p[2]+q[2])/2)==H.WATER,
            obstacles=[j for (j,o) in enumerate(w.obstacles) if H.RDLMigrationProbe.segment_hit(p,q,o,.25)]))
        if !clear
            actor!==nothing && record_abort(actor,forecast,steps,"blocked_forecast")
            return nothing
        end
        k==1 && (first_step=(heading=atan(dz,dx),speed=speed))
        hypot(q[1]-target[1],q[2]-target[2])<=LOCAL_HUNT.contact_radius && return first_step
        p=q
    end
    actor!==nothing && record_abort(actor,forecast,steps,"no_contact_in_horizon")
    nothing
end
function record_abort(actor,forecast,steps,reason)
    b=AUDIT_PREDATORS[][actor].visual.body;state=AUDIT_LOCAL[][actor]
    push!(AUDIT_ROWS,(actor=actor,tick=AUDIT_TICK[],target=b.target,remaining_ticks=b.timer,
        forecast=forecast,reason=reason,steps=steps,attack_start=isempty(state.records) ? nothing : last(state.records)))
end
function abort_main()
    expected=JSON3.read(read(joinpath(RUN,"result.json"),String))
    s,ps=animal_trial_world(;adult_rabbits=95);scents=PredatorScentWorld(2);minds=[PredatorMind(i) for i in 1:2]
    prey_scents=PreyScentWorld(2;cautious=true);local_hunts=[LocalHunt(i) for i in 1:2]
    AUDIT_PREDATORS[]=ps;AUDIT_LOCAL[]=local_hunts
    for t in 0:Int(expected.result.ticks)-1
        AUDIT_TICK[]=t
        animal_trial_step!(s,ps,t;scents,minds,prey_nutrition=1.5,prey_scents,motion_speed=true,local_hunts)
        if all(p->!p.alive,ps)
            for (i,p) in enumerate(ps)
                minds[i].trial===nothing || predator_mind_plan!(s,p,ps,minds[i],t+1;scents,index=i)
            end
            break
        end
        if (t+1)%17280==0
            report=animal_trial_report(s,ps;scents,minds)
            @assert JSON3.read(JSON3.write(report))==expected.result.daily[div(t+1,17280)]
        end
    end
    @assert JSON3.read(JSON3.write(animal_trial_report(s,ps;scents,minds)))==expected.result.final_state
    @assert JSON3.read(JSON3.write(local_hunt_report.(local_hunts)))==expected.result.local_hunt
    actual_events=[(actor=i,tick=e.tick) for (i,p) in enumerate(ps) for e in p.visual.events if e.kind=="abort_forecast"]
    @assert sort(actual_events;by=x->(x.actor,x.tick))==sort([(actor=r.actor,tick=r.tick) for r in AUDIT_ROWS];by=x->(x.actor,x.tick))
    write(ARGS[2],JSON3.write((source=basename(RUN),final_and_daily_match=true,aborts=AUDIT_ROWS)))
    println("MATCH aborts=",length(AUDIT_ROWS))
end
abort_main()
