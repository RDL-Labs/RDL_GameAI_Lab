# Numeric kinds accompany the existing total counts. No per-item identity or age.
mutable struct FoodResources
    site_kinds::Vector{UInt8}
    inventory::Dict{String,Vector{UInt8}}
    personal::Dict{String,Vector{Int}}
    shared::Vector{Int}
    initial::Vector{Int}
    added::Vector{Int}
    consumed::Vector{Int}
    processed::Vector{Int}
    progress::Dict{String,Tuple{UInt8,Int}}
    work_ticks::Dict{String,Int}
    pleasure::Dict{String,Float64}
    meals::Vector{Any}
    scratch::Vector{Int}
end
function checked_food_kind(value)
    value isa Integer && !(value isa Bool) && value in RDLBody.FOOD_KIND_IDS || error("food_kind must be a known numeric ID")
    UInt8(value)
end
site_food_kind(f)=checked_food_kind(get(f,:food_kind,RDLBody.ORDINARY_FOOD))
function food_count_vector(value,total)
    value!==nothing && !(length(value)==length(RDLBody.FOOD_KIND_IDS) && all(x->x isa Integer && !(x isa Bool) && x>=0,value)) && error("food counts must be nonnegative integers")
    counts=value===nothing ? [total,0,0,0] : Int[x for x in value]
    length(counts)==length(RDLBody.FOOD_KIND_IDS) && all(>=(0),counts) && sum(counts)==total || error("food kind counts disagree with total")
    counts
end
function food_resources(spec,w,food,stock,shared,stores)
    kinds=site_food_kind.(food)
    enabled=get(spec,:typed_food,false)
    enabled isa Bool || error("typed_food must be Bool")
    if !enabled
        all(==(RDLBody.ORDINARY_FOOD),kinds) || error("nonordinary food requires typed_food")
        return nothing
    end
    get(spec,:world_history,nothing)===nothing || error("typed food world transfer requires daily checkpoints")
    initial_kinds=get(spec,:initial_inventory_kinds,nothing)
    initial_kinds!==nothing && length(initial_kinds)!=length(IDS) && error("initial_inventory_kinds roster")
    inv=Dict{String,Vector{UInt8}}()
    for (i,a) in enumerate(IDS)
        inv[a]=initial_kinds===nothing ? fill(UInt8(RDLBody.ORDINARY_FOOD),w.inventory[a]) : checked_food_kind.(initial_kinds[i])
        length(inv[a])==w.inventory[a] || error("initial_inventory_kinds count")
    end
    personal_spec=get(spec,:initial_personal_food_counts,nothing)
    personal=Dict(a=>food_count_vector(personal_spec===nothing ? nothing : get(personal_spec,Symbol(a),nothing),stores[a]) for a in IDS)
    shared_kinds=food_count_vector(get(spec,:initial_shared_food_counts,nothing),shared)
    r=FoodResources(kinds,inv,personal,shared_kinds,zeros(Int,4),zeros(Int,4),zeros(Int,4),zeros(Int,4),
        Dict(a=>(UInt8(0),0) for a in IDS),Dict(a=>0 for a in IDS),Dict(a=>0. for a in IDS),Any[],zeros(Int,4))
    food_remaining!(r,stock)
    r.initial.=r.scratch
    r
end
function food_remaining!(r,stock)
    fill!(r.scratch,0)
    length(stock)==length(r.site_kinds) || error("food site kind count")
    for i in eachindex(stock);r.scratch[r.site_kinds[i]]+=stock[i];end
    r.scratch .+= r.shared
    for a in IDS
        r.scratch .+= r.personal[a]
        for kind in r.inventory[a];r.scratch[kind]+=1;end
    end
    r.scratch
end
function food_audit!(r,w,stock,shared,stores)
    all(length(r.inventory[a])==w.inventory[a] && sum(r.personal[a])==stores[a] for a in IDS) || error("typed inventory mismatch")
    sum(r.shared)==shared && all(>=(0),r.shared) && all(a->all(>=(0),r.personal[a]),IDS) || error("typed storage mismatch")
    sum(r.consumed)==w.consumed || error("typed consumption mismatch")
    food_remaining!(r,stock)
    for k in RDLBody.FOOD_KIND_IDS
        produced=sum(r.processed[j] for j in RDLBody.FOOD_KIND_IDS if RDLBody.FOOD_PROCESS_OUTPUT[j]==k;init=0)
        r.initial[k]+r.added[k]+produced==r.scratch[k]+r.consumed[k]+r.processed[k] || error("food kind conservation: $k")
    end
    nothing
end
food_has_edible(r,a)=any(RDLBody.food_edible,r.inventory[a])
food_has_raw(r,a)=any(k->RDLBody.FOOD_PROCESS_OUTPUT[k]!=0,r.inventory[a])
function food_best_edible(r,a,gut,reserve)
    best=0;score=-Inf
    for (i,k) in enumerate(r.inventory[a])
        RDLBody.food_edible(k) || continue
        value=gut===nothing ? FOOD_LIKING[k] : taste(gut,k,reserve)
        if value>score;best=i;score=value;end
    end
    best
end
function food_remove!(r,a,i)
    kind=r.inventory[a][i];deleteat!(r.inventory[a],i)
    r.progress[a][1]==kind && (r.progress[a]=(UInt8(0),0))
    kind
end
function food_deposit!(r,a,shared_stores)
    store=shared_stores ? r.shared : r.personal[a]
    for k in r.inventory[a];store[k]+=1;end
    empty!(r.inventory[a]);r.progress[a]=(UInt8(0),0)
end
function food_retrieve!(r,a,shared_stores,gut,reserve)
    store=shared_stores ? r.shared : r.personal[a]
    best=0;score=-Inf
    for k in RDLBody.FOOD_KIND_IDS
        store[k]>0 || continue
        # Initial recipe knowledge: a raw ingredient is useful but requires work.
        value=RDLBody.food_edible(k) ? 1+(gut===nothing ? FOOD_LIKING[k] : taste(gut,k,reserve)) : 0.
        if value>score;best=k;score=value;end
    end
    best>0 || error("retrieve from empty typed store")
    store[best]-=1;push!(r.inventory[a],UInt8(best))
    best
end
function food_process!(r,a)
    raw=findfirst(k->RDLBody.FOOD_PROCESS_OUTPUT[k]!=0,r.inventory[a])
    raw===nothing && return "no_ingredient"
    kind=r.inventory[a][raw];old,done=r.progress[a]
    done=old==kind ? done+1 : 1;r.work_ticks[a]+=1
    if done>=RDLBody.FOOD_PROCESS_TICKS[kind]
        r.inventory[a][raw]=UInt8(RDLBody.FOOD_PROCESS_OUTPUT[kind])
        r.processed[kind]+=1;r.progress[a]=(UInt8(0),0)
        return "processed"
    end
    r.progress[a]=(kind,done)
    "processing"
end
function food_record_meal!(r,a,kind,liking,now)
    r.consumed[kind]+=1;r.pleasure[a]+=liking
    push!(r.meals,(actor=a,kind=kind,liking=liking,us=now))
    length(r.meals)>64 && popfirst!(r.meals)
end
function food_track_cargo!(r,dropped,food,a,op,action,status,index)
    if status=="dropped"
        j=only(i for (i,origin) in dropped["origins"] if origin.drop_operation==op && origin.dropper==a)
        kind=food_remove!(r,a,1)
        j>length(r.site_kinds) ? push!(r.site_kinds,kind) : (r.site_kinds[j]=kind)
        food[j]=merge((;pairs(food[j])...),(food_kind=Int(kind),))
    elseif status=="recovered"
        push!(r.inventory[a],r.site_kinds[index])
    end
end
function food_snapshot(r)
    D("labels"=>collect(RDLBody.FOOD_KIND_LABELS),"storage_class"=>collect(RDLBody.FOOD_STORAGE),
        "decay_enabled"=>false,"site_kinds"=>copy(r.site_kinds),"inventory"=>deepcopy(r.inventory),
        "shared"=>copy(r.shared),"personal"=>deepcopy(r.personal),"initial"=>copy(r.initial),
        "added"=>copy(r.added),"consumed"=>copy(r.consumed),"processed_inputs"=>copy(r.processed),
        "progress"=>copy(r.progress),"work_ticks"=>copy(r.work_ticks),"pleasure"=>copy(r.pleasure),"meals"=>copy(r.meals))
end
