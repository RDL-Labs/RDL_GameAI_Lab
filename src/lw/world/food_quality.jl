# Sparse deviations from ordinary quality: no per-product IDs in warehouse stacks.
const FOOD_LIFETIME_DAYS=(5,2,30,10,1,0,1,1) # authored game durations, not food safety guidance
mutable struct FoodAgeState
    enabled::Bool
    inventory::Dict{String,Vector{Int}}
    stores::Dict{String,Dict{NTuple{3,Int},Int}}
    sites::Dict{Int,Int}
end
FoodAgeState()=FoodAgeState(false,Dict{String,Vector{Int}}(),Dict{String,Dict{NTuple{3,Int},Int}}(),Dict{Int,Int}())
food_deadline(r,k)=k==RDLBody.SPOILED_FOOD ? typemax(Int) : r.game.expiry_day+FOOD_LIFETIME_DAYS[k]
function food_acquisition_deadline(r,site)
    deadline=get(r.game.age.sites,site,typemax(Int))
    deadline==typemax(Int) ? food_deadline(r,r.site_kinds[site]) : deadline
end
food_inventory_deadline(r,a,i)=r.game.age.enabled ? r.game.age.inventory[a][i] : food_deadline(r,r.inventory[a][i])
mutable struct FoodGameState
    enabled::Bool
    skills::Dict{String,Any}
    inventory::Dict{String,Dict{Int,Int}}
    stores::Dict{String,Dict{Tuple{Int,Int},Int}}
    sites::Dict{Int,Int}
    fishing::Dict{String,Any}
    expired_by_kind::Dict{Int,Int}
    salted_fish::Int
    expired_fish::Int
    expiry_day::Int
    age::FoodAgeState
end
FoodGameState(enabled=false)=FoodGameState(enabled,Dict{String,Any}(),Dict{String,Dict{Int,Int}}(),Dict{String,Dict{Tuple{Int,Int},Int}}(),Dict{Int,Int}(),Dict{String,Any}(),Dict{Int,Int}(),0,0,0,FoodAgeState())
food_taste_key(kind,q=2)=q==2 ? RDLBody.FOOD_APPEARANCE[kind] : RDLBody.FOOD_APPEARANCE[kind]*":quality:$q"
function food_held_quality(r,a,kind,q)
    any(i->r.inventory[a][i]==kind && (hasproperty(r,:game) ? food_quality(r,a,i)==q : q==2),eachindex(r.inventory[a]))
end
function food_stored_quality_count(r,a,stores,kind,q)
    !hasproperty(r,:game) && return q==2 ? stores[kind] : 0
    owner=stores===r.shared ? "shared" : a
    entries=get(r.game.stores,owner,Dict{Tuple{Int,Int},Int}())
    q==2 ? stores[kind]-sum(get(entries,(Int(kind),v),0) for v in (1,3,4)) : get(entries,(Int(kind),Int(q)),0)
end
food_quality(r,a,i)=get(get(r.game.inventory,a,Dict{Int,Int}()),i,2)
function food_quality_set!(r,a,i,q)
    1<=q<=4 || error("food quality")
    entries=get!(()->Dict{Int,Int}(),r.game.inventory,a)
    q==2 ? delete!(entries,i) : (entries[i]=q)
    q
end
function food_quality_remove!(r,a,i)
    entries=get(r.game.inventory,a,nothing);entries===nothing && return
    # Shift sparse positions in order so deleting one item cannot lose a neighbour.
    delete!(entries,i)
    for j in sort!([j for j in keys(entries) if j>i])
        entries[j-1]=pop!(entries,j)
    end
end
function food_push!(r,a,kind,q=2;deadline=food_deadline(r,kind))
    push!(r.inventory[a],UInt8(kind));q!=2 && food_quality_set!(r,a,length(r.inventory[a]),q)
    r.game.age.enabled && push!(get!(()->Int[],r.game.age.inventory,a),deadline)
end
function food_give!(r,a,b,i=1)
    q=food_quality(r,a,i);deadline=food_inventory_deadline(r,a,i);kind=food_remove!(r,a,i);food_push!(r,b,kind,q;deadline)
end
function food_quality_store_add!(r,owner,kind,q,n=1;deadline=food_deadline(r,kind))
    if r.game.age.enabled && n>0
        lots=get!(()->Dict{NTuple{3,Int},Int}(),r.game.age.stores,owner)
        key=(Int(kind),Int(q),deadline);lots[key]=get(lots,key,0)+n
    end
    q==2 && return
    entries=get!(()->Dict{Tuple{Int,Int},Int}(),r.game.stores,owner)
    key=(Int(kind),Int(q));entries[key]=get(entries,key,0)+n
end
function food_quality_store_take!(r,owner,kind,total;q=0,with_deadline=false)
    total>0 || error("empty quality store")
    entries=get!(()->Dict{Tuple{Int,Int},Int}(),r.game.stores,owner)
    ordinary=total-sum(get(entries,(Int(kind),v),0) for v in (1,3,4))
    ordinary>=0 || error("quality stock mismatch")
    deadline=food_deadline(r,kind)
    if r.game.age.enabled
        lots=r.game.age.stores[owner]
        keys_available=filter(k->k[1]==kind && (q==0 || k[2]==q),collect(keys(lots)))
        isempty(keys_available) && error("food age lot unavailable")
        # Physical withdrawal order within the selected kind/quality.
        key=first(sort!(keys_available;by=k->(k[3],k[2])))
        q=key[2];deadline=key[3]
        lots[key]==1 ? delete!(lots,key) : (lots[key]-=1)
    end
    if q==0
        # Deterministic physical withdrawal, not a cognitive preference rule.
        q=ordinary>0 ? 2 : first(v for v in (1,3,4) if get(entries,(Int(kind),v),0)>0)
    end
    if q==2
        ordinary>0 || error("ordinary quality unavailable")
    else
        key=(Int(kind),Int(q));n=get(entries,key,0);n>0 || error("quality unavailable")
        n==1 ? delete!(entries,key) : (entries[key]=n-1)
    end
    with_deadline ? (q,deadline) : q
end
function food_quality_swap!(r,a,b,give,want)
    # Extract both directions before adding either, including same-kind trades.
    outgoing=Tuple{String,Int,Int,Int}[]
    for (src,dst,counts) in ((a,b,give),(b,a,want)), k in eachindex(counts)
        for i in 1:counts[k]
            q,deadline=food_quality_store_take!(r,src,k,r.personal[src][k]-i+1;with_deadline=true)
            push!(outgoing,(dst,k,q,deadline))
        end
    end
    for (dst,k,q,deadline) in outgoing;food_quality_store_add!(r,dst,k,q;deadline);end
end
function food_skill_forecast(r,a,raw)
    skill=game_food_skill(raw)
    !r.game.enabled || skill===nothing ? nothing :
        game_skill_forecast(get(get(r.game.skills,a,D()),skill,game_skill_mb()),skill)
end
function food_quality_audit!(r)
    for (a,entries) in r.game.inventory, (i,q) in entries
        1<=i<=length(r.inventory[a]) && q in (1,3,4) || error("quality inventory mismatch")
    end
    for (owner,entries) in r.game.stores
        counts=owner=="shared" ? r.shared : r.personal[owner]
        all(k in RDLBody.FOOD_KIND_IDS && q in (1,3,4) && n>0 for ((k,q),n) in entries) || error("quality stack invalid")
        all(sum(get(entries,(k,q),0) for q in (1,3,4))<=counts[k] for k in eachindex(counts)) || error("quality stock mismatch")
    end
end
function food_game_snapshot(r)
    D("fishing"=>fishing_snapshot(r),"enabled"=>r.game.enabled,"rule"=>"logarithmic-v1","quality_labels"=>collect(GAME_QUALITY_LABELS),
      "skills"=>deepcopy(r.game.skills),"inventory_quality"=>deepcopy(r.game.inventory),
      "store_quality"=>D(a=>[D("kind"=>k,"quality"=>q,"count"=>n) for ((k,q),n) in sort!(collect(v);by=first)] for (a,v) in r.game.stores),
      "site_quality"=>copy(r.game.sites))
end
