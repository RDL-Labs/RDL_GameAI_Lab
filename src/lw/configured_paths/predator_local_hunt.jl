# 暫定固定・実験のみ既定OFF。観測位置履歴から速度予測、近距離のみ候補展開。
# 地形は既存H.clearによる正確な身体幅/水/境界判定を短距離で直接参照する近道。
# 未観測の獲物位置・速度は使わない。部分遮蔽率は未実装。
# 将来は地形観測MBからの不確かな予測へ置換。選択・成否更新は共通BasicLoop。
const LOCAL_HUNT=(radius=6.,velocity_cap=.7,history_ticks=20,horizon=3,attack_speed=1.,
    approach_speed=.35,side_angle=pi/3,contact_radius=.55,attack_priority=4.,
    approach_priority=2.,wait_priority=-1.,cost_weight=.2,future_attack_bonus=1.,expected_capture=.6,
    wait_forecast_ticks=20,withdraw_priority=0.,log_limit=128)
# 暫定の個体側事前見積もり。世界の確率係数とは独立。経験で文脈ごとに更新。
const CAPTURE_ESTIMATE=(near_distance=1.25,near_prior=.6,far_prior=.3,prior_samples=2.,weight=2.)
include("predator_water_approach.jl")
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
    probabilistic_capture::Bool
    capture_experience::Dict{String,Tuple{Int,Int}}
end
LocalHunt(i;probabilistic_capture=false)=LocalHunt(LW.BasicLoop("predator:$i:capture";probabilistic=true,seed=20261107+i),
    Dict{Int,NamedTuple}(),nothing,1.,nothing,Dict{String,Int}(),Any[],0,0,0.,nothing,0,0.,Any[],probabilistic_capture,Dict{String,Tuple{Int,Int}}())
function local_capture_estimate(state,origin,forecast)
    dx=forecast.x-origin[1];dz=forecast.z-origin[2];distance=hypot(dx,dz)
    approaching=dx*forecast.vx+dz*forecast.vz<=0
    near=distance<=CAPTURE_ESTIMATE.near_distance
    key=string(near ? "near" : "far",approaching ? ":closing" : ":leaving")
    samples,successes=get(state.capture_experience,key,(0,0))
    prior=near ? CAPTURE_ESTIMATE.near_prior : CAPTURE_ESTIMATE.far_prior
    (key=key,value=(successes+CAPTURE_ESTIMATE.prior_samples*prior)/(samples+CAPTURE_ESTIMATE.prior_samples))
end
function local_capture_opportunity(w,origin,forecast)
    target=(forecast.x,forecast.z)
    G.configured_capture_path(w,origin,target) || return nothing
    (heading=atan(target[2]-origin[2],target[1]-origin[1]),speed=min(LOCAL_HUNT.attack_speed,hypot(target[1]-origin[1],target[2]-origin[2])))
end
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
# 暫定固定: 局所狩猟ONでは経路の失敗を捕食全体へ転送せず、休止なしで再選択。
# 地形の正確な参照は従来同様。将来は観測MBの不確実な通行見積もりへ置換。
function configured_local_route_replan!(state,s,t,reason)
    b=s.predator.body
    b.misses+=1
    push!(s.predator.events,(tick=t,kind=reason,id=b.target))
    if state.selected!==nothing
        LW.resolve_method!(state.loop,state.loop.trial.source,false,nothing;creditable=false,goal_H_increment=0)
        state.selected=nothing
    end
    b.state=P.CHASE;b.timer=0
    state.counts[reason]=get(state.counts,reason,0)+1
end
function configured_local_hunt_plan!(state,s,observations,t;physiology=nothing)
    b=s.predator.body;rule=LOCAL_HUNT
    state.movement_speed=nothing;state.attack_speed=1.
    if b.state in (P.REST,P.RECOVER);return false;end
    if state.probabilistic_capture && b.state==P.ATTACK
        # Bounded physical attempt: one draw after the existing three-tick interval.
        # Update heading only from visible target; no future trajectory rollout.
        index=findfirst(o->o.id==b.target,observations)
        if index!==nothing
            o=observations[index];b.heading=atan(o.z-b.z,o.x-b.x)
            state.attack_speed=min(rule.attack_speed,o.distance)
        end
        b.counts[b.state]+=1;return true
    end
    observations,water_filtered=configured_predator_water_targets!(state,s,observations,t)
    if water_filtered && isempty(observations)
        # Consume the filtered observation here: returning false would let the
        # outer legacy selector immediately reacquire the rejected raw target.
        P.decide!(b,observations,t,s.predator.rng)
        return true
    end
    if isempty(observations)
        configured_local_wait_close!(state,"failed","target_unobserved")
        if b.state==P.ATTACK
            configured_local_route_replan!(state,s,t,"route_unseen")
        end
        if b.target!=0 && t<b.expires
            b.state=P.CHASE;b.heading=atan(b.seen_z-b.z,b.seen_x-b.x)
            state.movement_speed=rule.approach_speed;b.counts[b.state]+=1;return true
        end
        return false
    end
    o=observations[argmin([o.distance for o in observations])]
    if b.target!=0 || state.wait_trial!==nothing
        target=state.wait_trial===nothing ? b.target : state.wait_target
        index=findfirst(o->o.id==target,observations)
        if index===nothing
            if state.wait_trial!==nothing
                configured_local_wait_close!(state,"failed","target_unobserved")
                return false
            end
            b.state==P.ATTACK && configured_local_route_replan!(state,s,t,"route_unseen")
            if t<b.expires
                b.state=P.CHASE;b.heading=atan(b.seen_z-b.z,b.seen_x-b.x)
                state.movement_speed=rule.approach_speed;b.counts[b.state]+=1;return true
            end
        else
            o=observations[index]
        end
    end
    forecast=local_hunt_prediction(state,o,t)
    for seen in observations;state.memory[seen.id]=(x=seen.x,z=seen.z,tick=t);end
    filter!(pair->t-last(pair).tick<=rule.history_ticks,state.memory)
    if o.distance>rule.radius
        configured_local_wait_close!(state,"failed","target_left_local_range")
        b.state==P.ATTACK && configured_local_route_replan!(state,s,t,"route_out_of_range")
        b.target=o.id;b.seen_x=o.x;b.seen_z=o.z;b.expires=t+rule.history_ticks
        b.state=P.CHASE;b.heading=atan(o.z-b.z,o.x-b.x)
        state.movement_speed=rule.approach_speed;b.counts[b.state]+=1;return true
    end
    b.target=o.id;b.seen_x=o.x;b.seen_z=o.z;b.expires=t+rule.history_ticks
    origin=(b.x,b.z)
    attack=state.probabilistic_capture ? local_capture_opportunity(s.world,origin,forecast) : local_hunt_rollout(s.world,origin,forecast)
    if physiology!==nothing && (physiology.body.strain>=1 || physiology.body.burst<rule.horizon*PREDATOR_BODY.attack_burst)
        attack=nothing
    end
    estimate=state.probabilistic_capture ? local_capture_estimate(state,origin,forecast) : nothing
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
            # Failure to predict capture is not proof that the next step is impossible.
            angle=atan(o.z-b.z,o.x-b.x);speed=min(rule.attack_speed,o.distance)
            q=H.configured_boundary_step(s.world,origin,angle,speed)
            if H.clear(s.world,origin,q)
                b.heading=angle;state.attack_speed=speed
                state.counts["uncertain_continuation"]=get(state.counts,"uncertain_continuation",0)+1
                b.counts[b.state]+=1;return true
            end
            configured_local_route_replan!(state,s,t,"route_blocked")
        else
            b.heading=attack.heading;state.attack_speed=attack.speed
            b.counts[b.state]+=1;return true
        end
    end
    rows=Any[]
    attack!==nothing && push!(rows,LW.D("method"=>"attack","question"=>"capture","priority"=>rule.attack_priority-rule.cost_weight*o.distance+(estimate===nothing ? 0. : CAPTURE_ESTIMATE.weight*(estimate.value-rule.expected_capture)),
        "heading"=>attack.heading,"speed"=>attack.speed))
    heading=atan(o.z-b.z,o.x-b.x)
    for (name,offset) in (("approach",0.),("left",rule.side_angle),("right",-rule.side_angle),("withdraw",pi))
        angle=heading+offset;q=H.configured_boundary_step(s.world,origin,angle,rule.approach_speed)
        H.clear(s.world,origin,q) || continue
        future=state.probabilistic_capture ? local_capture_opportunity(s.world,q,forecast) : local_hunt_rollout(s.world,q,forecast)
        progress=o.distance-hypot(q[1]-o.x,q[2]-o.z)
        priority=name=="withdraw" ? rule.withdraw_priority : rule.approach_priority
        learning_gradient=estimate===nothing ? 0. : CAPTURE_ESTIMATE.weight*(local_capture_estimate(state,q,forecast).value-estimate.value)
        push!(rows,LW.D("method"=>name,"question"=>"local_position","priority"=>priority+progress+learning_gradient+(future===nothing ? 0. : rule.future_attack_bonus),"heading"=>angle,"speed"=>rule.approach_speed))
    end
    attack===nothing && push!(rows,LW.D("method"=>"wait","question"=>"capture_opportunity","priority"=>rule.wait_priority,"heading"=>heading,"speed"=>0.))
    state.selected=LW.choose_method!(state.loop,rows,state.loop.sequence+1)
    state.selected["target_id"]=o.id
    if estimate!==nothing
        state.selected["capture_context"]=estimate.key
        state.selected["capture_expected"]=estimate.value
    end
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
        if !p.alive || p.mode!=:hunt
            LW.resolve_method!(state.loop,source,nothing,nothing;creditable=false,goal_H_increment=0)
            state.selected=nothing;return
        end
        b.captures==state.last_captures && b.misses==state.last_misses && p.alive && return
        success=b.captures>state.last_captures
        if state.probabilistic_capture
            key=c["capture_context"];samples,successes=get(state.capture_experience,key,(0,0))
            state.capture_experience[key]=(samples+1,successes+Int(success))
            result_key=success ? "probability_capture" : "probability_miss"
            state.counts[result_key]=get(state.counts,result_key,0)+1
            if !isempty(p.visual.events) && hasproperty(last(p.visual.events),:reason)
                reason_key="capture_"*last(p.visual.events).reason
                state.counts[reason_key]=get(state.counts,reason_key,0)+1
            end
        end
        if success
            LW.resolve_prediction!(state.loop,source,get(c,"capture_expected",LOCAL_HUNT.expected_capture),1.;fulfilled=true)
        else
            LW.resolve_method!(state.loop,source,false,nothing;creditable=false,goal_H_increment=0)
            # Physical misses/escape/blocked end this route, not the hunt. No synthetic fatigue.
            b.state=P.CHASE;b.timer=0;b.target=get(c,"target_id",b.target)
            state.counts["route_retry"]=get(state.counts,"route_retry",0)+1
        end
    else
        moved=c["speed"]==0 || b.distance>state.start_distance
        LW.resolve_method!(state.loop,source,moved,nothing;creditable=false,goal_H_increment=0)
    end
    state.selected=nothing
end
local_hunt_report(state)=(counts=copy(state.counts),memory=length(state.memory),loop=LW.loop_snapshot(state.loop),records=copy(state.records),wait_records=deepcopy(state.wait_records),active_wait=deepcopy(state.wait_trial),probabilistic_capture=state.probabilistic_capture,capture_experience=copy(state.capture_experience))
