# 暫定の種別/判断設定。統合実験のpursuits sidecar接続時のみON、nothingでOFF。
# 逃走は連続観測の遠ざかる速度から推定。獲物の内部FLEE状態は参照しない。
# 20tickの見積もり、離脱後20tickの再取得抑制は暫定。将来は経験による時間/文脈評価へ。
const PREDATOR_PURSUIT=(speed=.85,flee_radial=.1,horizon=20,release_ticks=20,
    distance_band=.5,burst_per_meter=.2,strain_per_meter=.002,
    gain_weight=2.,fatigue_weight=3.,residual_weight=1.,log_limit=256)
mutable struct PredatorPursuit
    loop::LW.BasicLoop
    observed::Dict{Int,NamedTuple}
    released::Dict{Int,Int}
    active::Any
    counts::Dict{String,Int}
    records::Vector{Any}
end
PredatorPursuit(i)=PredatorPursuit(LW.BasicLoop("predator:$i:pursuit";probabilistic=true,seed=20261107+i),
    Dict{Int,NamedTuple}(),Dict{Int,Int}(),nothing,Dict{String,Int}(),Any[])
pursuit_count!(p,k)=(p.counts[k]=get(p.counts,k,0)+1)
function pursuit_radial(p,b,o,t)
    prior=get(p.observed,o.id,nothing)
    prior===nothing && return nothing
    dt=t-prior.tick;0<dt<=LOCAL_HUNT.history_ticks || return nothing
    dx=o.x-b.x;dz=o.z-b.z;distance=hypot(dx,dz)
    distance<=0 && return 0.
    ((o.x-prior.x)*dx+(o.z-prior.z)*dz)/(dt*distance)
end
function configured_pursuit_close!(p,t,reason;distance=nothing,opportunity=false)
    p.active===nothing && return
    a=p.active;elapsed=t-a.tick
    expected=max(predator_pursuit_reach(),a.distance-a.closing*elapsed)
    residual=distance===nothing ? 0. : max(0.,distance-expected-PREDATOR_PURSUIT.distance_band)
    # Only the pursuit child's forecast receives this residual. No parent food credit.
    LW.resolve_method!(p.loop,p.loop.trial.source,residual>0 ? false : nothing,
        opportunity ? true : residual>0 ? false : nothing;creditable=false,
        goal_H_increment=residual,completion_reward=opportunity ? 0. : nothing)
    push!(p.records,(event="result",tick=t,target=a.target,reason=reason,elapsed=elapsed,
        expected_distance=expected,observed_distance=distance,residual=residual,H=p.loop.H))
    length(p.records)>PREDATOR_PURSUIT.log_limit && popfirst!(p.records)
    pursuit_count!(p,"end:"*reason);p.active=nothing
end
predator_pursuit_reach()=G.CAPTURE_WORLD.reach
function configured_pursuit_observe!(p,state,s,observations,t;physiology=nothing)
    b=s.predator.body;r=PREDATOR_PURSUIT
    radial=Dict(o.id=>pursuit_radial(p,b,o,t) for o in observations)
    for o in observations;p.observed[o.id]=(x=o.x,z=o.z,tick=t);end
    filter!(pair->t-last(pair).tick<=LOCAL_HUNT.history_ticks,p.observed)
    filter!(pair->last(pair)>t,p.released)
    # A newly observed stop can undo the temporary rejection before its timeout.
    for o in observations
        v=radial[o.id]
        v!==nothing && v<=r.flee_radial && delete!(p.released,o.id)
    end
    filtered=filter(o->!haskey(p.released,o.id),observations)
    if p.active!==nothing
        index=findfirst(o->o.id==p.active.target,filtered)
        o=index===nothing ? nothing : filtered[index]
        v=o===nothing ? nothing : radial[o.id]
        exhausted=physiology!==nothing && (physiology.body.burst<r.burst_per_meter*r.speed || physiology.body.strain>=1)
        if o===nothing
            configured_pursuit_close!(p,t,"unobserved_or_route_unavailable")
        elseif o.distance<=predator_pursuit_reach()
            configured_pursuit_close!(p,t,"capture_range";distance=o.distance,opportunity=true)
        elseif v!==nothing && v<=r.flee_radial
            configured_pursuit_close!(p,t,"prey_stopped";distance=o.distance)
        elseif exhausted || t-p.active.tick>=r.horizon
            configured_pursuit_close!(p,t,exhausted ? "body_limit" : "forecast_due";distance=o.distance)
        else
            b.target=o.id;b.seen_x=o.x;b.seen_z=o.z;b.expires=t+LOCAL_HUNT.history_ticks
            b.state=P.CHASE;b.heading=atan(o.z-b.z,o.x-b.x)
            state.movement_speed=r.speed;b.counts[b.state]+=1;pursuit_count!(p,"sprint_ticks")
            return filtered,true
        end
    end
    if isempty(filtered)
        if !isempty(observations)
            b.target=0;b.expires=t;b.state=P.SEARCH;b.pursuit=0
            P.decide!(b,filtered,t,s.predator.rng)
            return filtered,true
        end
        return filtered,false
    end
    index=findfirst(o->o.id==b.target,filtered)
    o=index===nothing ? filtered[argmin([o.distance for o in filtered])] : filtered[index]
    v=radial[o.id]
    (v===nothing || v<=r.flee_radial || o.distance<=predator_pursuit_reach()) && return filtered,false
    configured_local_wait_close!(state,"interrupted","fleeing_prey_decision")
    physical=physiology===nothing ? nothing : physiology.body
    fatigue=physical===nothing ? 0. : predator_recovery_need(physical)
    hunger=physical===nothing ? 0. : max(0.,(PREDATOR_ANIMAL_TRIAL.initial_food-physical.reserve)/PREDATOR_ANIMAL_TRIAL.initial_food)
    closing=max(0.,r.speed-v)
    required=max(0.,o.distance-predator_pursuit_reach())
    gain=min(required,closing*r.horizon)/max(r.distance_band,required)
    cost=(PREDATOR_ANIMAL_TRIAL.daily_food/PREDATOR_ANIMAL_TRIAL.day_ticks+
        PREDATOR_ANIMAL_TRIAL.move_food*r.speed)*r.horizon/PREDATOR_ANIMAL_TRIAL.initial_food
    rows=Any[LW.D("method"=>"abandon","question"=>"pursuit_progress","priority"=>r.fatigue_weight*fatigue+r.residual_weight*p.loop.H)]
    feasible=physical===nothing || (physical.reserve>0 && physical.strain<1 && physical.burst>=r.burst_per_meter*r.speed)
    feasible && push!(rows,LW.D("method"=>"pursue","question"=>"pursuit_progress",
        "priority"=>r.gain_weight*gain+hunger-r.fatigue_weight*fatigue-cost))
    choice=LW.choose_method!(p.loop,rows,p.loop.sequence+1)
    push!(p.records,(event="choice",tick=t,target=o.id,selected=choice["method"],distance=o.distance,
        radial_speed=v,closing=closing,expected_gain=gain,cost=cost,fatigue=fatigue,hunger=hunger,
        H=p.loop.H,probability=get(choice,"selection_probability",nothing),candidates=[(method=c["method"],priority=c["priority"]) for c in rows]))
    length(p.records)>r.log_limit && popfirst!(p.records)
    pursuit_count!(p,choice["method"])
    if choice["method"]=="abandon"
        LW.resolve_method!(p.loop,p.loop.trial.source,nothing,nothing;creditable=false,goal_H_increment=0)
        p.released[o.id]=t+r.release_ticks
        b.target=0;b.expires=t;b.state=P.SEARCH;b.pursuit=0
        P.decide!(b,empty(filtered),t,s.predator.rng)
    else
        p.active=(target=o.id,tick=t,distance=o.distance,closing=closing)
        b.target=o.id;b.seen_x=o.x;b.seen_z=o.z;b.expires=t+LOCAL_HUNT.history_ticks
        b.state=P.CHASE;b.heading=atan(o.z-b.z,o.x-b.x)
        state.movement_speed=r.speed;b.counts[b.state]+=1;pursuit_count!(p,"sprint_ticks")
    end
    filtered,true
end
function configured_pursuit_exert!(physical,moved)
    physical===nothing && return
    r=PREDATOR_PURSUIT
    physical.body=LW.RDLBody.exert(physical.body,0.,r.strain_per_meter*moved,r.burst_per_meter*moved)
end
pursuit_report(p)=(counts=copy(p.counts),loop=LW.loop_snapshot(p.loop),active=p.active,records=deepcopy(p.records))
