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
function configured_rabbit_nursing_forecast(s,mother,children)
    a=s.animals;r=RABBIT_NURSING_PLAN
    goal=s.life.nest[first(children)]
    distance=hypot(a.x[mother]-goal[1],a.z[mother]-goal[2])
    travel_ticks=max(0.,distance-RABBIT_LIFE.nurse_distance)/r.move_speed*r.travel_slack
    milk=sum(max(0.,RABBIT_LIFE.milk_target-a.energy[i])+RABBIT_LIFE.infant_energy_per_day*travel_ticks/RABBIT_LIFE.day_ticks for i in children)
    required=RABBIT_LIFE.maternal_reserve+milk/RABBIT_LIFE.milk_efficiency+travel_ticks*r.move_cost_per_tick
    (goal=goal,travel_ticks=travel_ticks,milk=milk,departure_energy=min(r.departure_cap,required))
end
function configured_rabbit_nursing!(s,t)
    life=s.life;life===nothing && return
    a=s.animals;r=RABBIT_NURSING_PLAN
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
        minimum(a.energy[i] for i in children)<=r.request_energy || continue
        s.overrides[mother]==0 || continue
        forecast=configured_rabbit_nursing_forecast(s,mother,children)
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
        s.overrides[mother]=H.SEARCH;a.target[mother]=H.cell(s.world,goal...);a.next_sense[mother]=t+1
        life.nest_return_ticks+=1
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
