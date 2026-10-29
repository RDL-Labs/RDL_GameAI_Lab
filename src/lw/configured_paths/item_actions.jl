# Explicit operation fixtures only. No preference, collection goal or reward.
# A scheduled action yields to safety, food, social responses and night sleep.
function configured_item_actions(spec,enabled)
    rows=get(spec,:configured_item_actions,Any[])
    check(rows isa AbstractVector && length(rows)<=1024,"configured_item_actions")
    check(enabled || isempty(rows),"configured_items_require_objects")
    schedule=Dict{Tuple{Int,String},Dict{String,Any}}()
    allowed=("actor","us","action","item_id","target","offer_id","give_items","want_items","give_food","want_food")
    for row in rows
        p=D(String(k)=>deepcopy(v) for (k,v) in pairs(row))
        check(all(k->k in allowed,keys(p)),"configured_item_fields")
        actor=get(p,"actor",nothing);t=get(p,"us",nothing)
        check(actor in IDS && t isa Integer && !(t isa Bool) && t>=0 && mod(t,1_000_000)==0,"configured_item_identity")
        check(get(p,"action",nothing) in ITEM_ACTIONS,"configured_item_action")
        key=(Int(t),String(actor));check(!haskey(schedule,key),"configured_item_duplicate")
        delete!(p,"actor");delete!(p,"us")
        p["portable_item_action"]=true
        p["selection_mode"]="configured-item-operation"
        schedule[key]=p
    end
    schedule
end
function configured_item_plan(schedule,actor,now)
    p=get(schedule,(now,actor),nothing)
    p===nothing ? nothing : deepcopy(p)
end
