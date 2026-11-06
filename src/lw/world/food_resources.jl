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
    game::FoodGameState
    waste::Dict{String,Any}
end
function checked_food_kind(value)
    value isa Integer && !(value isa Bool) && value in RDLBody.FOOD_KIND_IDS || error("food_kind must be a known numeric ID")
    UInt8(value)
end
site_food_kind(f)=checked_food_kind(get(f,:food_kind,RDLBody.FRUIT_FOOD))
function food_count_vector(value,total)
    value!==nothing && !(length(value) in (4,5,6,7,length(RDLBody.FOOD_KIND_IDS)) && all(x->x isa Integer && !(x isa Bool) && x>=0,value)) && error("food counts must be nonnegative integers")
    counts=value===nothing ? vcat(total,zeros(Int,length(RDLBody.FOOD_KIND_IDS)-1)) : Int[x for x in value]
    length(counts)<length(RDLBody.FOOD_KIND_IDS) && append!(counts,zeros(Int,length(RDLBody.FOOD_KIND_IDS)-length(counts)))
    length(counts)==length(RDLBody.FOOD_KIND_IDS) && all(>=(0),counts) && sum(counts)==total || error("food kind counts disagree with total")
    counts
end
function food_resources(spec,w,food,stock,shared,stores)
    kinds=site_food_kind.(food)
    enabled=get(spec,:typed_food,false)
    enabled isa Bool || error("typed_food must be Bool")
    if !enabled
        all(==(RDLBody.FRUIT_FOOD),kinds) || error("nonordinary food requires typed_food")
        return nothing
    end
    get(spec,:world_history,nothing)===nothing || error("typed food world transfer requires daily checkpoints")
    initial_kinds=get(spec,:initial_inventory_kinds,nothing)
    initial_kinds!==nothing && length(initial_kinds)!=length(IDS) && error("initial_inventory_kinds roster")
    inv=Dict{String,Vector{UInt8}}()
    for (i,a) in enumerate(IDS)
        inv[a]=initial_kinds===nothing ? fill(UInt8(RDLBody.FRUIT_FOOD),w.inventory[a]) : checked_food_kind.(initial_kinds[i])
        length(inv[a])==w.inventory[a] || error("initial_inventory_kinds count")
    end
    personal_spec=get(spec,:initial_personal_food_counts,nothing)
    personal=Dict(a=>food_count_vector(personal_spec===nothing ? nothing : get(personal_spec,Symbol(a),nothing),stores[a]) for a in IDS)
    shared_kinds=food_count_vector(get(spec,:initial_shared_food_counts,nothing),shared)
    game_enabled=get(spec,:game_proficiency,true)
    game_enabled isa Bool || error("game_proficiency must be Bool")
    r=FoodResources(kinds,inv,personal,shared_kinds,zeros(Int,length(RDLBody.FOOD_KIND_IDS)),zeros(Int,length(RDLBody.FOOD_KIND_IDS)),zeros(Int,length(RDLBody.FOOD_KIND_IDS)),zeros(Int,length(RDLBody.FOOD_KIND_IDS)),
        Dict(a=>(UInt8(0),0) for a in IDS),Dict(a=>0 for a in IDS),Dict(a=>0. for a in IDS),Any[],zeros(Int,length(RDLBody.FOOD_KIND_IDS)),FoodGameState(game_enabled),
        D("counts"=>zeros(Int,length(RDLBody.FOOD_KIND_IDS)),"facilities"=>D(),"records"=>Any[],"last"=>D()))
    food_remaining!(r,stock)
    r.initial.=r.scratch
    get(spec,:food_batch_expiry,false) isa Bool || error("food_batch_expiry must be Bool")
    r.game.age.enabled=get(spec,:food_batch_expiry,false)
    if r.game.age.enabled
        for a in IDS
            r.game.age.inventory[a]=[food_deadline(r,k) for k in r.inventory[a]]
        end
        for (owner,counts) in Iterators.flatten((("shared"=>r.shared,),pairs(r.personal)))
            for k in eachindex(counts)
                counts[k]>0 && food_quality_store_add!(r,owner,k,2,counts[k])
            end
        end
        for j in eachindex(stock)
            # Unharvested world supply has no food-storage clock yet.
            r.game.age.sites[j]=typemax(Int)
        end
    end
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
    food_quality_audit!(r)
    all(>=(0),r.waste["counts"]) || error("negative waste count")
    for k in RDLBody.FOOD_KIND_IDS
        sum(v[k] for v in values(r.waste["facilities"]);init=0)==r.waste["counts"][k] || error("waste facility mismatch")
    end
    all(length(r.inventory[a])==w.inventory[a] && sum(r.personal[a])==stores[a] for a in IDS) || error("typed inventory mismatch")
    sum(r.shared)==shared && all(>=(0),r.shared) && all(a->all(>=(0),r.personal[a]),IDS) || error("typed storage mismatch")
    sum(r.consumed)==w.consumed || error("typed consumption mismatch")
    food_remaining!(r,stock)
    for k in RDLBody.FOOD_KIND_IDS
        produced=sum(r.processed[j] for j in RDLBody.FOOD_KIND_IDS if RDLBody.FOOD_PROCESS_OUTPUT[j]==k;init=0)
        k==RDLBody.COOKED_FISH && (produced-=r.game.salted_fish)
        k==RDLBody.SALTED_FISH && (produced+=r.game.salted_fish)
        r.initial[k]+r.added[k]+produced+(k==RDLBody.SPOILED_FOOD ? sum(values(r.game.expired_by_kind)) : 0)==r.scratch[k]+r.consumed[k]+r.processed[k]+get(r.game.expired_by_kind,k,0)+r.waste["counts"][k] || error("food kind conservation: $k")
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
    r.game.age.enabled && deleteat!(r.game.age.inventory[a],i)
    food_quality_remove!(r,a,i)
    kind=r.inventory[a][i];deleteat!(r.inventory[a],i)
    r.progress[a][1]==kind && (r.progress[a]=(UInt8(0),0))
    kind
end
function food_deposit!(r,a,shared_stores)
    store=shared_stores ? r.shared : r.personal[a]
    for (i,k) in enumerate(r.inventory[a])
        food_quality_store_add!(r,shared_stores ? "shared" : a,k,food_quality(r,a,i);deadline=food_inventory_deadline(r,a,i));store[k]+=1
    end
    delete!(r.game.inventory,a)
    empty!(r.inventory[a]);r.progress[a]=(UInt8(0),0)
    r.game.age.enabled && empty!(r.game.age.inventory[a])
end
function food_retrieve!(r,a,shared_stores,gut,reserve;kind=0,quality=0)
    store=shared_stores ? r.shared : r.personal[a]
    best=0;score=-Inf
    for k in RDLBody.FOOD_KIND_IDS
        kind!=0 && k!=kind && continue
        store[k]>0 || continue
        kind==0 && !RDLBody.food_edible(k) && RDLBody.FOOD_PROCESS_OUTPUT[k]==0 && continue
        # Initial recipe knowledge: a raw ingredient is useful but requires work.
        value=RDLBody.food_edible(k) ? 1+(gut===nothing ? FOOD_LIKING[k] : taste(gut,k,reserve)) : 0.
        if value>score;best=k;score=value;end
    end
    best>0 || error("retrieve from empty typed store")
    q,deadline=food_quality_store_take!(r,shared_stores ? "shared" : a,best,store[best];q=quality,with_deadline=true)
    store[best]-=1;food_push!(r,a,best,q;deadline)
    best
end
function food_meal_index(r,a,gut,reserve,kind;quality=0)
    kind==0 && return food_best_edible(r,a,gut,reserve)
    RDLBody.food_edible(kind) || return 0
    something(findfirst(i->r.inventory[a][i]==kind && (quality==0 || food_quality(r,a,i)==quality),eachindex(r.inventory[a])),0)
end
function food_process!(r,a;kind=0,salt_id=nothing,items=nothing,now=0)
    salt=nothing
    if salt_id!==nothing
        salt=items===nothing ? nothing : get(items["items"],salt_id,nothing)
        if kind!=RDLBody.FISH_FOOD || salt===nothing || salt["kind"]!=ROCK_SALT_ITEM ||
           salt["owner"]!=a || !(salt["location"] in (ITEM_HELD,ITEM_STORED))
            return "preparation_unavailable"
        end
    end
    raw=findfirst(k->RDLBody.FOOD_PROCESS_OUTPUT[k]!=0 && (kind==0 || k==kind),r.inventory[a])
    raw===nothing && return "no_ingredient"
    kind=r.inventory[a][raw];old,done=r.progress[a]
    recipe=salt===nothing ? kind : UInt8(RDLBody.SALTED_FISH)
    done=old==recipe ? done+1 : 1;r.work_ticks[a]+=1
    if done>=RDLBody.FOOD_PROCESS_TICKS[kind]
        skill=game_food_skill(kind)
        if r.game.enabled && skill!==nothing
            skills=get!(()->D(),r.game.skills,a)
            mb=get!(game_skill_mb,skills,skill)
            product=game_skill_complete!(mb,skill)
            food_quality_set!(r,a,raw,product.quality)
        else
            food_quality_set!(r,a,raw,2)
        end
        r.inventory[a][raw]=UInt8(RDLBody.FOOD_PROCESS_OUTPUT[kind])
        if salt!==nothing
            item_history!(salt,a,"cook:$now:$a","season_fish",now,nothing,ITEM_CONSUMED,salt["position"])
            r.inventory[a][raw]=UInt8(RDLBody.SALTED_FISH)
            r.game.salted_fish+=1
        end
        r.game.age.enabled && (r.game.age.inventory[a][raw]=food_deadline(r,r.inventory[a][raw]))
        r.processed[kind]+=1;r.progress[a]=(UInt8(0),0)
        return "processed"
    end
    r.progress[a]=(recipe,done)
    "processing"
end
function food_record_meal!(r,a,kind,liking,now;quality=2)
    r.consumed[kind]+=1;r.pleasure[a]+=liking
    push!(r.meals,(actor=a,kind=kind,quality=quality,liking=liking,us=now))
    length(r.meals)>64 && popfirst!(r.meals)
end
function food_track_cargo!(r,dropped,food,a,op,action,status,index)
    if status=="dropped"
        j=only(i for (i,origin) in dropped["origins"] if origin.drop_operation==op && origin.dropper==a)
        q=food_quality(r,a,1);deadline=food_inventory_deadline(r,a,1);kind=food_remove!(r,a,1)
        r.game.age.enabled && (r.game.age.sites[j]=deadline)
        q==2 ? delete!(r.game.sites,j) : (r.game.sites[j]=q)
        j>length(r.site_kinds) ? push!(r.site_kinds,kind) : (r.site_kinds[j]=kind)
        food[j]=merge((;pairs(food[j])...),(food_kind=Int(kind),))
    elseif status=="recovered"
        food_push!(r,a,r.site_kinds[index],get(r.game.sites,index,2);deadline=food_acquisition_deadline(r,index))
    end
end
function food_snapshot(r)
    D("age_batches"=>food_age_snapshot(r),"expired_total"=>sum(values(r.game.expired_by_kind)),"waste"=>deepcopy(r.waste),"game_proficiency"=>food_game_snapshot(r),"labels"=>collect(RDLBody.FOOD_KIND_LABELS),"storage_class"=>collect(RDLBody.FOOD_STORAGE),
        "decay_enabled"=>true,"expired_by_kind"=>copy(r.game.expired_by_kind),"expired_fish"=>r.game.expired_fish,"expiry_day"=>r.game.expiry_day,"site_kinds"=>copy(r.site_kinds),"inventory"=>deepcopy(r.inventory),
        "shared"=>copy(r.shared),"personal"=>deepcopy(r.personal),"initial"=>copy(r.initial),
        "added"=>copy(r.added),"consumed"=>copy(r.consumed),"salted_fish"=>r.game.salted_fish,"processed_inputs"=>copy(r.processed),
        "progress"=>copy(r.progress),"work_ticks"=>copy(r.work_ticks),"pleasure"=>copy(r.pleasure),"meals"=>copy(r.meals))
end
