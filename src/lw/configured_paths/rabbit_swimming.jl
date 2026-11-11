# 暫定固定：RabbitSwimmingPolicyで明示ON、通常の方策ではOFF。
# 川形状/着岸点は世界から直接取得、対岸の草・他個体の真値は選択に使わない。
# 岸辺の探索中に低い事前重みで候補化。空腹/既存Hで重みが増え、近傍草で下がる。
# 水中は着岸まで継続（流速・溺死・体温は未実装）。将来は岸の観測と身体MBへ置換。
const RABBIT_SWIMMING=(bank_range=6.,landing_margin=1.,swim_speed=.10,land_speed=.2,
    swim_cost=.036,land_cost=.012,energy_margin=1.5,reserve=5.,
    interval=64,prior_penalty=5.,hunger_reference=65.,hunger_scale=15.,
    H_scale=4.,grass_weight=1.,body_margin=.25)
mutable struct RabbitSwimmingPolicy
    base::RabbitApproachPolicy
    trips::Dict{Int,NamedTuple}
    counts::Dict{Symbol,Int}
end
RabbitSwimmingPolicy(base=RabbitApproachPolicy())=RabbitSwimmingPolicy(base,Dict{Int,NamedTuple}(),Dict(k=>0 for k in (:selected,:arrived,:swim_ticks,:interrupted)))
choose_state(p::RabbitSwimmingPolicy,o)=choose_state(p.base,o)
target!(w,a,i,t,p::RabbitSwimmingPolicy)=target!(w,a,i,t,p.base)
approach_feedback!(p::RabbitSwimmingPolicy,w,a,i,t)=haskey(p.trips,i) ? nothing : approach_feedback!(p.base,w,a,i,t)
configured_rabbit_swim_state(p,w,a,i,state,overrides)=state
function configured_rabbit_swim_state(p::RabbitSwimmingPolicy,w,a,i,state,overrides)
    if haskey(p.trips,i) && material(w.phase,a.x[i],a.z[i])!=WATER && overrides!==nothing && overrides[i]!=0
        delete!(p.trips,i);p.counts[:interrupted]+=1
    end
    haskey(p.trips,i) ? SEARCH : state
end
rabbit_approach_base(p::RabbitApproachPolicy)=p
rabbit_approach_base(p::RabbitSwimmingPolicy)=p.base
configured_rabbit_swim_step!(p,w,a,i,t,overrides)=false
function configured_rabbit_swim_clear(w,origin,destination)
    r=RABBIT_SWIMMING
    w.xmin+r.body_margin<=destination[1]<=w.xmax-r.body_margin && w.zmin+r.body_margin<=destination[2]<=w.zmax-r.body_margin || return false
    !any(o->RDLMigrationProbe.segment_hit(origin,destination,o,r.body_margin),w.obstacles)
end
function configured_rabbit_swim_candidate(w,a,i,t,p)
    r=RABBIT_SWIMMING;x=a.x[i];z=a.z[i]
    river=12+5sin((z-6)/22+w.phase);width=1.2+.4*(1+sin(z/13))
    abs(x-river)<=r.bank_range && material(w.phase,x,z)!=WATER || return nothing
    direction=x<river ? 1. : -1.;goal=(river+direction*(width/2+r.landing_margin),z)
    clear(w,goal,goal) && configured_rabbit_swim_clear(w,(x,z),goal) || return nothing
    distance=abs(goal[1]-x)
    cost=width/r.swim_speed*r.swim_cost+max(0.,distance-width)/r.land_speed*r.land_cost
    a.energy[i]>r.reserve+r.energy_margin*cost || return nothing
    observations=filter(!isnothing,observe_neighbors!(w,a,i,t))
    grass=isempty(observations) ? 0. : maximum(o.grass for o in observations)
    # 暫定接続: 渡河は現在の採食未達だけで促進する。過去区画の移動失敗は
    # その区画の評価に残し、全域の移動圧へ転用しない。採食解決で親Hは0。
    # 将来は渡河と現在の親目的の関係予測へ置換する。
    m=approach_memory(p.base,i);pressure=m.food_pressure.H
    score=(r.hunger_reference-a.energy[i])/r.hunger_scale+pressure/r.H_scale-r.prior_penalty-r.grass_weight*grass
    (goal=goal,cost=cost,probability=1/(1+exp(-clamp(score,-50.,50.))))
end
function configured_rabbit_swim_step!(p::RabbitSwimmingPolicy,w,a,i,t,overrides)
    r=RABBIT_SWIMMING;wet=material(w.phase,a.x[i],a.z[i])==WATER
    if !haskey(p.trips,i)
        # 高コスト地形版では独立した渡河抽選を使わず、通常の目的移動で渡る。
        RABBIT_TERRAIN.enabled && return false
        a.state[i]==SEARCH && (overrides===nothing || overrides[i]==0) && mod(t+i,r.interval)==0 || return false
        candidate=configured_rabbit_swim_candidate(w,a,i,t,p);candidate===nothing && return false
        m=approach_memory(p.base,i)
        rand(m.rng)<candidate.probability || return false
        p.trips[i]=candidate;p.counts[:selected]+=1;m.target=0;a.target[i]=0
        approach_record!(m,(event="swim_choice",tick=t,goal=candidate.goal,cost=candidate.cost,probability=candidate.probability))

    end
    trip=p.trips[i];origin=(a.x[i],a.z[i]);distance=hypot(trip.goal[1]-origin[1],trip.goal[2]-origin[2])
    heading=atan(trip.goal[2]-origin[2],trip.goal[1]-origin[1])
    probe=(origin[1]+min(r.land_speed,distance)*cos(heading),origin[2]+min(r.land_speed,distance)*sin(heading))
    wet=wet || material(w.phase,probe...)==WATER || material(w.phase,(origin[1]+probe[1])/2,(origin[2]+probe[2])/2)==WATER
    step=min(distance,wet ? r.swim_speed : r.land_speed)
    destination=(origin[1]+step*cos(heading),origin[2]+step*sin(heading))
    if !configured_rabbit_swim_clear(w,origin,destination)
        a.blocked[i]+=1
    else
        a.x[i],a.z[i]=destination;a.heading[i]=heading;a.distance[i]+=step
        k=cell(w,destination...)
        if k!=a.current_cell[i];a.previous_cell[i]=a.current_cell[i];a.current_cell[i]=k;end
    end
    wet && (p.counts[:swim_ticks]+=1;a.energy[i]=max(0.,a.energy[i]-(r.swim_cost-r.land_cost)))
    if hypot(a.x[i]-trip.goal[1],a.z[i]-trip.goal[2])<1e-8
        delete!(p.trips,i);p.counts[:arrived]+=1;a.target[i]=0;a.next_sense[i]=t+1
        approach_record!(approach_memory(p.base,i),(event="swim_arrived",tick=t,goal=trip.goal))
    end
    true
end

# Snapshot validation exception only for a recorded, geometrically valid water crossing.
# Does not change locomotion or permit untracked water positions.
configured_rabbit_swim_position_valid(policy,w,a,i)=false
function configured_rabbit_swim_position_valid(policy::RabbitSwimmingPolicy,w,a,i)
 p=(a.x[i],a.z[i])
 haskey(policy.trips,i) && material(w.phase,p...)==WATER && configured_rabbit_swim_clear(w,p,p)
end
