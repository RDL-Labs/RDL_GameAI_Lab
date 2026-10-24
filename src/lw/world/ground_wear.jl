# World history, ported from integrations/lightweight/ground_wear.py.
mutable struct GroundWear
    cells::Dict{Tuple{Int,Int},Any}
    receipts::Dict{String,Any}
    now::Int
    day::Int
    recovery::Bool
    operations::Int
    roads::Dict{Tuple{Int,Int},Any}
end
GroundWear(day;recovery=true)=GroundWear(Dict{Tuple{Int,Int},Any}(),Dict{String,Any}(),0,day,recovery,0,Dict{Tuple{Int,Int},Any}())

# World-authored surfaces, separate from accumulated walking distance.
# Cells are one-unit grid coordinates; walking never renews construction age.
function place_roads!(g,roads)
    pending=Dict{Tuple{Int,Int},Any}()
    for road in roads
        days=Float64(get(road,:lifetime_days,3650.))
        duration=days*g.day
        isfinite(duration) && 1<=duration<typemax(Int)-g.now || error("road_lifetime")
        lifetime=round(Int,duration)
        for cell in road.cells
            length(cell)==2 && all(x->x isa Real && isfinite(x) && isinteger(x),cell) || error("road_cell")
            key=(Int(cell[1]),Int(cell[2]))
            old=get(pending,key,get(g.roads,key,nothing))
            if old===nothing || old["built_us"]+old["lifetime_us"]<g.now+lifetime
                pending[key]=D("built_us"=>g.now,"lifetime_us"=>lifetime)
            end
        end
    end
    merge!(g.roads,pending)
    g
end
function surface_wear(g,key)
    c=wear_cell!(g,key)
    natural=c===nothing ? 0. : c["wear"]
    road=get(g.roads,key,nothing)
    road===nothing && return natural
    age=g.recovery ? g.now-road["built_us"] : 0
    max(natural,10*max(0.,1-age/road["lifetime_us"]))
end
function advance_wear!(g,now)
    now>=g.now || error("ground_clock")
    # Only current-tick receipts are needed: old-tick submissions are rejected.
    now>g.now && empty!(g.receipts)
    g.now=now
end
function wear_cell!(g,key)
    c=get(g.cells,key,nothing)
    c===nothing && return nothing
    if g.recovery
        elapsed=max(0,g.now-c["last_walk_us"]-g.day)
        c["wear"]=max(0.,c["anchor_wear"]-2*elapsed/g.day)
    end
    c
end
function wear_factor(g,p)
    1-.5*min(1.,surface_wear(g,(floor(Int,p[1]),floor(Int,p[2])))/10)
end
function tread!(g,op,agent,start,finish,now;walkable=p->true)
    now==g.now || error("ground_receipt_clock")
    source=(op,start,finish)
    if haskey(g.receipts,agent)
        g.receipts[agent]==source || error("ground_wear_conflict")
        return
    end
    d=hypot(finish[1]-start[1],finish[2]-start[2])
    d==0 && return
    g.receipts[agent]=source;g.operations+=1
    n=max(1,ceil(Int,d/.1))
    for i in 0:n-1
        t=(i+.5)/n
        point=(start[1]+t*(finish[1]-start[1]),start[2]+t*(finish[2]-start[2]))
        walkable(point) || continue
        key=(floor(Int,point[1]),floor(Int,point[2]))
        c=wear_cell!(g,key)
        if c===nothing
            c=D("distance"=>0.,"wear"=>0.,"last_walk_us"=>now,"anchor_wear"=>0.,"agents"=>D())
            g.cells[key]=c
        end
        c["distance"]+=d/n;c["wear"]+=d/n;c["anchor_wear"]=c["wear"];c["last_walk_us"]=now
        c["agents"][agent]=get(c["agents"],agent,0.)+d/n
    end
end
function wear_snapshot(g)
    cells=D()
    for key in sort(collect(keys(g.cells)))
        c=deepcopy(wear_cell!(g,key));delete!(c,"anchor_wear")
        cells["$(key[1]),$(key[2])"]=c
    end
    D("rule"=>"world-ground-recovery-v1","now_us"=>g.now,"recovery_enabled"=>g.recovery,
      "grace_us"=>g.day,"recovery_per_day"=>2,"cell_size"=>1.,"road_distance"=>10.,
      "operations"=>g.operations,"cells"=>cells,
      "artificial_road_rule"=>"linear-lifetime-v1",
      "artificial_roads"=>D("$(key[1]),$(key[2])"=>copy(g.roads[key]) for key in sort(collect(keys(g.roads)))))
end

# Environmental transfer only: no agent memory/body restoration.
function restore_wear(snapshot,day)
    snapshot.rule=="world-ground-recovery-v1" && snapshot.grace_us==day && snapshot.cell_size==1 && snapshot.recovery_per_day==2 || error("ground_history_rule")
    snapshot.now_us>=0 || error("ground_history_clock")
    g=GroundWear(day;recovery=Bool(snapshot.recovery_enabled));g.now=Int(snapshot.now_us);g.operations=Int(snapshot.operations)
    for (key,v) in pairs(snapshot.cells)
        coords=parse.(Int,split(String(key),','));length(coords)==2 || error("ground_history_cell")
        isfinite(v.wear) && isfinite(v.distance) && 0<=v.wear<=v.distance+1e-8 && 0<=v.last_walk_us<=g.now || error("ground_history_value")
        # Snapshot wear is already decayed; reconstruct an anchor to avoid applying
        # the past interval twice on the first new-cohort observation.
        elapsed=g.recovery ? max(0,g.now-Int(v.last_walk_us)-day) : 0
        agents=D((occursin('/',String(a)) ? String(a) : "inherited/"*String(a))=>Float64(d) for (a,d) in pairs(v.agents))
        all(isfinite(d) && d>=0 for d in values(agents)) || error("ground_history_agents")
        g.cells[(coords[1],coords[2])]=D("distance"=>Float64(v.distance),"wear"=>Float64(v.wear),"anchor_wear"=>Float64(v.wear)+2*elapsed/day,"last_walk_us"=>Int(v.last_walk_us),"agents"=>agents)
    end
    if haskey(snapshot,:artificial_roads)
        get(snapshot,:artificial_road_rule,nothing)=="linear-lifetime-v1" || error("road_history_rule")
        for (key,v) in pairs(snapshot.artificial_roads)
            coords=parse.(Int,split(String(key),','));length(coords)==2 || error("road_history_cell")
            v.built_us isa Integer && v.lifetime_us isa Integer && 0<=v.built_us<=g.now && 0<v.lifetime_us<typemax(Int)-v.built_us || error("road_history_value")
            g.roads[(coords[1],coords[2])]=D("built_us"=>Int(v.built_us),"lifetime_us"=>Int(v.lifetime_us))
        end
    end
    g
end
