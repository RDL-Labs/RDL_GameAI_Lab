# 暫定固定・実験のみ既定OFF。観測位置履歴から速度予測、近距離のみ候補展開。
# 地形は既存H.clearによる正確な身体幅/水/境界判定を短距離で直接参照する近道。
# 未観測の獲物位置・速度は使わない。部分遮蔽率は未実装。
# 将来は地形観測MBからの不確かな予測へ置換。選択・成否更新は共通BasicLoop。
const LOCAL_HUNT=(radius=6.,velocity_cap=.7,history_ticks=20,horizon=3,attack_speed=1.,
    approach_speed=.35,side_angle=pi/3,contact_radius=.55,attack_priority=4.,
    approach_priority=2.,wait_priority=-1.,cost_weight=.2,future_attack_bonus=1.,expected_capture=.6,
    wait_forecast_ticks=20,withdraw_priority=0.,log_limit=128)
mutable struct LocalHunt
    loop::LW.BasicLoop
    memory::Dict{Int,NamedTuple}
    selected::Any
    attack_speed::Float64
    movement_speed::Any
    counts::Dict{String,Int}
    records::Vector{Any}
    last_captures::Int
    last_misses::Int
    start_distance::Float64
    wait_trial::Any
    wait_target::Int
    wait_spent::Float64
    wait_records::Vector{Any}
end
LocalHunt(i)=LocalHunt(LW.BasicLoop("predator:$i:capture";probabilistic=true,seed=20261107+i),
    Dict{Int,NamedTuple}(),nothing,1.,nothing,Dict{String,Int}(),Any[],0,0,0.,nothing,0,0.,Any[])
function configured_local_wait_close!(state,status,reason)
    state.wait_trial===nothing && return
    child=state.wait_trial
    LW.action_trial_close!(child,status,LW.D("reason"=>reason))
    # Local opportunity is not capture or food. Parent H/reward is untouched.
    evidence=status=="interrupted" ? nothing : status=="achieved"
    LW.resolve_method!(state.loop,state.loop.trial.source,evidence,nothing;creditable=false,goal_H_increment=0)
    key="wait_"*status;state.counts[key]=get(state.counts,key,0)+1
    push!(state.wait_records,(target=state.wait_target,status=status,reason=reason,trial=deepcopy(child)))
    length(state.wait_records)>LOCAL_HUNT.log_limit && popfirst!(state.wait_records)
    state.wait_trial=nothing;state.selected=nothing
end
function local_hunt_prediction(state,o,t)
    old=get(state.memory,o.id,nothing);vx=0.;vz=0.
    if old!==nothing && 0<t-old.tick<=LOCAL_HUNT.history_ticks
        vx=(o.x-old.x)/(t-old.tick);vz=(o.z-old.z)/(t-old.tick)
        speed=hypot(vx,vz);scale=speed>LOCAL_HUNT.velocity_cap ? LOCAL_HUNT.velocity_cap/speed : 1.
        vx*=scale;vz*=scale
    end
    (x=o.x,z=o.z,vx=vx,vz=vz)
end
function local_hunt_rollout(w,origin,forecast)
    p=origin;first_step=nothing
    for k in 1:LOCAL_HUNT.horizon
        target=(forecast.x+k*forecast.vx,forecast.z+k*forecast.vz)
        dx=target[1]-p[1];dz=target[2]-p[2];distance=hypot(dx,dz)
        speed=min(LOCAL_HUNT.attack_speed,distance)
        q=distance>0 ? (w.boundary_gradient ? H.configured_boundary_step(w,p,atan(dz,dx),speed) : (p[1]+speed*dx/distance,p[2]+speed*dz/distance)) : p
        H.clear(w,p,q) || return nothing
        k==1 && (first_step=(heading=atan(dz,dx),speed=speed))
        hypot(q[1]-target[1],q[2]-target[2])<=LOCAL_HUNT.contact_radius && return first_step
        p=q
    end
    nothing
end
function configured_local_hunt_plan!(state,s,observations,t)
    b=s.predator.body;rule=LOCAL_HUNT
    state.movement_speed=nothing;state.attack_speed=1.
    if b.state in (P.REST,P.RECOVER);return false;end
    if isempty(observations)
        configured_local_wait_close!(state,"failed","target_unobserved")
        if b.state==P.ATTACK
            b.misses+=1;push!(s.predator.events,(tick=t,kind="abort_unseen",id=b.target));P.recover!(b)
            b.counts[b.state]+=1;return true
        end
        return false
    end
    o=observations[argmin([o.distance for o in observations])]
    if b.state==P.ATTACK || state.wait_trial!==nothing
        target=state.wait_trial===nothing ? b.target : state.wait_target
        index=findfirst(o->o.id==target,observations)
        if index===nothing
            if state.wait_trial!==nothing
                configured_local_wait_close!(state,"failed","target_unobserved")
                return false
            end
            b.misses+=1;push!(s.predator.events,(tick=t,kind="abort_unseen",id=b.target));P.recover!(b)
            b.counts[b.state]+=1;return true
        end
        o=observations[index]
    end
    forecast=local_hunt_prediction(state,o,t)
    for seen in observations;state.memory[seen.id]=(x=seen.x,z=seen.z,tick=t);end
    filter!(pair->t-last(pair).tick<=rule.history_ticks,state.memory)
    if o.distance>rule.radius
        configured_local_wait_close!(state,"failed","target_left_local_range")
        return false
    end
    b.target=o.id;b.seen_x=o.x;b.seen_z=o.z;b.expires=t+rule.history_ticks
    origin=(b.x,b.z);attack=local_hunt_rollout(s.world,origin,forecast)
    state.counts["evaluations"]=get(state.counts,"evaluations",0)+1
    if state.wait_trial!==nothing
        if attack!==nothing
            configured_local_wait_close!(state,"achieved","capture_opportunity_observed")
        else
            b.state=P.CHASE;b.heading=atan(o.z-b.z,o.x-b.x);state.movement_speed=0.
            b.counts[b.state]+=1;return true
        end
    end
    if b.state==P.ATTACK
        if attack===nothing
            b.misses+=1;push!(s.predator.events,(tick=t,kind="abort_forecast",id=b.target));P.recover!(b)
        else
            b.heading=attack.heading;state.attack_speed=attack.speed
        end
        b.counts[b.state]+=1;return true
    end
    rows=Any[]
    attack!==nothing && push!(rows,LW.D("method"=>"attack","question"=>"capture","priority"=>rule.attack_priority-rule.cost_weight*o.distance,
        "heading"=>attack.heading,"speed"=>attack.speed))
    heading=atan(o.z-b.z,o.x-b.x)
    for (name,offset) in (("approach",0.),("left",rule.side_angle),("right",-rule.side_angle),("withdraw",pi))
        angle=heading+offset;q=H.configured_boundary_step(s.world,origin,angle,rule.approach_speed)
        H.clear(s.world,origin,q) || continue
        future=local_hunt_rollout(s.world,q,forecast)
        progress=o.distance-hypot(q[1]-o.x,q[2]-o.z)
        priority=name=="withdraw" ? rule.withdraw_priority : rule.approach_priority
        push!(rows,LW.D("method"=>name,"question"=>"local_position","priority"=>priority+progress+(future===nothing ? 0. : rule.future_attack_bonus),"heading"=>angle,"speed"=>rule.approach_speed))
    end
    attack===nothing && push!(rows,LW.D("method"=>"wait","question"=>"capture_opportunity","priority"=>rule.wait_priority,"heading"=>heading,"speed"=>0.))
    state.selected=LW.choose_method!(state.loop,rows,state.loop.sequence+1)
    c=state.selected;name=c["method"];state.counts[name]=get(state.counts,name,0)+1
    state.start_distance=b.distance;state.last_captures=b.captures;state.last_misses=b.misses
    b.heading=c["heading"]
    if name=="attack"
        b.state=P.ATTACK;b.timer=rule.horizon;b.attacks+=1;state.attack_speed=c["speed"]
    else
        b.state=P.CHASE;state.movement_speed=c["speed"]
        if name=="wait"
            # 暫定固定の初期見積もり20tick。試行中は固定し選び直して延長しない。
            state.wait_trial=LW.action_trial(state.loop.trial.source,"wait","capture_opportunity",rule.wait_forecast_ticks)
            state.wait_target=o.id;state.wait_spent=NaN
        end
    end
    push!(state.records,(tick=t,selected=name,target=o.id,distance=o.distance,forecast=forecast,
        candidates=[(method=c["method"],priority=c["priority"]) for c in rows]))
    length(state.records)>rule.log_limit && popfirst!(state.records)
    b.counts[b.state]+=1;true
end
function configured_local_hunt_finish!(state,p)
    state.selected===nothing && return
    b=p.visual.body;c=state.selected;source=state.loop.trial.source
    if c["method"]=="wait"
        if !p.alive || p.mode!=:hunt
            configured_local_wait_close!(state,"interrupted",!p.alive ? "death" : "parent_changed")
            return
        end
        energy=isnan(state.wait_spent) ? 0. : max(0.,p.spent-state.wait_spent)
        state.wait_spent=p.spent
        LW.action_trial_step!(state.wait_trial,1.,energy)
        state.counts["wait_ticks"]=get(state.counts,"wait_ticks",0)+1
        state.wait_trial["elapsed"]>=LOCAL_HUNT.wait_forecast_ticks && configured_local_wait_close!(state,"failed","forecast_elapsed_without_opportunity")
        return
    elseif c["method"]=="attack"
        b.captures==state.last_captures && b.misses==state.last_misses && p.alive && return
        success=b.captures>state.last_captures
        LW.resolve_prediction!(state.loop,source,LOCAL_HUNT.expected_capture,success ? 1. : 0.;fulfilled=success)
    else
        moved=c["speed"]==0 || b.distance>state.start_distance
        LW.resolve_method!(state.loop,source,moved,nothing;creditable=false,goal_H_increment=0)
    end
    state.selected=nothing
end
local_hunt_report(state)=(counts=copy(state.counts),memory=length(state.memory),loop=LW.loop_snapshot(state.loop),records=copy(state.records),wait_records=deepcopy(state.wait_records),active_wait=deepcopy(state.wait_trial))
