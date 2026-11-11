# 暫定固定の暦による繁殖停止。既定OFF（通年）。ON時だけ旧365日/240日窓を再現。
# 日付を直接参照する環境ショートカット。将来は環境・身体状態による繁殖条件へ置換。
const RABBIT_BREEDING_SEASON=(enabled=false,)
configured_rabbit_breeding_open(day;enabled=RABBIT_BREEDING_SEASON.enabled)=
    !enabled || mod(day,RABBIT_LIFE.year_days)<RABBIT_LIFE.season_days

# 暫定固定：繁殖ON。子の不足・帰巣消費を直接参照し、まとめて採食してから授乳へ戻る。
# 日付や実施回数では完了扱いしない。血縁/巣位置/子のenergyは認知の代用。
# 逃走優先。胃の満杯/睡眠を尊重し、通常満腹85を超す備蓄は要求しない。
# 将来は子との関係MB・身体需要・移動見積もりへ置換する。
const RABBIT_NURSING_PLAN=(enabled=true,request_energy=4.,departure_cap=85.,
    move_speed=.2,move_cost_per_tick=.012,travel_slack=1.5,gut_limit=3.8,
    sleep_limit=1.,minimum_grass=.005)
# 暫定固定: 血縁/子の位置と不足を直接読む。巣到着では完了しない。
# enabled=falseで旧巣目標へ戻す。将来は子との関係MB/成果評価へ置換。
const RABBIT_NURSING_GOAL=(enabled=true,completion_tolerance=1e-9)
# 暫定固定: 子の実energyと最後に見た危険位置を比較。学習済み評価ではない。
# 必要性=(request_energy-min_child_energy)/request_energy、危険=(far-distance)/(far-near)。
# 同点は警戒維持。距離3/10は現行視覚反応の基準に合わせた世界距離。
# enabled=falseで旧警戒一律優先。将来は子/危険MBの関係拘束へ置換。
const RABBIT_NURSING_ALERT=(enabled=true,near_distance=3.,far_distance=10.,history_limit=64)
const RABBIT_NURSING_ALERT_STATS=Dict("considered"=>0,"allowed"=>0)
const RABBIT_NURSING_ALERT_RECORDS=Any[]
configured_nursing_alert_enabled(mother)=RABBIT_NURSING_ALERT.enabled
function configured_nursing_alert_evidence(s,mother,children)
    rule=RABBIT_NURSING_ALERT;a=s.animals
    need=clamp((RABBIT_NURSING_PLAN.request_energy-minimum(a.energy[i] for i in children))/RABBIT_NURSING_PLAN.request_energy,0.,1.)
    observed=s.seen_position[mother]
    distance=hypot(a.x[mother]-observed[1],a.z[mother]-observed[2])
    danger=clamp((rule.far_distance-distance)/(rule.far_distance-rule.near_distance),0.,1.)
    (need=need,danger=danger,distance=distance,allow=need>danger)
end
configured_nursing_pending(life)=life.nursing_pending
configured_nursing_targets(life)=life.nursing_targets
function configured_rabbit_nursing_forecast(s,mother,children)
    a=s.animals;r=RABBIT_NURSING_PLAN
    child=children[argmin([(a.energy[i],hypot(a.x[mother]-a.x[i],a.z[mother]-a.z[i]),i) for i in children])]
    goal=RABBIT_NURSING_GOAL.enabled ? (a.x[child],a.z[child]) : s.life.nest[first(children)]
    distance=hypot(a.x[mother]-goal[1],a.z[mother]-goal[2])
    travel_ticks=max(0.,distance-RABBIT_LIFE.nurse_distance)/r.move_speed*r.travel_slack
    milk=sum(max(0.,RABBIT_LIFE.milk_target-a.energy[i])+RABBIT_LIFE.infant_energy_per_day*travel_ticks/RABBIT_LIFE.day_ticks for i in children)
    required=RABBIT_LIFE.maternal_reserve+milk/RABBIT_LIFE.milk_efficiency+travel_ticks*r.move_cost_per_tick
    (goal=goal,travel_ticks=travel_ticks,milk=milk,departure_energy=min(r.departure_cap,required))
end
function configured_rabbit_nursing!(s,t)
    life=s.life;life===nothing && return
    a=s.animals;r=RABBIT_NURSING_PLAN
    pending=configured_nursing_pending(life);targets=configured_nursing_targets(life)
    empty!(targets)
    filter!(i->s.alive[i] && dependent(life,i,t) && life.mother[i]>0 && s.alive[life.mother[i]],pending)
    RABBIT_NURSING_GOAL.enabled || empty!(pending)
    mothers=Dict{Int,Vector{Int}}()
    for i in eachindex(s.alive)
        life.moving[i]=s.alive[i] && configured_rabbit_self_feeding(s,i,t)
        s.alive[i] && dependent(life,i,t) || continue
        mother=life.mother[i]
        mother>0 && s.alive[mother] || continue
        push!(get!(()->Int[],mothers,mother),i)
    end
    r.enabled || return
    for (mother,children) in mothers
        if minimum(a.energy[i] for i in children)<=r.request_energy && RABBIT_NURSING_GOAL.enabled
            union!(pending,(i for i in children if a.energy[i]<RABBIT_LIFE.milk_target))
        end
        if RABBIT_NURSING_GOAL.enabled
            children=filter(i->i in pending,children)
            isempty(children) && continue
        else
            minimum(a.energy[i] for i in children)<=r.request_energy || continue
        end
        nursing_alert=s.overrides[mother]==H.ALERT && configured_nursing_alert_enabled(mother)
        (s.overrides[mother]==0 || nursing_alert) || continue
        forecast=configured_rabbit_nursing_forecast(s,mother,children)
        if nursing_alert
            evidence=configured_nursing_alert_evidence(s,mother,children)
            allow=evidence.allow && a.energy[mother]>=forecast.departure_energy
            RABBIT_NURSING_ALERT_STATS["considered"]+=1
            RABBIT_NURSING_ALERT_STATS["allowed"]+=allow
            push!(RABBIT_NURSING_ALERT_RECORDS,(tick=t,mother=mother,need=evidence.need,danger=evidence.danger,distance=evidence.distance,mother_energy=a.energy[mother],departure_energy=forecast.departure_energy,allow=allow))
            length(RABBIT_NURSING_ALERT_RECORDS)>RABBIT_NURSING_ALERT.history_limit && popfirst!(RABBIT_NURSING_ALERT_RECORDS)
            allow || continue
            # Do not erase ALERT until an approach is actually required.
        end
        if a.energy[mother]<forecast.departure_energy
            # 暫定固定：授乳準備の採食需要。満腹休息より優先、胃満杯/睡眠/逃走は保つ。
            if a.gut[mother]<r.gut_limit && a.sleepy[mother]<r.sleep_limit
                k=H.cell(s.world,a.x[mother],a.z[mother])
                s.overrides[mother]=H.grass!(s.world,k,t)>=r.minimum_grass ? H.GRAZE : H.SEARCH
                a.target[mother]=0;a.next_sense[mother]=t
            end
            continue
        end
        goal=forecast.goal
        hypot(a.x[mother]-goal[1],a.z[mother]-goal[2])<=RABBIT_LIFE.nurse_distance && continue
        RABBIT_NURSING_GOAL.enabled && (targets[mother]=goal)
        s.overrides[mother]=H.SEARCH;a.target[mother]=H.cell(s.world,goal...);a.next_sense[mother]=t+1
        life.nest_return_ticks+=1
    end
end

function configured_nursing_steering(s,base)
    s.life===nothing && return base
    return function(w,a,i,speed,overrides)
        goal=configured_maternal_boundary_goal(s,i,s.ticks)
        goal===nothing && (goal=get(configured_nursing_targets(s.life),i,nothing))
        if goal!==nothing && overrides!==nothing && overrides[i]==H.SEARCH
            a.heading[i]=atan(goal[2]-a.z[i],goal[1]-a.x[i])
        end
        base===nothing ? a.heading[i] : base(w,a,i,speed,overrides)
    end
end

# 暫定固定：繁殖ONの授乳帰巣SEARCHだけ。advance!(...;nursing_potential=false)で旧移動。
# 既定ON。巣セルへの既存方角と近傍障害物の幾何を直接使用する認知ショートカット。
# 将来は観測された障害物・巣MBによる移動へ置換。授乳判定・逃走には介入しない。
# world座標単位。半径と係数は初版の試験値。左右同点は個体IDの偶奇で固定する。
const RABBIT_POTENTIAL=(body_radius=.25, influence=1.2, repulsion=1.4,
    progress_floor=.15, turn_offsets=(pi/4,pi/2,3pi/4,pi), epsilon=1e-9)

function configured_rabbit_potential(w,a,i,speed,overrides)
    overrides!==nothing && overrides[i]==H.SEARCH || return a.heading[i]
    rule=RABBIT_POTENTIAL
    x=a.x[i];z=a.z[i];base=a.heading[i]
    gx=cos(base);gz=sin(base);fx=gx;fz=gz
    # Cheap squared-distance filter; only nearby obstacles contribute forces.
    # No spatial index yet: the filter scans the existing obstacle vector.
    for obstacle in w.obstacles
        dx=x-obstacle.x;dz=z-obstacle.z
        radius=obstacle.radius+rule.body_radius
        d2=dx*dx+dz*dz
        d2<(radius+rule.influence)^2 || continue
        d=sqrt(d2);gap=max(0.,d-radius)
        strength=rule.repulsion*(1-gap/rule.influence)^2
        fx+=strength*dx/max(d,rule.epsilon)
        fz+=strength*dz/max(d,rule.epsilon)
    end
    heading=atan(fz,fx)
    p=(x,z)
    candidate=(x+speed*cos(heading),z+speed*sin(heading))
    if fx*gx+fz*gz>rule.progress_floor && H.clear(w,p,candidate)
        return heading
    end
    # Low forward force or blocked step: local sideways candidates, stable side
    # preference rather than alternating left/right each tick. Never teleport.
    side=isodd(i) ? 1. : -1.
    for offset in rule.turn_offsets, sign in (side,-side)
        heading=base+sign*offset
        candidate=(x+speed*cos(heading),z+speed*sin(heading))
        H.clear(w,p,candidate) && return heading
    end
    base # Authoritative collision check in H.step! retains blocked accounting.
end
