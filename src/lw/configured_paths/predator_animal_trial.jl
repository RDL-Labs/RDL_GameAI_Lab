# 暫定固定・動物単独実験のみ。通常LWへ自動接続しない（既定OFF）。
# 600g/日、900g/成体は食料相当量の仮値。一括摂食で消化・死体を省略する。
# 縄張り中心は初期配置、視認した相手への防衛/撤退は距離勾配で決める。
# 将来は身体需要・経験MBによる選択と摂食/消化に置換。人への対応は未接続。
const PREDATOR_ANIMAL_TRIAL=(day_ticks=17280,daily_food=600.,move_food=.1,
    initial_food=900.,capacity=1800.,hunt_below=600.,adult_food=900.,
    minimum_size_fraction=.05,territory_radius=20.,rival_sight=12.,
    retreat_difference=.1,retreat_speed=.3)

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
end
function configured_trial_predator(s,position,seed)
    visual=G.configured_wildlife_predator(s.world,s.animals,
        (predator_count=1,predator_position=position),seed)
    TrialPredator(visual,Tuple(position),PREDATOR_ANIMAL_TRIAL.initial_food,0.,0.,0.,true,
        :rest,Dict{Symbol,Int}(),0,false)
end
trial_proxy(s,p)=(world=s.world,animals=s.animals,alive=s.alive,life=s.life,ticks=s.ticks,predator=p.visual)
function configured_trial_plan!(s,p,others,t)
    rule=PREDATOR_ANIMAL_TRIAL;body=p.visual.body
    p.mode=:dead
    p.alive || return
    # All decisions use pre-movement positions. No unseen rival coordinates are used.
    seen=nothing;nearest=Inf
    for other in others
        other===p && continue
        other.alive || continue
        rival=other.visual.body
        distance=hypot(body.x-rival.x,body.z-rival.z)
        bearing=atan(rival.z-body.z,rival.x-body.x)
        cover=H.grass_cover!(s.world,H.cell(s.world,rival.x,rival.z),t;body_height=G.WILDLIFE_PREDATOR.body_height)
        distance<=rule.rival_sight/(1+G.WILDLIFE_PREDATOR.cover_attenuation*cover)*P.field_factor(bearing-p.visual.gaze,false) &&
            distance<nearest && P.los(s.world,(body.x,body.z),(rival.x,rival.z)) || continue
        seen=other;nearest=distance
    end
    seen!==nothing && !p.last_rival && (p.encounters+=1)
    p.last_rival=seen!==nothing
    if seen!==nothing && body.state!=P.ATTACK
        rival=seen.visual.body
        # The other animal's private center is never consulted.
        own_strength=max(0.,1-hypot(body.x-p.center[1],body.z-p.center[2])/rule.territory_radius)
        intruder_strength=max(0.,1-hypot(rival.x-p.center[1],rival.z-p.center[2])/rule.territory_radius)
        body.heading=atan(rival.z-body.z,rival.x-body.x)
        p.visual.gaze=P.turn_gaze(p.visual.gaze,body.heading)
        p.mode=intruder_strength>own_strength+rule.retreat_difference || own_strength==0 ? :retreat : :warn
        body.target=0;body.pursuit=0;body.state=P.REST;body.timer=0
        return
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
function configured_trial_advance!(s,p,t)
    rule=PREDATOR_ANIMAL_TRIAL;body=p.visual.body
    p.ticks[p.mode]=get(p.ticks,p.mode,0)+1
    p.visual.previous_position=(body.x,body.z)
    p.alive || return
    previous_distance=body.distance;previous_captures=body.captures
    if p.mode==:hunt
        G.configured_wildlife_predator_advance!(trial_proxy(s,p),t)
    elseif p.mode==:retreat
        body.heading+=pi;P.move!(s.world,body,rule.retreat_speed)
    end
    if body.captures>previous_captures
        victim=last(p.visual.events).id
        # Approximate volume from visible body height; not calibrated rabbit mass.
        fraction=clamp((G.rabbit_height(s,victim)/G.RABBIT_LIFE.adult_height)^3,rule.minimum_size_fraction,1.)
        meal=rule.adult_food*fraction
        accepted=min(meal,rule.capacity-p.food)
        p.food+=accepted;p.eaten+=accepted;p.discarded+=meal-accepted
        body.timer=0 # Replace the legacy fixed half-day rest with food balance.
    end
    expense=rule.daily_food/rule.day_ticks+rule.move_food*(body.distance-previous_distance)
    used=min(p.food,expense);p.food-=used;p.spent+=used
    p.food<=0 && (p.alive=false)
end
function trial_predator_report(p)
    @assert isapprox(PREDATOR_ANIMAL_TRIAL.initial_food+p.eaten,p.food+p.spent;atol=1e-7)
    body=p.visual.body
    @assert body.attacks==body.captures+body.misses+(body.state==P.ATTACK ? 1 : 0)
    (alive=p.alive,food=p.food,eaten=p.eaten,spent=p.spent,discarded=p.discarded,
     captures=body.captures,attacks=body.attacks,encounters=p.encounters,
     ticks=copy(p.ticks),position=(body.x,body.z),center=p.center,
     prey_observations=p.visual.seen_by_rabbits,events=copy(p.visual.events))
end
