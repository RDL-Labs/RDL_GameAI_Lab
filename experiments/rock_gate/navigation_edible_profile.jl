# Local experimental simplification; raw acorns remain inedible in the world model.
function navigation_edible_profile!(input)
    s=input["scene"];s["food_processing"]=false
    for site in s["food"]
        get(site,"food_kind",1)==3 && (site["food_kind"]=1)
    end
    for kinds in get(s,"initial_inventory_kinds",Any[])
        replace!(kinds,3=>1)
    end
    for counts in values(get(s,"initial_personal_food_counts",Dict()))
        counts[1]+=counts[3];counts[3]=0
    end
    if haskey(s,"initial_shared_food_counts")
        counts=s["initial_shared_food_counts"];counts[1]+=counts[3];counts[3]=0
    end
    input
end
