# 暫定固定・動物単独実験のみ。通常LWへ自動接続しない（既定OFF）。
# 600g/日、900g/成体は食料相当量の仮値。一括摂食で消化・死体を省略する。
# 縄張り中心は初期配置、視認した相手への防衛/撤退は距離勾配で決める。
# 将来は身体需要・経験MBによる選択と摂食/消化に置換。人への対応は未接続。
const PREDATOR_ANIMAL_TRIAL=(day_ticks=17280,daily_food=600.,move_food=.1,
    initial_food=900.,capacity=1800.,hunt_below=600.,adult_food=900.,
    minimum_size_fraction=.05,territory_radius=20.,rival_sight=12.,
    balance_atol=1e-7,balance_rtol=1e-10, # Diagnostic tolerance for cumulative Float64 sums.
    retreat_difference=.1,retreat_speed=.3,warning_duration_ticks=60,warning_cooldown_ticks=600)

mutable struct TrialPredator
    visual::G.WildlifePredator
    center::Tuple{Float64,Float64}
    food::Float64
    eaten::Float64
    spent::Float64
    discarded::Float64
    alive::Bool
    mode::Symbol
    ticks::Dict{Symbol,Int}
    encounters::Int
    last_rival::Bool
    warning_started::Int
    warning_blocked_until::Int
    warning_timeouts::Int
end
function configured_trial_predator(s,position,seed)
    visual=G.configured_wildlife_predator(s.world,s.animals,
        (predator_count=1,predator_position=position),seed)
    TrialPredator(visual,Tuple(position),PREDATOR_ANIMAL_TRIAL.initial_food,0.,0.,0.,true,
        :rest,Dict{Symbol,Int}(),0,false,-1,0,0)
end
trial_proxy(s,p)=(world=s.world,animals=s.animals,alive=s.alive,life=s.life,ticks=s.ticks,predator=p.visual)
function trial_visible_rival(s,p,others,t)
    body=p.visual.body;rule=PREDATOR_ANIMAL_TRIAL
    seen=nothing;nearest=Inf
    for other in others
        other===p && continue
        other.alive || continue
        rival=other.visual.body
        distance=hypot(body.x-rival.x,body.z-rival.z)
        bearing=atan(rival.z-body.z,rival.x-body.x)
        cover=H.grass_cover!(s.world,H.cell(s.world,rival.x,rival.z),t;body_height=G.WILDLIFE_PREDATOR.body_height)
        distance<=rule.rival_sight*G.AmbientVision.range_factor(:predator,G.AmbientVision.illumination(t))/(1+G.WILDLIFE_PREDATOR.cover_attenuation*cover)*P.field_factor(bearing-p.visual.gaze,false) &&
            distance<nearest && P.los(s.world,(body.x,body.z),(rival.x,rival.z)) || continue
        seen=other;nearest=distance
    end
    (actor=seen,distance=nearest)
end
function configured_trial_plan!(s,p,others,t; territory_evidence=nothing)
    rule=PREDATOR_ANIMAL_TRIAL;body=p.visual.body
    p.mode=:dead
    p.alive || return
    # 暫定固定: 威嚇は開始から60tickまで、終了後600tickは再開しない。
    # 視野から一瞬外れても期限を延長しない。将来は状況変化/身体需要による終了へ置換。
    if p.warning_started>=0 && t-p.warning_started>=rule.warning_duration_ticks
        p.warning_started=-1
        p.warning_blocked_until=t+rule.warning_cooldown_ticks
        p.warning_timeouts+=1
    end
    # All decisions use pre-movement positions. No unseen rival coordinates are used.
    seen=trial_visible_rival(s,p,others,t).actor
    seen!==nothing && !p.last_rival && (p.encounters+=1)
    p.last_rival=seen!==nothing
    if seen!==nothing && body.state!=P.ATTACK
        rival=seen.visual.body
        # The other animal's private center is never consulted.
        own_strength=max(0.,1-hypot(body.x-p.center[1],body.z-p.center[2])/rule.territory_radius)
        intruder_strength=max(0.,1-hypot(rival.x-p.center[1],rival.z-p.center[2])/rule.territory_radius)
        rival_response=territory_evidence===nothing ?
            (intruder_strength>own_strength+rule.retreat_difference || own_strength==0 ? :retreat : :warn) :
            (territory_evidence.own>territory_evidence.foreign+rule.retreat_difference ? :warn : :retreat)
        if rival_response==:retreat || t>=p.warning_blocked_until
            body.heading=atan(rival.z-body.z,rival.x-body.x)
            p.visual.gaze=P.turn_gaze(p.visual.gaze,body.heading)
            p.mode=rival_response
            p.mode==:warn && p.warning_started<0 && (p.warning_started=t)
            body.target=0;body.pursuit=0;body.state=P.REST;body.timer=0
            return
        end
    end
    if p.food>=rule.hunt_below && body.state!=P.ATTACK
        p.mode=:rest;body.state=P.REST;body.timer=0;body.target=0;body.pursuit=0
        p.visual.gaze=P.turn_gaze(p.visual.gaze,body.heading+G.WILDLIFE_PREDATOR.scan_amplitude*sin(t/G.WILDLIFE_PREDATOR.scan_period))
        return
    end
    p.mode=:hunt
    body.state==P.REST && (body.state=P.SEARCH;body.timer=0)
    G.configured_wildlife_predator_plan!(trial_proxy(s,p),t)
end
function configured_trial_advance!(s,p,t; scent_speed=0.,prey_nutrition=1.,search_speed=nothing,attack_speed=1.,movement_speed=nothing,probabilistic_capture=false,physiology=nothing)
    rule=PREDATOR_ANIMAL_TRIAL;body=p.visual.body
    p.ticks[p.mode]=get(p.ticks,p.mode,0)+1
    p.visual.previous_position=(body.x,body.z)
    p.alive || return
    previous_distance=body.distance;previous_captures=body.captures
    attacking=body.state==P.ATTACK
    if physiology!==nothing
        @assert physiology.body.reserve==p.food
        physical=physiology.body
        mobility=physical.strain<1 && physical.damage<1 && p.food>0
        if !mobility
            physiology.limited_ticks+=1
            search_speed=0.;movement_speed=0.;scent_speed=0.;attack_speed=0.
        end
        if attacking && (!mobility || physical.burst<PREDATOR_BODY.attack_burst)
            body.misses+=1;body.state=P.CHASE;body.timer=0;attacking=false
            push!(p.visual.events,(tick=t,kind="body_limited",id=body.target,reason="body_limited"))
        end
    end
    if p.mode==:hunt
        if search_speed!==nothing && body.state==P.SEARCH
            # 暫定固定: scent caution supplies slow search speed; no change to chase/attack.
            P.move!(s.world,body,search_speed)
        else
            G.configured_wildlife_predator_advance!(trial_proxy(s,p),t;attack_speed,movement_speed,probabilistic_capture)
        end
    elseif p.mode==:retreat
        body.heading+=pi;P.move!(s.world,body,physiology!==nothing && (physiology.body.strain>=1 || physiology.body.damage>=1) ? 0. : rule.retreat_speed)
    elseif p.mode in (:scent_return,:scent_avoid)
        P.move!(s.world,body,scent_speed)
    elseif p.mode in (:visit_food,:visit_rest)
        P.move!(s.world,body,scent_speed)
    end
    if body.captures>previous_captures
        victim=last(p.visual.events).id
        # Approximate volume from visible body height; not calibrated rabbit mass.
        fraction=clamp((G.rabbit_height(s,victim)/G.RABBIT_LIFE.adult_height)^3,rule.minimum_size_fraction,1.)
        # Trial-only nutrition multiplier (default 1); capacity and choice rules stay separate.
        meal=rule.adult_food*fraction*prey_nutrition
        accepted=min(meal,rule.capacity-p.food)
        p.food+=accepted;p.eaten+=accepted;p.discarded+=meal-accepted
        body.timer=0 # Replace the legacy fixed half-day rest with food balance.
    end
    expense=rule.daily_food/rule.day_ticks+rule.move_food*(body.distance-previous_distance)
    if physiology===nothing
        used=min(p.food,expense);p.food-=used;p.spent+=used
    else
        before_food=p.food;physical=physiology.body
        physical=LW.Body(physical.burst,physical.strain,p.food,physical.damage)
        physiology.body=LW.RDLBody.exert(physical,expense,0.)
        p.food=physiology.body.reserve;p.spent+=before_food-p.food
    end
    p.food<=0 && (p.alive=false)
    physiology!==nothing && predator_physiology_update!(physiology,p,body.distance-previous_distance,attacking,p.mode==:rest)
end
function trial_predator_report(p)
    balance_residual=PREDATOR_ANIMAL_TRIAL.initial_food+p.eaten-p.food-p.spent
    @assert isapprox(PREDATOR_ANIMAL_TRIAL.initial_food+p.eaten,p.food+p.spent;
        atol=PREDATOR_ANIMAL_TRIAL.balance_atol,rtol=PREDATOR_ANIMAL_TRIAL.balance_rtol)
    body=p.visual.body
    @assert body.attacks==body.captures+body.misses+(body.state==P.ATTACK ? 1 : 0)
    (alive=p.alive,food=p.food,eaten=p.eaten,spent=p.spent,discarded=p.discarded,balance_residual=balance_residual,
     captures=body.captures,attacks=body.attacks,encounters=p.encounters,
     warning_started=p.warning_started,warning_blocked_until=p.warning_blocked_until,warning_timeouts=p.warning_timeouts,
     ticks=copy(p.ticks),position=(body.x,body.z),center=p.center,
     prey_observations=p.visual.seen_by_rabbits,events=copy(p.visual.events))
end
