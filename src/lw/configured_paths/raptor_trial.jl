# 暫定固定・動物実験専用、通常OFF。G/H/Pを持つ動物ランナーから読み込む。
# 軽い状態機械と世界総個体数の近道。MBによる判断・学習ではない。
# 将来は観測/身体/場所MBと外部個体群へ置換。時刻は既存17280tick/日。
const RAPTOR_TRIAL=(arrival_rabbits=150,departure_rabbits=100,day_ticks=17280,
    scan_ticks=120,rest_ticks=4320,flight_speed=1.,sight=40.,reach=2.5,
    capture_base=.85,alert_penalty=.25,cover_penalty=.3,
    daily_food=100.,initial_food=100.,capacity=250.,hunt_below=80.,adult_food=200.,
    eating_ticks=720,threat_range=8.,minimum_light=.25,seed=20261110,event_limit=256,
    tree_kind=1,minimum_tree_height=3.,switch_after_miss=true,rabbit_notice_range=3.)

# 暫定固定: 飛行高度を解かず、狩り飛行中だけ平面距離3以内で兎の視覚対象にする。
# 3は未較正の世界距離、Infで追加制限なし。食事中は地上の通常観測を維持。
# 視野・遮蔽・動体・危険記憶は既存処理。将来は高度と見かけの大きさへ置換。
configured_raptor_notice(bird,distance)=bird.mode!=:hunt || distance<=RAPTOR_TRIAL.rabbit_notice_range

mutable struct RaptorTrial
    visual::G.WildlifePredator
    perches::Vector{Tuple{Float64,Float64}}
    perch::Int
    mode::Symbol
    present::Bool
    target::Int
    destination::Tuple{Float64,Float64}
    due::Int
    food::Float64
    meal::Float64
    meal_rate::Float64
    captures::Int
    attempts::Int
    scans::Int
    arrivals::Int
    departures::Int
    interrupted_meals::Int
    eaten::Float64
    remains::Float64
    ticks::Dict{Symbol,Int}
    events::Vector{NamedTuple}
end
function configured_raptor(s,scene)
    rule=RAPTOR_TRIAL
    perches=Tuple{Float64,Float64}[(Float64(o.x),Float64(o.z)) for o in scene.obstacles
        if get(o,:kind,0)==rule.tree_kind && get(o,:height,0.)>=rule.minimum_tree_height]
    isempty(perches) && error("raptor requires tree perches")
    visual=G.configured_wildlife_predator(s.world,s.animals,(predator_count=1,),rule.seed)
    RaptorTrial(visual,perches,1,:outside,false,0,first(perches),0,rule.initial_food,
        0.,0.,0,0,0,0,0,0,0.,0.,Dict{Symbol,Int}(),NamedTuple[])
end
function configured_raptor_event!(bird,t,kind;details...)
    push!(bird.events,(tick=t,kind=kind,details=(;details...)))
    length(bird.events)>RAPTOR_TRIAL.event_limit && popfirst!(bird.events)
end
function configured_raptor_return!(bird)
    bird.target=0;bird.mode=:return;bird.destination=bird.perches[bird.perch]
end
function configured_raptor_leave_meal!(bird,t)
    bird.meal>0 && configured_raptor_event!(bird,t,"leftovers";position=(bird.visual.body.x,bird.visual.body.z),amount=bird.meal)
    bird.remains+=bird.meal;bird.meal=0.
end
# 日次ヒステリシス。1羽のみ。画面外は非計算、出現時の身体は暫定再設定。
function configured_raptor_population!(bird,n,t)
    t%RAPTOR_TRIAL.day_ticks==0 || return
    if !bird.present && n>=RAPTOR_TRIAL.arrival_rabbits
        bird.present=true;bird.mode=:arrive;bird.arrivals+=1;bird.food=RAPTOR_TRIAL.initial_food
        bird.perch=rand(bird.visual.rng,eachindex(bird.perches));bird.destination=bird.perches[bird.perch]
        bird.visual.body.x=bird.destination[1];bird.visual.body.z=bird.destination[2]
        # Entry is finalized by the world adapter at the nearest map edge.
        configured_raptor_event!(bird,t,"arrival";rabbits=n)
    elseif bird.present && n<=RAPTOR_TRIAL.departure_rabbits && bird.mode!=:depart
        configured_raptor_leave_meal!(bird,t);bird.mode=:depart;bird.target=0
        configured_raptor_event!(bird,t,"departure_started";rabbits=n)
    end
end
function configured_raptor_edge(w,position)
    x,z=position
    edges=((w.xmin,z),(w.xmax,z),(x,w.zmin),(x,w.zmax))
    edges[argmin(map(p->hypot(p[1]-x,p[2]-z),edges))]
end
# 高所視線の暫定2D近似: 自分の止まり木の幹のみ除外。他の遮蔽物は既存形状。
function configured_raptor_visible(s,bird,i,t)
    s.alive[i] && !G.configured_rabbit_in_burrow(s,i,t) || return false
    origin=(bird.visual.body.x,bird.visual.body.z);prey=(s.animals.x[i],s.animals.z[i])
    hypot(prey[1]-origin[1],prey[2]-origin[2])<=RAPTOR_TRIAL.sight || return false
    !any(o->hypot(o.x-origin[1],o.z-origin[2])>o.radius &&
        H.RDLMigrationProbe.segment_hit(origin,prey,o,0.),s.world.obstacles)
end
# 暫定固定: switch_after_miss=trueで直前に失敗した獲物だけ次の選択から除外。
# 有界イベント履歴を使い保存型を変更しない。成功で解除、別の失敗で対象更新。
# 他に見えなければ既存の別の木への移動。将来は失敗経験による関係評価へ置換。
function configured_raptor_failed_target(bird)
    for event in Iterators.reverse(bird.events)
        event.kind=="miss" && return event.details.id
        event.kind in ("capture","arrival") && return 0
    end
    0
end
function configured_raptor_scan!(bird,s,t;switch_after_miss=RAPTOR_TRIAL.switch_after_miss)
    bird.scans+=1;best=0;best_score=-Inf
    excluded=switch_after_miss ? configured_raptor_failed_target(bird) : 0
    for i in eachindex(s.alive)
        i==excluded && continue
        configured_raptor_visible(s,bird,i,t) || continue
        cover=H.grass_cover!(s.world,H.cell(s.world,s.animals.x[i],s.animals.z[i]),t;body_height=G.rabbit_height(s,i))
        rand(bird.visual.rng)<1/(1+cover) || continue
        distance=hypot(s.animals.x[i]-bird.visual.body.x,s.animals.z[i]-bird.visual.body.z)
        score=1/(1+distance)/(1+cover)
        score>best_score && (best=i;best_score=score)
    end
    if best>0
        bird.target=best;bird.destination=(s.animals.x[best],s.animals.z[best]);bird.mode=:hunt
        configured_raptor_event!(bird,t,"target";id=best,position=bird.destination)
    else
        bird.perch=mod1(bird.perch+1,length(bird.perches));configured_raptor_return!(bird)
    end
end
function configured_raptor_capture!(bird,s,t;prey_nutrition=1.,rabbit_composition=nothing)
    bird.attempts+=1;i=bird.target;chance=0.
    valid=1<=i<=length(s.alive) && s.alive[i] && !G.configured_rabbit_in_burrow(s,i,t)
    if valid
        prey=(s.animals.x[i],s.animals.z[i]);origin=(bird.visual.body.x,bird.visual.body.z)
        valid=hypot(prey[1]-origin[1],prey[2]-origin[2])<=RAPTOR_TRIAL.reach &&
            H.clear(s.world,prey,prey) && P.los(s.world,origin,prey)
        if valid
            cover=H.grass_cover!(s.world,H.cell(s.world,prey...),t;body_height=G.rabbit_height(s,i))
            aware=s.animals.state[i] in (H.ALERT,H.FLEE)
            chance=clamp(RAPTOR_TRIAL.capture_base-RAPTOR_TRIAL.alert_penalty*aware-
                RAPTOR_TRIAL.cover_penalty*cover,0.,1.)
        end
    end
    if valid && rand(bird.visual.rng)<chance
        s.alive[i]=false;bird.captures+=1;bird.mode=:eat
        bird.visual.body.x=s.animals.x[i];bird.visual.body.z=s.animals.z[i]
        fraction=clamp((G.rabbit_height(s,i)/G.RABBIT_LIFE.adult_height)^3,0.,1.)
        bird.meal=prey_nutrition*(rabbit_composition===nothing ? RAPTOR_TRIAL.adult_food*fraction : configured_rabbit_meal(rabbit_composition,s,i,RAPTOR_TRIAL.adult_food,fraction))
        bird.meal_rate=bird.meal/RAPTOR_TRIAL.eating_ticks
        configured_raptor_event!(bird,t,"capture";id=i,probability=chance,meal=bird.meal)
    else
        configured_raptor_event!(bird,t,"miss";id=i,probability=chance)
        configured_raptor_return!(bird)
    end
end
# 休息中は定数時間の消費と期日確認のみ。獲物走査も候補評価も行わない。
function configured_raptor_step!(bird,s,predators,t;present=nothing,prey_nutrition=1.,rabbit_composition=nothing)
    bird.ticks[bird.mode]=get(bird.ticks,bird.mode,0)+1
    bird.present || return
    body=bird.visual.body;bird.visual.previous_position=(body.x,body.z)
    bird.food=max(0.,bird.food-RAPTOR_TRIAL.daily_food/RAPTOR_TRIAL.day_ticks)
    if bird.mode==:rest
        if t>=bird.due && bird.food<RAPTOR_TRIAL.hunt_below && G.AmbientVision.illumination(t)>=RAPTOR_TRIAL.minimum_light
            bird.mode=:observe;bird.due=t
        end
    elseif bird.mode==:observe
        t<bird.due && return
        bird.due=t+RAPTOR_TRIAL.scan_ticks
        G.AmbientVision.illumination(t)<RAPTOR_TRIAL.minimum_light && return
        configured_raptor_scan!(bird,s,t)
    elseif bird.mode==:eat
        danger=any(eachindex(predators)) do j
            p=predators[j]
            p.alive && (present===nothing || present[j]) &&
                hypot(p.visual.body.x-body.x,p.visual.body.z-body.z)<=RAPTOR_TRIAL.threat_range &&
                P.los(s.world,(body.x,body.z),(p.visual.body.x,p.visual.body.z))
        end
        if danger
            bird.interrupted_meals+=1;configured_raptor_leave_meal!(bird,t);configured_raptor_return!(bird)
        else
            amount=min(bird.meal,bird.meal_rate,RAPTOR_TRIAL.capacity-bird.food)
            bird.meal-=amount;bird.food+=amount;bird.eaten+=amount
            if bird.meal<=eps(RAPTOR_TRIAL.adult_food) || bird.food>=RAPTOR_TRIAL.capacity
                configured_raptor_leave_meal!(bird,t);configured_raptor_return!(bird)
            end
        end
    else
        # Flight follows only a still-visible target; loss retains the last observed point.
        if bird.mode==:hunt && 1<=bird.target<=length(s.alive) && configured_raptor_visible(s,bird,bird.target,t)
            bird.destination=(s.animals.x[bird.target],s.animals.z[bird.target])
        end
        dx=bird.destination[1]-body.x;dz=bird.destination[2]-body.z;distance=hypot(dx,dz)
        step=min(distance,RAPTOR_TRIAL.flight_speed)
        distance>0 && (body.x+=step*dx/distance;body.z+=step*dz/distance)
        if distance<=RAPTOR_TRIAL.flight_speed
            if bird.mode==:hunt
                configured_raptor_capture!(bird,s,t;prey_nutrition,rabbit_composition)
            elseif bird.mode==:depart
                bird.present=false;bird.mode=:outside;bird.departures+=1
                configured_raptor_event!(bird,t,"departure")
            else
                bird.mode=:rest;bird.due=t+(bird.food<RAPTOR_TRIAL.hunt_below ? RAPTOR_TRIAL.scan_ticks : RAPTOR_TRIAL.rest_ticks)
            end
        end
    end
    # Starvation causes off-map retreat, not immortal hunting at zero food.
    if bird.food<=0 && bird.mode ∉ (:depart,:outside)
        configured_raptor_leave_meal!(bird,t);bird.mode=:depart;bird.destination=configured_raptor_edge(s.world,(body.x,body.z))
        configured_raptor_event!(bird,t,"hungry_departure")
    end
end
configured_raptor_report(bird)=(present=bird.present,mode=bird.mode,position=(bird.visual.body.x,bird.visual.body.z),
    food=bird.food,captures=bird.captures,attempts=bird.attempts,scans=bird.scans,arrivals=bird.arrivals,
    departures=bird.departures,interrupted_meals=bird.interrupted_meals,eaten=bird.eaten,
    remains=bird.remains,ticks=copy(bird.ticks),events=copy(bird.events))
