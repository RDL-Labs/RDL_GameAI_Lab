fishing_site(f)=get(f,:acquisition,"pickup")=="fishing"
function fishing_state!(r,a)
    get!(() -> D("active"=>nothing,"attempts"=>0,"caught"=>0,"interrupted"=>0,
        "sites"=>D(),"records"=>Any[],"rng"=>BasicLoop("$a:fishing";probabilistic=true,seed=get(r.game.fishing,"seed",0)).rng),r.game.fishing,a)
end
function fishing_record!(s,row)
    push!(s["records"],row);length(s["records"])>64 && popfirst!(s["records"])
end
function fishing_cancel!(r,a,now,reason)
    s=get(r.game.fishing,a,nothing);s===nothing && return
    active=s["active"];active===nothing && return
    s["interrupted"]+=1
    fishing_record!(s,D("us"=>now,"status"=>"interrupted","site"=>active["site"],"ticks"=>active["ticks"],"reason"=>reason))
    s["active"]=nothing
end
function fishing_tick!(r,w,cargo,food,stock,a,j,now,op)
    # Replays of the same completed or partial tick cannot consume RNG/resources twice.
    s=fishing_state!(r,a);receipt=get(s,"receipt",nothing)
    if receipt!==nothing && receipt["us"]==now
        receipt["site"]==j && receipt["op"]==op || error("fishing operation conflict")
        return receipt["status"]
    end
    receipt!==nothing && now<receipt["us"] && error("fishing time rewind")
    legal=1<=j<=length(food) && fishing_site(food[j]) &&
        hypot(w.positions[a][1]-food[j].x,w.positions[a][2]-food[j].z)<=1.25 &&
        !any(o->segment_hit(w.positions[a],(Float64(food[j].x),Float64(food[j].z)),o,0.),w.obstacles)
    status="fishing_unavailable"
    if legal
        active=s["active"]
        if active!==nothing && (active["site"]!=j || active["last_us"]+1_000_000!=now)
            fishing_cancel!(r,a,now,"interrupted_or_changed_site");active=nothing
        end
        if active===nothing
            skills=get(r.game.skills,a,D())
            skill=game_skill_forecast(get(skills,"fishing",game_skill_mb()),"fishing")
            active=D("site"=>j,"ticks"=>0,"last_us"=>now,"effect"=>(r.game.enabled ? skill.effect : 0.),"probability"=>game_fishing_probability(r.game.enabled ? skill.effect : 0.))
            s["active"]=active
        end
        active["ticks"]+=1;active["last_us"]=now;status="fishing"
        if active["ticks"]>=GAME_FISHING_TICKS
            # A miss never proves absence; latent stock only governs the world receipt.
            river=get(food[j],:river_id,nothing)!==nothing
            field=river ? river_fishing_field(food,stock,j,active["effect"]) : nothing
            probability=river ? field.probability : active["probability"]
            roll=rand(s["rng"]);caught=roll<probability && (river || stock[j]>0)
            donor=caught ? (river ? river_fishing_take!(stock,field.neighbors,s["rng"]) : j) : nothing
            caught=caught && donor!==nothing
            s["attempts"]+=1;s["caught"]+=Int(caught)
            evidence=get!(() -> D("attempts"=>0,"caught"=>0),s["sites"],string(j))
            evidence["attempts"]+=1;evidence["caught"]+=Int(caught)
            recent=get!(() -> Bool[],evidence,"recent");push!(recent,caught)
            length(recent)>GAME_FISHING_RECENT_TRIALS && popfirst!(recent)
            if r.game.enabled
                skills=get!(() -> D(),r.game.skills,a)
                game_skill_complete!(get!(game_skill_mb,skills,"fishing"),"fishing";product_quality=false)
            end
            if caught
                !river && (stock[j]-=1);w.inventory[a]+=1;push!(cargo[a],op)
                food_push!(r,a,r.site_kinds[j]);status="picked_up"
            else
                status="no_catch"
            end
            fishing_record!(s,D("us"=>now,"site"=>j,"status"=>status,"probability"=>probability,"donor_cell"=>donor,"local_fraction"=>(river ? field.fraction : nothing),"roll"=>roll,"ticks"=>active["ticks"]))
            s["active"]=nothing
        end
    else
        fishing_cancel!(r,a,now,"unavailable")
    end
    s["receipt"]=D("us"=>now,"site"=>j,"op"=>op,"status"=>status)
    status
end
function fishing_snapshot(r)
    D(a=>D("attempts"=>s["attempts"],"caught"=>s["caught"],"interrupted"=>s["interrupted"],
        "active"=>deepcopy(s["active"]),"sites"=>deepcopy(s["sites"]),"records"=>deepcopy(s["records"]))
      for (a,s) in r.game.fishing if a!="seed")
end
