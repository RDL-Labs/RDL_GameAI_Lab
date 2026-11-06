# 暫定の世界/ゲーム規則。実験のprobabilistic_capture=trueのみ有効、既定OFF。
# 実際の位置・警戒・速度は世界の成否抽選専用。個体の候補評価へ確率を渡さない。
# 将来は身体能力・地形別の実測較正へ置換。1攻撃区間につき抽選は1回。
const CAPTURE_WORLD=(reach=2.5,path_step=.5,base=.1,distance_weight=.4,
    unaware_weight=.2,rear_weight=.1,closing_weight=.15,cover_weight=.1,
    speed_scale=1.,minimum=.05,maximum=.9)
function configured_capture_chance(distance,aware,rear,closing,cover)
    r=CAPTURE_WORLD
    clamp(r.base+r.distance_weight*clamp(1-distance/r.reach,0.,1.)+
        r.unaware_weight*(!aware)+r.rear_weight*clamp(rear,0.,1.)+
        r.closing_weight*clamp(closing/r.speed_scale,-1.,1.)-
        r.cover_weight*clamp(cover,0.,1.),r.minimum,r.maximum)
end
function configured_capture_path(w,p,q)
    distance=hypot(q[1]-p[1],q[2]-p[2])
    distance<=CAPTURE_WORLD.reach || return false
    steps=max(1,ceil(Int,distance/CAPTURE_WORLD.path_step));prior=p
    for k in 1:steps
        next=(p[1]+(q[1]-p[1])*k/steps,p[2]+(q[2]-p[2])*k/steps)
        H.clear(w,prior,next) || return false
        prior=next
    end
    true
end
function configured_probability_advance!(s,t,attack_speed)
    v=s.predator;b=v.body;target=b.target
    start=(b.x,b.z)
    P.move!(s.world,b,attack_speed;turn=false) # Charge actual movement even on a miss.
    b.timer-=1
    b.timer>0 && return
    valid=1<=target<=length(s.alive) && s.alive[target]
    chance=0.;distance=Inf;reason="target_unavailable"
    if valid
        prey=(s.animals.x[target],s.animals.z[target]);origin=(b.x,b.z)
        distance=hypot(prey[1]-b.x,prey[2]-b.z)
        valid=configured_capture_path(s.world,origin,prey) && P.los(s.world,origin,prey)
        reason=distance>CAPTURE_WORLD.reach ? "out_of_reach" : "blocked"
        if valid
            ux=distance>0 ? (prey[1]-b.x)/distance : 0.
            uz=distance>0 ? (prey[2]-b.z)/distance : 0.
            old=target<=length(v.previous_prey) ? v.previous_prey[target] : prey
            closing=(b.x-start[1]-(prey[1]-old[1]))*ux+(b.z-start[2]-(prey[2]-old[2]))*uz
            rear=(1+cos(s.animals.heading[target])*ux+sin(s.animals.heading[target])*uz)/2
            aware=s.animals.state[target] in (H.ALERT,H.FLEE)
            cover=H.grass_cover!(s.world,H.cell(s.world,prey...),t;body_height=rabbit_height(s,target))
            chance=configured_capture_chance(distance,aware,rear,closing,cover)
            reason="draw"
        end
    end
    success=valid && rand(v.rng)<chance
    if success
        s.alive[target]=false;b.captures+=1;b.state=P.REST;b.target=0
    else
        b.misses+=1;b.state=P.CHASE
    end
    b.timer=0
    push!(v.events,(tick=t,kind=success ? "capture" : "probability_miss",id=target,
        probability=chance,distance=isfinite(distance) ? distance : nothing,reason=reason))
end
