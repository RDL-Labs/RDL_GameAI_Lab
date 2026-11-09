# 暫定固定の局所ρ。RabbitApproachPolicyで既定ON、enabled=falseで無効。
# 候補なしの経過を10 SEARCH tickの見積もり残差としてH化。
# 近傍の実座標/衝突/草観測は既存と同じ認知ショートカット。
# 将来は共通の親MBの残差・ρ制御へ置換。経路/脱出口の正解は与えない。
const RABBIT_LOCAL_RHO=(enabled=true,history_limit=64,visit_limit=256,forecast_ticks=10,H_trigger=1.,H_limit=32.,
    radii=(.4,.8,1.2,1.6),directions=32,arrival=.21,
    visit_resolution=.4,visit_penalty=.7,heading_bonus=.15,distance_cost=.1,
    forecast_slack=2.,speed=.2)
mutable struct RabbitLocalRho
    H::Float64
    missing_ticks::Int
    waypoint::Union{Nothing,Tuple{Float64,Float64}}
    remaining::Int
    visits::Dict{Tuple{Int,Int},Int}
    records::Vector{Any}
    queries::Int
    counts::Dict{String,Int}
end
RabbitLocalRho()=RabbitLocalRho(0.,0,nothing,0,Dict{Tuple{Int,Int},Int}(),Any[],0,Dict{String,Int}())
rho_key(p)=Tuple(floor.(Int,collect(p)./RABBIT_LOCAL_RHO.visit_resolution))
function rho_record!(m,row)
    m.counts[row.event]=get(m.counts,row.event,0)+1
    push!(m.records,row)
    length(m.records)>RABBIT_LOCAL_RHO.history_limit && popfirst!(m.records)
    if length(m.visits)>RABBIT_LOCAL_RHO.visit_limit
        delete!(m.visits,first(sort!(collect(keys(m.visits)))))
    end
end
function configured_rabbit_local_rho!(m,w,a,i,t,base;geometry,allowed=q->true)
    p=RABBIT_LOCAL_RHO;origin=(a.x[i],a.z[i])
    if m.waypoint!==nothing
        distance=hypot(origin[1]-m.waypoint[1],origin[2]-m.waypoint[2])
        if distance<=p.arrival || m.remaining<=0
            rho_record!(m,(event=distance<=p.arrival ? "local_arrived" : "local_failed",tick=t,H=m.H,position=origin,waypoint=m.waypoint))
            key=rho_key(m.waypoint);m.visits[key]=get(m.visits,key,0)+1
            m.waypoint=nothing
        else
            m.remaining-=1
            return atan(m.waypoint[2]-origin[2],m.waypoint[1]-origin[1])
        end
    end
    coarse=filter(!isnothing,geometry.observe_neighbors!(w,a,i,t))
    if !isempty(coarse)
        if m.H>0;rho_record!(m,(event="coarse_restored",tick=t,H=m.H,position=origin));end
        m.H=0.;m.missing_ticks=0;empty!(m.visits)
        return base
    end
    m.missing_ticks+=1
    m.H=min(p.H_limit,max(0.,m.missing_ticks/p.forecast_ticks-1))
    m.H<p.H_trigger && return base
    candidates=NamedTuple[]
    for radius in p.radii,j in 0:p.directions-1
        angle=2pi*j/p.directions;q=(origin[1]+radius*cos(angle),origin[2]+radius*sin(angle))
        m.queries+=1
        allowed(q) && geometry.clear(w,origin,q) || continue
        k=geometry.cell(w,q...)
        food=w.layers===nothing ? geometry.grass!(w,k,t) : geometry.configured_rabbit_layer_observation(geometry.observe_grass!(w,k,t),a.energy[i]).food
        score=log1p(food)-p.visit_penalty*get(m.visits,rho_key(q),0)+p.heading_bonus*cos(angle-base)-p.distance_cost*radius
        push!(candidates,(position=q,score=score,radius=radius))
    end
    isempty(candidates) && return base
    chosen=candidates[argmax([c.score for c in candidates])]
    m.waypoint=chosen.position;m.remaining=ceil(Int,chosen.radius/p.speed*p.forecast_slack)
    m.visits[rho_key(origin)]=get(m.visits,rho_key(origin),0)+1
    rho_record!(m,(event="fine_choice",tick=t,H=m.H,position=origin,waypoint=m.waypoint,candidates=length(candidates)))
    atan(m.waypoint[2]-origin[2],m.waypoint[1]-origin[1])
end
