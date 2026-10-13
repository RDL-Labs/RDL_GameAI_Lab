# World history, ported from integrations/lightweight/ground_wear.py.
mutable struct GroundWear
    cells::Dict{Tuple{Int,Int},Any}
    receipts::Dict{String,Any}
    now::Int
    day::Int
    recovery::Bool
    operations::Int
end
GroundWear(day;recovery=true)=GroundWear(Dict{Tuple{Int,Int},Any}(),Dict{String,Any}(),0,day,recovery,0)
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
    c=wear_cell!(g,(floor(Int,p[1]),floor(Int,p[2])))
    c===nothing ? 1. : 1-.5*min(1.,c["wear"]/10)
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
      "operations"=>g.operations,"cells"=>cells)
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
    g
end
