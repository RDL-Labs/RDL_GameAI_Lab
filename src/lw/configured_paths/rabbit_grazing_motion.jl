# 暫定固定: 採食中の小移動。通常ON、enabled=falseで旧挙動。
# 60tick(5分)ごと、個体別位相で0.1移動。局所の草だけを参照。
# 衝突・実座標・消費は通常移動と共通。遠方探索や学習ではない。
# 将来は採食姿勢・局所採食成果のMBへ置換。統計はプロセス内累計。
const RABBIT_GRAZING_MOTION=(enabled=true,interval_ticks=60,step_distance=.1,
    turn_amplitude=pi/4,turn_phase=2.399963229728653,offsets=(0.,pi/2,-pi/2),
    extra_cost_per_distance=(.012-.0047)/.2)
const RABBIT_GRAZING_MOTION_STATS=Dict("attempts"=>0,"moved"=>0,"blocked"=>0)
function configured_rabbit_grazing_motion!(w,a,i,t;enabled=RABBIT_GRAZING_MOTION.enabled)
    p=RABBIT_GRAZING_MOTION
    (!enabled || a.state[i]!=GRAZE || mod(t+i,p.interval_ticks)!=0) && return 0.
    RABBIT_GRAZING_MOTION_STATS["attempts"]+=1
    origin=(a.x[i],a.z[i]);base=a.heading[i]+p.turn_amplitude*sin((div(t+i,p.interval_ticks)+i)*p.turn_phase)
    best=-Inf;chosen=nothing
    for offset in p.offsets
        heading=configured_boundary_heading(w,origin,base+offset)
        q=(origin[1]+p.step_distance*cos(heading),origin[2]+p.step_distance*sin(heading))
        clear(w,origin,q) || continue
        k=cell(w,q...)
        food=w.layers===nothing ? grass!(w,k,t) : configured_rabbit_layer_observation(observe_grass!(w,k,t),a.energy[i]).food
        food>0 || continue
        if food>best;best=food;chosen=(q,heading);end
    end
    if chosen===nothing
        RABBIT_GRAZING_MOTION_STATS["blocked"]+=1
        return 0.
    end
    q,heading=chosen
    if rabbit_land_step!(w,a,i,q)
        a.heading[i]=heading;a.target[i]=0;a.next_sense[i]=t
        RABBIT_GRAZING_MOTION_STATS["moved"]+=1
        return p.step_distance*p.extra_cost_per_distance
    end
    0.
end
