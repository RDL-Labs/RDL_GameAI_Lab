# 暫定固定: wildlife.predator_count=1 の時だけ既存の視覚・捕食FSMを接続（既定0）。
# 狙い: LWの草・障害物・繁殖個体に捕食圧を加える。人は獲物にしない。
# 最後に見た位置を追うが、接触の成否は世界側の幾何で判定する。
# 将来は空腹・獲物経験・巣などのMBに置換。休息時間は栄養モデルではない。
const WILDLIFE_PREDATOR=(sight=16.,cover_attenuation=.8,body_height=.6,
    scan_amplitude=pi/2,scan_period=12.,event_limit=128)

mutable struct WildlifePredator
    body::P.Predator
    rng::MersenneTwister
    gaze::Float64
    previous_position::Tuple{Float64,Float64}
    previous_prey::Vector{Tuple{Float64,Float64}}
    seen_by_rabbits::Int
    events::Vector{NamedTuple}
end

function configured_wildlife_predator(w,a,cfg,seed)
    predator_count=get(cfg,:predator_count,0)
    predator_count isa Integer && !(predator_count isa Bool) && predator_count in (0,1) ||
        error("wildlife.predator_count must be 0 or 1 in this prototype")
    predator_count==0 && return nothing
    predator=P.spawn(w) # Geometry-only starting point; does not inspect rabbit positions.
    if hasproperty(cfg,:predator_position)
        position=cfg.predator_position
        length(position)==2 && all(x->x isa Real && !(x isa Bool) && isfinite(x),position) || error("invalid predator position")
        H.clear(w,Tuple(position),Tuple(position)) || error("blocked predator position")
        predator.x,predator.z=Float64.(position)
    end
    WildlifePredator(predator,MersenneTwister(seed),predator.heading,(predator.x,predator.z),
        collect(zip(a.x,a.z)),0,NamedTuple[])
end

function configured_wildlife_predator_plan!(s,t)
    predator_state=s.predator;predator_state===nothing && return
    predator=predator_state.body;rule=WILDLIFE_PREDATOR
    desired=predator.target!=0 && t<predator.expires ? atan(predator.seen_z-predator.z,predator.seen_x-predator.x) :
        predator.heading+rule.scan_amplitude*sin(t/rule.scan_period)
    predator_state.gaze=P.turn_gaze(predator_state.gaze,desired)
    observations=NamedTuple{(:id,:x,:z,:distance),Tuple{Int,Float64,Float64,Float64}}[]
    if !(predator.state in (P.REST,P.RECOVER,P.ATTACK))
        for i in eachindex(s.alive)
            s.alive[i] || continue
            position=(s.animals.x[i],s.animals.z[i])
            moved=i<=length(predator_state.previous_prey) && position!=predator_state.previous_prey[i]
            tracked=predator.target==i && t<predator.expires
            cover=H.grass_cover!(s.world,H.cell(s.world,position...),t;body_height=rabbit_height(s,i))
            distance=hypot(position[1]-predator.x,position[2]-predator.z)
            factor=P.field_factor(atan(position[2]-predator.z,position[1]-predator.x)-predator_state.gaze,false)
            distance<=rule.sight/(1+rule.cover_attenuation*cover)*P.vision_factor(true,moved,tracked)*factor &&
                factor>0 && P.los(s.world,(predator.x,predator.z),position) || continue
            push!(observations,(id=i,x=position[1],z=position[2],distance=distance))
        end
    end
    P.decide!(predator,observations,t,predator_state.rng)
    resize!(predator_state.previous_prey,length(s.alive))
    for i in eachindex(s.alive);predator_state.previous_prey[i]=(s.animals.x[i],s.animals.z[i]);end
end

function configured_wildlife_predator_advance!(s,t)
    predator_state=s.predator;predator_state===nothing && return
    predator=predator_state.body
    predator_state.previous_position=(predator.x,predator.z)
    prior_captures=predator.captures
    P.advance!(s.world,predator,s.animals,s.alive,t,predator_state.rng,predator_state.events)
    if predator.captures>prior_captures && s.life!==nothing
        victim=last(predator_state.events).id
        if s.life.due[victim]>0
            s.life.lost_investment+=s.life.invested[victim];s.life.invested[victim]=0.
            s.life.due[victim]=0;s.life.litter[victim]=0;s.life.lost_pregnancies+=1
        end
    end
    length(predator_state.events)>WILDLIFE_PREDATOR.event_limit && popfirst!(predator_state.events)
end

function wildlife_predator_snapshot(s)
    s.predator===nothing && return nothing
    state=s.predator;predator=state.body
    @assert sum(predator.counts)==s.ticks
    @assert predator.attacks==predator.captures+predator.misses+(predator.state==P.ATTACK ? 1 : 0)
    @assert H.clear(s.world,(predator.x,predator.z),(predator.x,predator.z))
    (rule="configured-visual-predation-v1",position=(predator.x,predator.z),state=P.NAMES[predator.state],
     attacks=predator.attacks,captures=predator.captures,misses=predator.misses,blocked=predator.blocked,
     distance=predator.distance,state_ticks=copy(predator.counts),seen_by_rabbits=state.seen_by_rabbits,
     events=copy(state.events))
end
