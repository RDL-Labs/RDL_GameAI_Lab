# 暫定固定: estimates["crossing_enabled"]=1 の実験のみON、既定OFF。
# 川形状/自己位置/着地点を直接参照。獲物の真の位置は使わない。
# 低い通常MB候補。将来は岸/流れの観測と経験による不確かな予測へ置換。
const PREDATOR_CROSSING=(prior_penalty=2.5,swim_speed=.12,land_speed=.22,
    swim_move_multiplier=4.,landing_margin=1.,arrival_radius=.4,
    forecast_slack=1.5,energy_margin=1.2)
crossing_water(w,p)=H.material(w.phase,p...)==H.WATER
# 暫定固定: 選択済み渡河は水中で休息へ切替せず岸まで継続。死亡は上位で終了。
# 明示ON時だけ使用。将来は泳ぎ/上陸/中断の身体MBへ置換。
configured_crossing_committed(w,mind,p)=mind.selected!==nothing &&
    !P.configured_predator_terrain_enabled(w) &&
    mind.selected["action"]==:cross_river && crossing_water(w,(p.visual.body.x,p.visual.body.z))
function configured_crossing_candidate!(rows,mind,p,w;physiology=nothing)
    P.configured_predator_terrain_enabled(w) && return # Normal movement handles costly water.
    get(mind.estimates,"crossing_enabled",0.)>0 || return
    b=p.visual.body;r=PREDATOR_CROSSING
    river=12+5sin((b.z-6)/22+w.phase);width=1.2+.4*(1+sin(b.z/13))
    direction=b.x<river ? 1. : -1.
    target=(river+direction*(width/2+r.landing_margin),b.z)
    H.clear(w,target,target) || return
    distance=hypot(target[1]-b.x,target[2]-b.z)
    forecast=ceil(r.forecast_slack*(max(0.,distance-width)/r.land_speed+width/r.swim_speed))
    cost=PREDATOR_ANIMAL_TRIAL.daily_food/PREDATOR_ANIMAL_TRIAL.day_ticks*forecast+
        PREDATOR_ANIMAL_TRIAL.move_food*(distance+(r.swim_move_multiplier-1)*width)
    p.food>cost*r.energy_margin || return
    physiology!==nothing && physiology.body.strain+distance*PREDATOR_BODY.move_strain>=1 && return
    hunger=max(0.,(PREDATOR_ANIMAL_TRIAL.initial_food-p.food)/PREDATOR_COGNITION.food_pressure_scale)
    push!(rows,LW.D("method"=>(direction>0 ? "cross:east" : "cross:west"),"action"=>:cross_river,
        "question"=>"reached_other_bank","priority"=>PREDATOR_COGNITION.food_weight*hunger-r.prior_penalty-cost/PREDATOR_COGNITION.food_value_scale,
        "forecast"=>forecast,"expected"=>PREDATOR_COGNITION.place_prior,"target"=>target,
        "arrival_radius"=>r.arrival_radius,"crossing_cost"=>cost))
end
function configured_crossing_step!(w,b,speed)
    r=PREDATOR_CROSSING;origin=(b.x,b.z)
    for offset in (0.,pi/4,-pi/4,pi/2,-pi/2)
        heading=H.configured_boundary_heading(w,origin,b.heading+offset)
        probe=(b.x+speed*cos(heading),b.z+speed*sin(heading))
        wet=crossing_water(w,origin)||crossing_water(w,probe)||crossing_water(w,((origin[1]+probe[1])/2,(origin[2]+probe[2])/2))
        step=wet ? min(speed,r.swim_speed) : speed
        destination=(b.x+step*cos(heading),b.z+step*sin(heading))
        w.xmin+.25<=destination[1]<=w.xmax-.25 && w.zmin+.25<=destination[2]<=w.zmax-.25 || continue
        any(o->H.RDLMigrationProbe.segment_hit(origin,destination,o,.25),w.obstacles) && continue
        b.x,b.z=destination;b.heading=heading;b.distance+=step
        return wet ? step*(r.swim_move_multiplier-1)*PREDATOR_ANIMAL_TRIAL.move_food : 0.
    end
    b.blocked+=1
    0.
end
