# 暫定固定：wildlife.reproduction=true のみ（既定false）。幼体は巣で待機し、
# 母親は日に一度、授乳が必要な仔の出生位置へ戻る。位置は記憶の代用として直接保持。
# 既存の採食・逃走FSMを保ち、母体不足なら採食、逃走は帰巣より優先する。
# 将来は巣の観測・記憶と子の要求による目的選択へ置換する。学習成果とは扱わない。
function configured_rabbit_nursing!(s,t)
    life=s.life;life===nothing && return
    a=s.animals;day=div(t,RABBIT_LIFE.day_ticks)
    for i in eachindex(s.alive)
        life.moving[i]=s.alive[i] && !dependent(life,i,t)
    end
    for i in eachindex(s.alive)
        s.alive[i] && dependent(life,i,t) && life.nursed_day[i]<day || continue
        mother=life.mother[i]
        mother>0 && s.alive[mother] && a.energy[mother]>RABBIT_LIFE.maternal_reserve && s.overrides[mother]==0 || continue
        goal=life.nest[i]
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
