# Replay the saved day 2 through day 6 without changing choices or RNG.
const RUN=abspath(ARGS[1])
include(joinpath(RUN,"source/experiments/lw_wildlife/animals_only.jl"))
function audit_death()
    s,predators,scents,minds,prey_scents=deserialize(joinpath(RUN,"day-2.jls"))
    expected=JSON3.read(read(joinpath(RUN,"result.json"),String))
    selections=Any[];events=Any[];buckets=Dict{String,Dict{Symbol,Int}}();samples=Any[]
    attack_start=nothing
    for t in s.ticks:6*17280-1
        p=predators[2];m=minds[2];b=p.visual.body
        prior_sequence=m.loop.sequence;prior_events=length(p.visual.events)
        food_before=p.food;H_before=m.loop.H;prior_attacks=b.attacks
        animal_trial_step!(s,predators,t;scents,minds,prey_nutrition=1.5,prey_scents,motion_speed=true)
        if b.attacks>prior_attacks
            origin=p.visual.previous_position;seen=(b.seen_x,b.seen_z)
            attack_start=(tick=t,position=origin,seen=seen,distance=hypot(seen[1]-origin[1],seen[2]-origin[2]),
                sight_clear=P.los(s.world,origin,seen),body_path_clear=H.clear(s.world,origin,seen))
        end
        if p.mode!=:dead
            band=food_before<300 ? "below300" : food_before<600 ? "300to600" : "above600"
            key=string(div(t,17280)+1,":",band)
            bucket=get!(()->Dict{Symbol,Int}(),buckets,key);bucket[p.mode]=get(bucket,p.mode,0)+1
        end
        if m.loop.sequence!=prior_sequence
            push!(selections,(tick=t,food_before=food_before,H_before=H_before,H_after=m.loop.H,
                selected=deepcopy(m.selected),hunt_estimate=get(m.estimates,"hunt",nothing)))
        end
        if length(p.visual.events)>prior_events
            event=last(p.visual.events);geometry=nothing
            if event.kind=="blocked"
                # Failed move! leaves position unchanged and rotates heading by pi/2.
                start=(b.x,b.z);heading=b.heading-pi/2;dest=(b.x+cos(heading),b.z+sin(heading));w=s.world
                geometry=(start=start,destination=dest,last_seen=(b.seen_x,b.seen_z),
                    sight_to_last_seen=P.los(w,start,(b.seen_x,b.seen_z)),
                    sight_along_step=P.los(w,start,dest),
                    boundary=!(w.xmin+.25<=dest[1]<=w.xmax-.25 && w.zmin+.25<=dest[2]<=w.zmax-.25),
                    water=H.material(w.phase,dest...)==H.WATER || H.material(w.phase,(start[1]+dest[1])/2,(start[2]+dest[2])/2)==H.WATER,
                    obstacles=[j for (j,o) in enumerate(w.obstacles) if H.RDLMigrationProbe.segment_hit(start,dest,o,.25)])
            end
            push!(events,(event=event,food=food_before,attack_start=attack_start,geometry=geometry))
        end
        if t%600==0 && p.alive
            push!(samples,(tick=t,food=p.food,mode=p.mode,position=(b.x,b.z),H=m.loop.H,
                caution=prey_scents.caution_ticks[2],signal=prey_scents.observed[2]))
        end
        if (t+1)%17280==0
            report=animal_trial_report(s,predators;scents,minds)
            @assert JSON3.read(JSON3.write(report))==expected.result.daily[div(t+1,17280)]
        end
    end
    write(ARGS[2],JSON3.write((matched_days=[3,4,5,6],selections=selections,events=events,buckets=buckets,samples=samples)))
    println("MATCH days 3..6 selections=",length(selections))
end
audit_death()
