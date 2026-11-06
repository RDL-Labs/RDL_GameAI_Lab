# A transformation conserves quantity, custody and location. The expiry counter
# is a transfer between species of resource, NOT a loss added to total mass.
function food_expire_fish!(r,w,cargo,food,stock,stores,shared,day)
    r.game.age.enabled && return food_expire_batches!(r,food,stock,shared,day)
    day>=r.game.expiry_day || error("food expiry clock rewind")
    !game_fish_expired(r.game.expiry_day,day) && return shared
    spoiled=RDLBody.SPOILED_FOOD
    for kind in (RDLBody.FISH_FOOD,RDLBody.COOKED_FISH,RDLBody.SALTED_FISH)
    expired=0
    for a in IDS
        for i in eachindex(r.inventory[a])
            r.inventory[a][i]==kind || continue
            r.inventory[a][i]=UInt8(spoiled);food_quality_set!(r,a,i,2);expired+=1
        end
        n=r.personal[a][kind];r.personal[a][kind]=0;r.personal[a][spoiled]+=n;expired+=n
    end
    n=r.shared[kind];r.shared[kind]=0;r.shared[spoiled]+=n;expired+=n
    for entries in values(r.game.stores)
        for q in 1:4;delete!(entries,(kind,q));end
    end
    for j in eachindex(stock)
        r.site_kinds[j]==kind && !fishing_site(food[j]) || continue
        expired+=stock[j];r.site_kinds[j]=UInt8(spoiled);delete!(r.game.sites,j)
        food[j]=merge((;pairs(food[j])...),(food_kind=spoiled,appearance=RDLBody.FOOD_APPEARANCE[spoiled]))
    end
    r.game.expired_fish+=expired
    r.game.expired_by_kind[kind]=get(r.game.expired_by_kind,kind,0)+expired
    end
    r.game.expiry_day=day
    shared
end

function food_age_snapshot(r)
    age=r.game.age
    D("enabled"=>age.enabled,"lifetimes_days"=>collect(FOOD_LIFETIME_DAYS),"inventory_deadlines"=>deepcopy(age.inventory),
      "stores"=>D(a=>[D("kind"=>k,"quality"=>q,"deadline"=>d,"count"=>n) for ((k,q,d),n) in sort!(collect(lots);by=first)] for (a,lots) in age.stores),"site_deadlines"=>copy(age.sites))
end
function food_age_audit!(r)
    r.game.age.enabled || return nothing
    for a in IDS
        length(r.game.age.inventory[a])==length(r.inventory[a]) || error("food age inventory mismatch")
    end
    for (owner,counts) in Iterators.flatten((("shared"=>r.shared,),pairs(r.personal)))
        lots=get(r.game.age.stores,owner,Dict{NTuple{3,Int},Int}())
        all(>(0),values(lots)) || error("invalid food lot size")
        for k in eachindex(counts), q in 1:4
            expected=q==2 ? counts[k]-sum(get(get(r.game.stores,owner,Dict()),(k,v),0) for v in (1,3,4)) : get(get(r.game.stores,owner,Dict()),(k,q),0)
            sum(n for ((kind,quality,d),n) in lots if kind==k && quality==q;init=0)==expected || error("food lot count mismatch")
        end
    end
    nothing
end
function food_expire_batches!(r,food,stock,shared,day)
    day>=r.game.expiry_day || error("food expiry clock rewind")
    day==r.game.expiry_day && return shared
    r.game.expiry_day=day;age=r.game.age;spoiled=RDLBody.SPOILED_FOOD
    function expired!(kind,n)
        r.game.expired_by_kind[kind]=get(r.game.expired_by_kind,kind,0)+n
        kind in (5,7,8) && (r.game.expired_fish+=n)
    end
    for a in IDS, i in eachindex(r.inventory[a])
        k=r.inventory[a][i]
        k!=spoiled && age.inventory[a][i]<=day || continue
        r.inventory[a][i]=UInt8(spoiled);age.inventory[a][i]=typemax(Int);food_quality_set!(r,a,i,2)
        r.progress[a]=(UInt8(0),0);expired!(k,1)
    end
    for (owner,lots) in age.stores
        counts=owner=="shared" ? r.shared : r.personal[owner]
        for ((k,q,d),n) in collect(lots)
            k!=spoiled && d<=day || continue
            delete!(lots,(k,q,d));counts[k]-=n;counts[spoiled]+=n
            if q!=2
                entries=r.game.stores[owner];left=entries[(k,q)]-n
                left==0 ? delete!(entries,(k,q)) : (entries[(k,q)]=left)
            end
            food_quality_store_add!(r,owner,spoiled,2,n);expired!(k,n)
        end
    end
    for j in eachindex(stock)
        k=r.site_kinds[j]
        if k!=spoiled && !fishing_site(food[j]) && get(age.sites,j,typemax(Int))>day
            condition=get(age.sites,j,typemax(Int))-day<=cld(FOOD_LIFETIME_DAYS[k],2) && FOOD_LIFETIME_DAYS[k]>1 ? 1 : 0
            food[j]=merge((;pairs(food[j])...),(condition=condition,))
        end
        k!=spoiled && !fishing_site(food[j]) && get(age.sites,j,typemax(Int))<=day || continue
        expired!(k,stock[j]);r.site_kinds[j]=UInt8(spoiled);age.sites[j]=typemax(Int);delete!(r.game.sites,j)
        food[j]=merge((;pairs(food[j])...),(food_kind=spoiled,appearance=RDLBody.FOOD_APPEARANCE[spoiled],condition=2))
    end
    food_age_audit!(r)
    shared
end

function observed_food_conditions(r,view)
    r===nothing && return D()
    D(a=>food_condition_visuals(r,a,true) for a in keys(get(view,"observed_food_stocks",D())))
end

# Public sensory view. No expiry day, birth date or lot identity leaves this boundary.
function food_condition_visuals(r,a,at_home;shared_stores=false)
    r.game.age.enabled || return Any[]
    totals=Dict{Tuple{Int,Int},Int}()
    stage(k,d)=k==RDLBody.SPOILED_FOOD ? 2 : d-r.game.expiry_day<=cld(FOOD_LIFETIME_DAYS[k],2) && FOOD_LIFETIME_DAYS[k]>1 ? 1 : 0
    for (i,k) in enumerate(r.inventory[a])
        key=(Int(k),stage(k,r.game.age.inventory[a][i]));totals[key]=get(totals,key,0)+1
    end
    if at_home
        for ((k,q,d),n) in get(r.game.age.stores,shared_stores ? "shared" : a,Dict{NTuple{3,Int},Int}())
            key=(k,stage(k,d));totals[key]=get(totals,key,0)+n
        end
    end
    [D("kind"=>k,"appearance"=>RDLBody.FOOD_APPEARANCE[k],"condition"=>s,"count"=>n) for ((k,s),n) in sort!(collect(totals);by=first)]
end
