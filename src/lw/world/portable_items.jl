include("../../data/item_ids.jl")

# Finite world capabilities. This module neither selects an action nor assigns
# value, pleasure, currency status, or social credit to a successful transfer.
const ITEM_OFFER_TTL_US=30_000_000
const ITEM_ACTIONS=("item_pickup","item_drop","item_store","item_retrieve",
    "item_give","item_offer","item_counter","item_accept","item_decline")
item_field(x,k,default)=x isa AbstractDict ? get(x,String(k),get(x,k,default)) : get(x,k,default)
item_hasfield(x,k)=x isa AbstractDict ? haskey(x,String(k)) || haskey(x,k) : hasproperty(x,k)
item_integer(x)=x isa Integer && !(x isa Bool)
item_real(x)=x isa Real && !(x isa Bool) && isfinite(x)
item_kind_valid(x)=item_integer(x) && 1<=x<=65535
item_at_home(w,home,a)=hypot(w.positions[a][1]-home[1],w.positions[a][2]-home[2])<=1.25
item_contact(w,a,b)=b in IDS && b!=a && contact(w,a,b) && w.hearing[a] && w.hearing[b]
item_trade_contact(w,home,a,b)=item_contact(w,a,b) && item_at_home(w,home,a) && item_at_home(w,home,b)
function item_time(now)
    check(item_integer(now) && 0<=now<=typemax(Int)-ITEM_OFFER_TTL_US,"item_time")
    Int(now)
end
function item_push!(v,x,limit)
    push!(v,x)
    length(v)>limit && popfirst!(v)
    nothing
end

function item_properties(entry,defaults)
    label=item_field(entry,:label,defaults["label"])
    color=item_field(entry,:color,defaults["color"])
    size=item_field(entry,:size,defaults["size"])
    mass=item_field(entry,:mass,defaults["mass"])
    light=item_field(entry,:light_source,defaults["light_source"])
    check(label isa AbstractString && !isempty(label) && ncodeunits(label)<=128,"item_label")
    check(color isa AbstractString && !isempty(color) && ncodeunits(color)<=64,"item_color")
    check(item_real(size) && size>0 && isfinite(Float64(size)),"item_size")
    check(item_real(mass) && mass>0 && isfinite(Float64(mass)),"item_mass")
    check(item_real(light) && 0<=light<=1.,"item_light")
    D("label"=>String(label),"color"=>String(color),"size"=>Float64(size),
        "mass"=>Float64(mass),"light_source"=>Float64(light))
end
function item_kind_defaults(kind)
    if kind in ITEM_KIND_IDS
        return D("label"=>ITEM_KIND_LABELS[kind],"color"=>ITEM_COLORS[kind],
            "size"=>ITEM_SIZES[kind],"mass"=>ITEM_MASSES[kind],"light_source"=>ITEM_LIGHT[kind])
    end
    D("label"=>"item_$kind","color"=>"neutral","size"=>.1,"mass"=>.1,"light_source"=>0.)
end
function portable_items(spec,w)
    check(!(item_hasfield(spec,:portable_items) && item_hasfield(spec,:loose_items)),"item_scene_alias_conflict")
    entries=item_field(spec,:loose_items,item_field(spec,:portable_items,nothing))
    entries===nothing && return nothing
    check(entries isa AbstractVector && length(entries)<=256,"portable_items_list")
    check(item_field(spec,:world_history,nothing)===nothing,"portable_items_require_daily_checkpoints")
    registry=Dict{Int,Any}(k=>item_kind_defaults(k) for k in ITEM_KIND_IDS)
    entries_kinds=item_field(spec,:item_kinds,Any[])
    check(entries_kinds isa AbstractVector && length(entries_kinds)<=256,"item_registry")
    declared=Set{Int}()
    for entry in entries_kinds
        kind=item_field(entry,:id,nothing)
        check(item_kind_valid(kind) && !(kind in declared),"item_registry_kind")
        push!(declared,Int(kind))
        registry[Int(kind)]=item_properties(entry,item_kind_defaults(kind))
    end
    limits=item_field(spec,:item_carry_limits,(mass=5.,size=1.))
    limit_mass=item_field(limits,:mass,5.);limit_size=item_field(limits,:size,1.)
    check(item_real(limit_mass) && limit_mass>0 && isfinite(Float64(limit_mass)),"item_carry_mass")
    check(item_real(limit_size) && limit_size>0 && isfinite(Float64(limit_size)),"item_carry_size")
    items=Dict{Int,Any}();initial=Dict{Int,Int}(k=>0 for k in keys(registry))
    for entry in entries
        id=item_field(entry,:id,nothing);kind=item_field(entry,:kind,nothing)
        check(item_integer(id) && 1<=id<=typemax(Int) && !haskey(items,id),"item_id")
        check(item_kind_valid(kind),"item_kind")
        kind=Int(kind)
        if !haskey(registry,kind)
            registry[kind]=item_kind_defaults(kind);initial[kind]=0
        end
        x=item_field(entry,:x,nothing);z=item_field(entry,:z,nothing)
        check(item_real(x) && item_real(z),"item_position")
        properties=item_properties(entry,registry[kind])
        location=item_field(entry,:location,"ground");owner=item_field(entry,:owner,nothing)
        check(location isa AbstractString && location in ITEM_LOCATIONS,"item_location")
        loc=UInt8(findfirst(==(location),ITEM_LOCATIONS))
        check(loc==ITEM_GROUND ? owner===nothing : owner in IDS,"item_owner")
        position=(Float64(x),Float64(z))
        origin=D("id"=>Int(id),"kind"=>Int(kind),"position"=>collect(position),
            "location"=>Int(loc),"owner"=>owner,"source"=>"scene")
        items[Int(id)]=merge(properties,D("id"=>Int(id),"kind"=>kind,"location"=>loc,
            "owner"=>owner,"position"=>position,"origin"=>origin,
            "history"=>Any[],"history_count"=>0))
        initial[kind]+=1
    end
    kind_ids=sort(collect(keys(registry)))
    s=D("items"=>items,"initial_ids"=>sort(collect(keys(items))),"kind_ids"=>kind_ids,"registry"=>registry,
        "kind_index"=>Dict(k=>i for (i,k) in enumerate(kind_ids)),"initial_counts"=>[initial[k] for k in kind_ids],
        "carry_limits"=>D("mass"=>Float64(limit_mass),"size"=>Float64(limit_size)),
        "offers"=>D(),"receipts"=>D(),"clock_us"=>-1,"records"=>Any[],
        "notices"=>D(a=>Any[] for a in IDS),"counts"=>D(k=>0 for k in
            ("picked_up","dropped","stored","retrieved","given","offered","exchanged","declined","expired","unavailable")))
    item_audit!(s,w)
    s
end

function item_audit!(s,w)
    check(sort(collect(keys(s["items"])))==s["initial_ids"],"item_identity_conservation")
    check(sort(collect(keys(s["registry"])))==s["kind_ids"],"item_registry_identity")
    counts=zeros(Int,length(s["kind_ids"]))
    for (id,item) in s["items"]
        check(item["id"]==id && item_kind_valid(item["kind"]) && haskey(s["registry"],item["kind"]),"item_identity")
        check(item["location"] in (ITEM_GROUND,ITEM_HELD,ITEM_STORED),"item_location_state")
        check(item["location"]==ITEM_GROUND ? item["owner"]===nothing : item["owner"] in IDS,"item_owner_state")
        check(all(item_real,item["position"]),"item_position_state")
        check(item_real(item["mass"]) && item["mass"]>0 && item_real(item["size"]) && item["size"]>0,"item_physical_state")
        check(item["origin"]["id"]==id && item["origin"]["kind"]==item["kind"],"item_origin")
        check(length(item["history"])<=32 && item["history_count"]>=length(item["history"]),"item_history_bound")
        counts[s["kind_index"][item["kind"]]]+=1
    end
    check(counts==s["initial_counts"],"item_kind_conservation")
    nothing
end

# Descriptors expose observable physical properties. IDs address world objects;
# they are not proof that a policy has correctly recognized an object's meaning.
function item_descriptor(item)
    D("ref"=>item["id"],"kind"=>Int(item["kind"]),"color"=>item["color"],
        "size"=>item["size"],"mass"=>item["mass"],"light_source"=>item["light_source"],"location"=>Int(item["location"]))
end
function item_inventory(s,a)
    check(a in IDS,"item_actor")
    own=D("held"=>Any[],"stored"=>Any[])
    for id in s["initial_ids"]
        item=s["items"][id];item["owner"]==a || continue
        push!(own[item["location"]==ITEM_HELD ? "held" : "stored"],item_descriptor(item))
    end
    own
end
# A separate non-food carrying budget; food inventory load remains under the
# existing physiology. Injury may make a current load excessive: dropping or
# storing is still possible, but new acquisitions must satisfy the final load.
function item_load(s,a;remove=(),add=())
    mass=0.;size=0.;count=0
    for (id,item) in s["items"]
        held=item["owner"]==a && item["location"]==ITEM_HELD && !(id in remove)
        held || id in add || continue
        mass+=item["mass"];size=max(size,item["size"]);count+=1
    end
    D("mass"=>mass,"size"=>size,"count"=>count)
end
function item_capacity(s,w,a)
    D("mass"=>s["carry_limits"]["mass"]*(1-clamp(w.bodies[a].damage,0.,1.)),"size"=>s["carry_limits"]["size"])
end
function item_can_carry(s,w,a;remove=(),add=())
    load=item_load(s,a;remove,add);capacity=item_capacity(s,w,a)
    load["mass"]<=capacity["mass"]+1e-12*max(1.,capacity["mass"]) &&
        load["size"]<=capacity["size"]+1e-12*max(1.,capacity["size"])
end
item_position(item,w)=item["location"]==ITEM_HELD ? w.positions[item["owner"]] : item["position"]
function item_visible(s,w,home,a,yaw,now;visual_obstacles=w.obstacles)
    check(a in IDS,"item_actor");t=item_time(now)
    angle=yaw isa AbstractDict ? yaw[a] : yaw
    check(item_real(angle),"item_yaw")
    visible=Any[];p=w.positions[a];sn,cs=sincos(deg2rad(angle))
    for id in s["initial_ids"]
        item=s["items"][id]
        item["location"]==ITEM_STORED && continue
        item["owner"]==a && continue
        q=item_position(item,w);dx,dz=q[1]-p[1],q[2]-p[2]
        f,r=dx*sn+dz*cs,dx*cs-dz*sn;d=hypot(dx,dz)
        d<=12 && (f>=0 || d<=1.25) || continue
        any(o->segment_hit(p,q,o,0.),visual_obstacles) && continue
        row=item_descriptor(item)
        # Other owners' internal category IDs, stores and prior histories are private.
        delete!(row,"kind");delete!(row,"mass")
        merge!(row,D("forward"=>f,"right"=>r,"distance"=>d,"holder"=>item["owner"]))
        push!(visible,row)
    end
    sort!(visible;by=x->(x["distance"],x["ref"]))
    resize!(visible,min(32,length(visible)))
    partners=String[b for b in IDS if item_contact(w,a,b)]
    offers=sort(collect(values(s["offers"]));by=o->o["id"])
    incoming=Any[deepcopy(o) for o in offers if o["target"]==a && t<o["expires_us"] && o["proposer"] in partners]
    outgoing=findfirst(o->o["proposer"]==a && t<o["expires_us"],offers)
    D("visible"=>visible,"own"=>item_inventory(s,a),"own_load"=>item_load(s,a),
        "carry_capacity"=>item_capacity(s,w,a),"partners"=>partners,
        "trade_partners"=>String[b for b in partners if item_trade_contact(w,home,a,b)],
        "incoming"=>incoming,"outgoing"=>outgoing===nothing ? nothing : offers[outgoing]["id"],
        "notices"=>deepcopy(s["notices"][a]))
end

function item_light_objects(s,w)
    out=NamedTuple{(:x,:z,:radius,:height,:color,:light_source),Tuple{Float64,Float64,Float64,Float64,String,Float64}}[]
    for id in s["initial_ids"]
        item=s["items"][id]
        item["location"]==ITEM_STORED && continue
        item["light_source"]>0 || continue
        x,z=item_position(item,w)
        push!(out,(x=x,z=z,radius=item["size"]/2,height=0.,color=item["color"],light_source=item["light_source"]))
    end
    out
end

function item_history!(item,a,op,action,now,owner,location,position)
    event=D("actor"=>a,"operation"=>op,"action"=>action,"us"=>now,
        "from_owner"=>item["owner"],"to_owner"=>owner,
        "from_location"=>Int(item["location"]),"to_location"=>Int(location))
    item_push!(item["history"],event,32);item["history_count"]+=1
    item["owner"]=owner;item["location"]=location;item["position"]=position
    nothing
end
function item_record!(s,event)
    item_push!(s["records"],deepcopy(event),64)
    s["counts"][event["status"]]+=1
end
function item_notice!(s,a,event)
    item_push!(s["notices"][a],deepcopy(event),32)
end
function item_close!(s,o,status,now;changes=nothing,reason=nothing)
    delete!(s["offers"],o["id"])
    event=merge(deepcopy(o),D("offer_id"=>o["id"],"status"=>status,"us"=>now,"reason"=>reason))
    item_record!(s,event)
    for a in (o["proposer"],o["target"])
        notice=deepcopy(event)
        if changes!==nothing
            notice["own_before"]=changes[a].before
            notice["own_after"]=changes[a].after
        end
        item_notice!(s,a,notice)
    end
    nothing
end
function item_expire!(s,now)
    t=item_time(now)
    check(t>=s["clock_us"],"item_clock_rewind")
    s["clock_us"]=t
    for id in sort([id for (id,o) in s["offers"] if t>=o["expires_us"]])
        item_close!(s,s["offers"][id],"expired",t)
    end
    nothing
end
function item_terms(ids,food)
    check(ids isa AbstractVector && length(ids)<=4 && all(x->item_integer(x) && 1<=x<=typemax(Int),ids),"item_offer_ids")
    check(length(unique(ids))==length(ids),"item_offer_duplicate")
    check(food isa AbstractVector && length(food)==4 && all(x->item_integer(x) && 0<=x<=4,food) && sum(food)<=4,"item_offer_food")
    (Int[x for x in ids],Int[x for x in food])
end
item_owns(s,a,ids)=all(id->haskey(s["items"],id) && s["items"][id]["owner"]==a && s["items"][id]["location"]!=ITEM_GROUND,ids)
item_food_available(foods,a,counts)=all(iszero,counts) || (foods!==nothing && all(foods.personal[a].>=counts))
function item_own_result(s,foods,a)
    D("items"=>item_inventory(s,a),"food"=>foods===nothing ? nothing : copy(foods.personal[a]))
end

function item_execute!(s,foods,w,stores,home,a,op,action,now;
        item_id=0,target=nothing,offer_id=nothing,give_items=Int[],want_items=Int[],give_food=[0,0,0,0],want_food=[0,0,0,0])
    check(a in IDS && op isa AbstractString && !isempty(op) && ncodeunits(op)<=256,"item_operation_identity")
    check(action in ITEM_ACTIONS,"item_action")
    check(item_integer(item_id) && 0<=item_id<=typemax(Int),"item_target_id")
    t=item_time(now);give,gf=item_terms(give_items,give_food);want,wf=item_terms(want_items,want_food)
    if action in ("item_offer","item_counter")
        check(item_id==0 && target in IDS && target!=a &&
            (action=="item_counter" ? offer_id isa AbstractString : offer_id===nothing),"item_offer_target")
        check(isempty(intersect(give,want)),"item_offer_overlap")
        check(!isempty(give) || !isempty(want),"item_offer_needs_item")
            # A single empty leg expresses a gift proposal or a request. Both
            # still require the recipient's explicit acceptance; no forced take.
    else
        check(isempty(give) && isempty(want) && all(iszero,gf) && all(iszero,wf),"item_unused_terms")
        if action in ("item_accept","item_decline")
            check(item_id==0 && target===nothing && offer_id isa AbstractString && !isempty(offer_id),"item_reply")
        else
            check(item_id>0 && offer_id===nothing,"item_target")
            check(action=="item_give" ? target in IDS && target!=a : target===nothing,"item_give_target")
        end
    end
    signature=(action,Int(item_id),target,offer_id,Tuple(give),Tuple(want),Tuple(gf),Tuple(wf))
    prior=get(s["receipts"],a,nothing)
    if prior!==nothing && t==prior["us"]
        check(prior["op"]==op && prior["signature"]==signature,"item_operation_conflict")
        return deepcopy(prior["result"])
    end
    check(prior===nothing || t>prior["us"],"item_stale_operation")
    item_expire!(s,t)
    status="unavailable";reason="unknown_item";id=offer_id;recorded=false
    own_before=nothing;own_after=nothing
    body=w.bodies[a]
    if !(body.reserve>0 && body.damage<1 && body.strain<1)
        reason="body_limited"
    elseif action in ("item_offer","item_counter")
        previous=action=="item_counter" ? get(s["offers"],offer_id,nothing) : nothing
        if action=="item_counter" && (previous===nothing || previous["target"]!=a || previous["proposer"]!=target)
            reason="counter_not_recipient"
        elseif previous!==nothing && get(previous,"round",0)>=8
            reason="counter_round_limit"
        elseif any(o->o["proposer"]==a,values(s["offers"]))
            reason="outgoing_pending"
        elseif !item_trade_contact(w,home,a,target)
            reason="partner_unavailable"
        elseif !item_owns(s,a,give) || !item_food_available(foods,a,gf)
            reason="own_resources_unavailable"
        elseif foods===nothing && sum(wf)>0
            reason="food_disabled"
        else
            id="$a:$t:$op"
            o=D("id"=>id,"proposer"=>a,"target"=>target,"give_items"=>give,"want_items"=>want,
                "give_food"=>gf,"want_food"=>wf,"created_us"=>t,"expires_us"=>t+ITEM_OFFER_TTL_US)
            if previous!==nothing
                o["counter_of"]=previous["id"];o["round"]=get(previous,"round",0)+1
                o["root_id"]=get(previous,"root_id",previous["id"])
                o["expires_us"]=previous["expires_us"]
                item_close!(s,previous,"declined",t;reason="countered")
            end
            s["offers"][id]=o;status="offered";reason=nothing
            item_record!(s,merge(deepcopy(o),D("status"=>status,"us"=>t)));recorded=true
        end
    elseif action in ("item_accept","item_decline")
        reason="unknown_offer"
        if haskey(s["offers"],id)
            o=s["offers"][id];b=o["proposer"]
            if o["target"]!=a
                reason="not_recipient"
            elseif !item_trade_contact(w,home,a,b)
                reason="partner_unavailable";item_close!(s,o,status,t;reason);recorded=true
            elseif action=="item_decline"
                status="declined";reason=nothing;item_close!(s,o,status,t);recorded=true
            elseif !item_owns(s,b,o["give_items"]) || !item_owns(s,a,o["want_items"]) ||
                    !item_food_available(foods,b,o["give_food"]) || !item_food_available(foods,a,o["want_food"])
                reason="resources_unavailable";item_close!(s,o,status,t;reason);recorded=true
            elseif !item_can_carry(s,w,b;remove=o["give_items"],
                    add=[ref for ref in o["want_items"] if s["items"][ref]["location"]==ITEM_HELD]) ||
                    !item_can_carry(s,w,a;remove=o["want_items"],
                    add=[ref for ref in o["give_items"] if s["items"][ref]["location"]==ITEM_HELD])
                reason="carry_capacity";item_close!(s,o,status,t;reason);recorded=true
            else
                before_b=item_own_result(s,foods,b);own_before=item_own_result(s,foods,a)
                # Validate all resources before changing any ownership or food.
                food_change=sum(o["give_food"])+sum(o["want_food"])>0
                left=right=nothing
                if food_change
                    check(foods!==nothing,"item_food_disabled")
                    left=copy(foods.personal[b]);right=copy(foods.personal[a])
                    check(sum(left)==stores[b] && sum(right)==stores[a],"item_food_storage_mismatch")
                    left.=left.-o["give_food"].+o["want_food"]
                    right.=right.-o["want_food"].+o["give_food"]
                    check(all(>=(0),left) && all(>=(0),right),"item_food_stock")
                end
                for (ids,recipient) in ((o["give_items"],a),(o["want_items"],b)), ref in ids
                    item=s["items"][ref]
                    item_history!(item,a,op,action,t,recipient,item["location"],w.positions[recipient])
                end
                if food_change
                    foods.personal[b].=left;foods.personal[a].=right
                    stores[b]=sum(left);stores[a]=sum(right)
                end
                own_after=item_own_result(s,foods,a);after_b=item_own_result(s,foods,b)
                changes=Dict(a=>(before=own_before,after=own_after),b=>(before=before_b,after=after_b))
                status="exchanged";reason=nothing;item_close!(s,o,status,t;changes);recorded=true
            end
        end
    elseif haskey(s["items"],item_id)
        item=s["items"][item_id];p=w.positions[a];reason="not_owned"
        if action=="item_pickup"
            q=item["position"];reason="not_reachable"
            if item["location"]==ITEM_GROUND && hypot(q[1]-p[1],q[2]-p[2])<=1.25 && !any(o->segment_hit(p,q,o,0.),w.obstacles)
                if item_can_carry(s,w,a;add=(item_id,))
                    item_history!(item,a,op,action,t,a,ITEM_HELD,p);status="picked_up"
                else
                    reason="carry_capacity"
                end
            end
        elseif item["owner"]==a
            reason="wrong_location"
            if action=="item_drop" && item["location"]==ITEM_HELD
                item_history!(item,a,op,action,t,nothing,ITEM_GROUND,p);status="dropped"
            elseif action=="item_store" && item["location"]==ITEM_HELD && item_at_home(w,home,a)
                item_history!(item,a,op,action,t,a,ITEM_STORED,p);status="stored"
            elseif action=="item_retrieve" && item["location"]==ITEM_STORED && item_at_home(w,home,a)
                if item_can_carry(s,w,a;add=(item_id,))
                    item_history!(item,a,op,action,t,a,ITEM_HELD,p);status="retrieved"
                else
                    reason="carry_capacity"
                end
            elseif action=="item_give" && item["location"]==ITEM_HELD && item_contact(w,a,target)
                if item_can_carry(s,w,target;add=(item_id,))
                    item_history!(item,a,op,action,t,target,ITEM_HELD,w.positions[target]);status="given"
                else
                    reason="carry_capacity"
                end
            end
        end
        status!="unavailable" && (reason=nothing)
    end
    result=D("actor"=>a,"operation"=>String(op),"action"=>action,"us"=>t,
        "status"=>status,"reason"=>reason,"item_id"=>Int(item_id),"target"=>target,"offer_id"=>id)
    if own_before!==nothing
        result["own_before"]=own_before;result["own_after"]=own_after
    end
    if !recorded;item_record!(s,result);end
    if status in ("picked_up","dropped","stored","retrieved","given")
        item_notice!(s,a,result)
        status=="given" && item_notice!(s,target,result)
    end
    s["receipts"][a]=D("op"=>String(op),"us"=>t,"signature"=>signature,"result"=>deepcopy(result))
    item_audit!(s,w)
    result
end

function item_snapshot(s)
    items=Any[];remaining=zeros(Int,length(s["kind_ids"]))
    for id in s["initial_ids"]
        item=deepcopy(s["items"][id])
        item["position"]=item["location"]==ITEM_GROUND ? collect(item["position"]) : nothing
        remaining[s["kind_index"][item["kind"]]]+=1;push!(items,item)
    end
    D("rule"=>"portable-nonfood-items-v2","items"=>items,"kind_ids"=>copy(s["kind_ids"]),
        "registry"=>[merge(D("id"=>k),deepcopy(s["registry"][k])) for k in s["kind_ids"]],
        "carry_limits"=>copy(s["carry_limits"]),"initial_counts"=>copy(s["initial_counts"]),
        "remaining_counts"=>remaining,"counts"=>copy(s["counts"]),
        "active"=>[deepcopy(o) for (_,o) in sort(collect(s["offers"]);by=first)],"records"=>deepcopy(s["records"]))
end
