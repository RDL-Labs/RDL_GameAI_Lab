# Observer-only world metrics. Never read by policy, MB, reward, or RNG.
# Same 1.25 world-unit radius as the existing deposit legality test; not a new rule.
const HOME_ACTIVITY_RADIUS=1.25
home_activity_inside(position,home)=hypot(position[1]-home[1],position[2]-home[2])<=HOME_ACTIVITY_RADIUS
home_activity_counts()=D("returns"=>0,"departures"=>0,"unload_count"=>0,"unloaded_units"=>0)
function home_activity_attach!(storage_stats,positions,home,start_us)
    get!(storage_stats,"home_activity") do
        totals=D(a=>merge(home_activity_counts(),D("inside"=>home_activity_inside(p,home))) for (a,p) in positions)
        D("observer_only"=>true,"recording_started_us"=>start_us,"totals"=>totals,
            "day"=>0,"actors"=>D(),"events"=>Any[])
    end
end
function home_activity_day!(state,completed_us,day_us)
    # A tick ending exactly at midnight belongs to the day it just executed.
    day=div(max(0,completed_us-1),day_us)+1
    if state["day"]!=day
        state["day"]=day
        state["actors"]=D(a=>home_activity_counts() for a in keys(state["totals"]))
        empty!(state["events"])
    end
end
function home_activity_position!(state,actor,position,home,load,completed_us,day_us)
    home_activity_day!(state,completed_us,day_us)
    total=state["totals"][actor];inside=home_activity_inside(position,home)
    inside==total["inside"] && return
    kind=inside ? "returns" : "departures"
    total[kind]+=1;state["actors"][actor][kind]+=1;total["inside"]=inside
    push!(state["events"],D("actor"=>actor,"us"=>completed_us,"kind"=>kind,
        "position"=>collect(position),"load"=>load))
end
function home_activity_unload!(state,actor,amount,position,completed_us,day_us)
    amount>0 || return # Empty deposits and failed attempts are not unloading.
    home_activity_day!(state,completed_us,day_us)
    for counts in (state["totals"][actor],state["actors"][actor])
        counts["unload_count"]+=1;counts["unloaded_units"]+=amount
    end
    push!(state["events"],D("actor"=>actor,"us"=>completed_us,"kind"=>"unload",
        "position"=>collect(position),"amount"=>amount))
end
home_activity_snapshot(state)=deepcopy(state)
