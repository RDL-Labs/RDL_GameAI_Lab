# Run separately against a frozen source tree and the working source tree.
# This replays historical exchange memories in controlled current observations;
# it is a planner benchmark, not a continuation of the old 180-day experiment.
using JSON3, Statistics, Profile, SHA, Random
length(ARGS)==3 || error("usage: benchmark_trade_recall.jl SOURCE_ROOT SUMMARY.json NEW_OUTPUT_DIR")
root=abspath(ARGS[1]);out=abspath(ARGS[3]);ispath(out) && error("fresh output required");mkpath(out)
include(joinpath(root,"src/lw/LW.jl"))
saved=JSON3.read(read(ARGS[2]),NamedTuple{(:incidental_items,),Tuple{Dict{String,Dict{String,Any}}}}).incidental_items
home=(0.,0.);w=LW.world(true)
for (i,a) in enumerate(LW.IDS)
    w.positions[a]=(.3*(i-2),0.);w.inventory[a]=0;w.bodies[a]=LW.Body(10.,0.,90.,0.)
end
counts=[[8,0,8,0],[12,0,4,0],[4,0,12,0]]
stores=Dict(a=>sum(counts[i]) for (i,a) in enumerate(LW.IDS))
objects=[(id=2i+j,kind=j+1,owner=a,location="held",x=0.,z=0.) for (i,a) in enumerate(LW.IDS) for j in 0:1]
spec=(typed_food=true,initial_personal_food_counts=Dict(Symbol(a)=>counts[i] for (i,a) in enumerate(LW.IDS)),loose_items=objects)
foods=LW.food_resources(spec,w,Any[],Int[],0,stores);items=LW.portable_items(spec,w)
cases=Any[]
for a in LW.IDS, mode in ("offer","response")
    state=LW.incidental_item_state(a,33)
    state["exchange_relations"]=deepcopy(saved[a]["exchange_relations"])
    relation=LW.social_relations_state(a;relational=true)
    relation["social_view"]=LW.D("peers"=>[LW.D("ref"=>b,"expression"=>(distress=.8,fear=0.)) for b in LW.IDS if b!=a])
    view=LW.item_visible(items,w,home,a,0.,0;open_stores=true,foods)
    if mode=="response"
        other=first(b for b in LW.IDS if b!=a)
        view["incoming"]=Any[LW.D("id"=>"fixture","proposer"=>other,"round"=>0,
            "give_items"=>Int[],"want_items"=>[first(view["own"]["held"])["ref"]],
            "give_food"=>zeros(Int,4),"want_food"=>zeros(Int,4))]
    end
    mind=LW.item_social_state!(state);mind[mode=="offer" ? "offer" : "response"].H=4.
    push!(cases,(a=a,mode=mode,state=state,relation=relation,view=view,body=w.bodies[a],stock=foods.personal[a]))
end
function invoke(c,s,r)
    LW.item_social_plan!(s,c.view,c.body,nothing,c.stock,0;relation=r)
end
for c in cases, _ in 1:2;invoke(c,deepcopy(c.state),deepcopy(c.relation));end
times=[Float64[] for _ in cases];bytes=[Int[] for _ in cases];gcs=[Float64[] for _ in cases]
decisions=Any[]
for repeat in 1:5, (i,c) in enumerate(cases)
    state=deepcopy(c.state);relation=deepcopy(c.relation);GC.gc()
    t=@timed invoke(c,state,relation)
    push!(times[i],t.time);push!(bytes[i],t.bytes);push!(gcs[i],t.gctime)
    if repeat==1
        push!(decisions,(actor=c.a,mode=c.mode,plan=t.value,state=LW.incidental_item_snapshot(state),relation=LW.social_relations_snapshot(relation)))
    end
end
rows=[(actor=c.a,mode=c.mode,memory=length(c.state["exchange_relations"]),seconds=times[i],bytes=bytes[i],gc=gcs[i],median_seconds=median(times[i]),median_bytes=median(bytes[i])) for (i,c) in enumerate(cases)]
write(joinpath(out,"timings.json"),JSON3.write(rows));write(joinpath(out,"decisions.json"),JSON3.write(decisions))
Profile.init(n=4_000_000,delay=.001);Profile.clear()
for _ in 1:5,c in cases
    s=deepcopy(c.state);r=deepcopy(c.relation)
    Profile.@profile invoke(c,s,r)
end
open(joinpath(out,"cpu-flat.txt"),"w") do io;Profile.print(io;format=:flat,sortedby=:count,mincount=5);end
open(joinpath(out,"cpu-tree.txt"),"w") do io;Profile.print(io;format=:tree,mincount=5);end
println(JSON3.write(rows))
# Additional deterministic parity cases, outside the timed region. Include the
# next RNG words from a copy, so accidental extra draws cannot hide in snapshots.
signatures=Any[]
for c in cases, H in (0.,16.), seed in (1,19)
    s=deepcopy(c.state);r=deepcopy(c.relation);role=c.mode=="offer" ? "offer" : "response"
    s["social"][role]=LW.BasicLoop("$(c.a):items-$role";probabilistic=true,seed)
    s["social"][role].H=H
    p=invoke(c,s,r)
    payload=(plan=p,state=LW.incidental_item_snapshot(s),relation=LW.social_relations_snapshot(r),rng=rand(copy(s["social"][role].rng),UInt64,8))
    push!(signatures,(actor=c.a,mode=c.mode,H=H,seed=seed,sha256=bytes2hex(sha256(JSON3.write(payload)))))
end
write(joinpath(out,"parity.json"),JSON3.write(signatures))
