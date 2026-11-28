import Random
include("fire_rest_local.jl")
# 暫定固定: scene.fire_rest=false。既知の安全な中央火と自宅の休息効用比較。
# 場所知識・安全度1を初期設定で与える。将来は観測/場所MBへ置換。
# 再判断128秒、距離費用.12、自宅効用.2は局所条件に基づく仮値。
const FIRE_REST_RULES=(review_us=128_000_000,travel_cost=.12,home_value=.2,arrival=.48)
function configured_fire_rest!(map,house,fire,position,yaw,rows,now;eligible,blocked,night,demand,seed=1)
    state=get!(()->D("rng"=>Random.MersenneTwister(seed),"choice"=>"none","until"=>0,
        "choices"=>0,"fire_choices"=>0,"rest_ticks"=>0,"walk_ticks"=>0),map,"configured_fire_rest")
    if blocked || night || demand>HOUSE_IDLE_RULES.max_demand
        state["choice"]="none";return nothing
    end
    (eligible || state["choice"]=="fire") || return nothing
    if state["choice"]=="none" || now>=state["until"]
        dx,dz=position[1]-fire[1],position[2]-fire[2];d=hypot(dx,dz)
        target=d>0 ? (fire[1]+2dx/d,fire[2]+2dz/d) : (fire[1]+2,fire[2])
        fire_score=configured_fire_rest_bias(2.,1.;enabled=true)-FIRE_REST_RULES.travel_cost*hypot(target[1]-position[1],target[2]-position[2])
        home_score=FIRE_REST_RULES.home_value-FIRE_REST_RULES.travel_cost*hypot(house.x-position[1],house.z-position[2])
        state["choice"]=rand(state["rng"])<1/(1+exp(home_score-fire_score)) ? "fire" : "home"
        state["target"]=target;state["until"]=now+FIRE_REST_RULES.review_us;state["choices"]+=1
        state["choice"]=="fire" && (state["fire_choices"]+=1)
    end
    state["choice"]=="fire" || return nothing
    target=state["target"];dx,dz=target[1]-position[1],target[2]-position[2];d=hypot(dx,dz)
    if d<=FIRE_REST_RULES.arrival+1e-12
        state["rest_ticks"]+=1
        return D("action"=>"rest","method"=>"fire_rest","configured_rule"=>"fire_rest","configured_observation"=>true)
    end
    viable=filter(r->r["cost"]!==nothing && r["clear"],rows)
    isempty(viable) && (state["choice"]="none";return nothing)
    sn,cs=sincosd(yaw);forward,right=dx*sn+dz*cs,dx*cs-dz*sn
    row=viable[argmin([hypot(forward-cosd(ANGLES[parse(Int,r["ref"])+1]),right-sind(ANGLES[parse(Int,r["ref"])+1])) for r in viable])]
    state["walk_ticks"]+=1
    plan=D("action"=>"walk","direction"=>parse(Int,row["ref"]),"method"=>"fire_rest_approach","configured_rule"=>"fire_rest","configured_observation"=>true)
    if d<=1.25
        plan["approach_angle"]=rad2deg(atan(right,forward));plan["approach_span"]=min(.5,max(0.,d-FIRE_REST_RULES.arrival))
    end
    plan
end
