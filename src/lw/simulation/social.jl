include(joinpath(@__DIR__, "legacy_loop.jl"))
include(joinpath(@__DIR__, "../learning/social_models.jl"))
include("../../data/lw_actor_ids.jl")

include(joinpath(@__DIR__, "../world/contact.jl"))

include(joinpath(@__DIR__, "../perception/social.jl"))

function communicate!(w,a,op,action,target=nothing,reply=nothing)
    key=a*"|"*op;request=(action,target,reply)
    if haskey(w.receipts,key)
        old,result=w.receipts[key];check(old==request,"communication_conflict");return deepcopy(result)
    end
    check(a in IDS && !isempty(op),"identity");check(length(w.receipts)<w.capacity,"capacity")
    check(action in ("request","give","refuse","reach","warn","withdraw","eat","wait"),"action")
    check(target===nothing || (target in IDS && target!=a),"target")
    messages=observe(w,a)["messages"]
    predecessors=[m for m in messages if m["id"]==reply && m["sender"]==target]
    antecedent=isempty(predecessors) ? nothing : predecessors[1]
    status="unavailable";kind=nothing
    if action in ("wait","withdraw")
        status=action
    elseif action=="eat"
        if w.inventory[a]>0
            w.bodies[a],status,_,_=step(w.bodies[a],"eat",0)
            w.inventory[a]-=1;w.consumed+=1
        else
            status="no_food"
        end
    elseif target!==nothing && contact(w,a,target)
        if action in ("request","reach")
            kind=action;status="expressed"
        elseif action in ("give","refuse") && antecedent!==nothing && antecedent["kind"]=="request" && !((a,reply) in w.answered)
            if action=="refuse"
                kind="refuse";status="expressed"
            elseif w.inventory[a]>0
                w.inventory[a]-=1;w.inventory[target]+=1;kind="given";status="transferred"
            end
        elseif action=="warn" && antecedent!==nothing && antecedent["kind"]=="reach"
            kind="warn";status="expressed"
        end
    end
    kind in ("given","refuse") && push!(w.answered,(a,reply))
    if kind!==nothing && (kind in ("reach","given") || w.hearing[target])
        w.inbox[target]=[m for m in w.inbox[target] if w.seconds-m["time"]<3]
        push!(w.inbox[target],D("id"=>a*":"*op,"sender"=>a,"kind"=>kind,"reply_to"=>reply,"time"=>w.seconds))
    end
    r=D("agent"=>a,"operation"=>op,"action"=>action,"status"=>status,"time"=>w.seconds)
    w.receipts[key]=(request,deepcopy(r));r
end
function response(obs,share)
    for m in reverse(obs["messages"])
        action=m["kind"]=="warn" ? "withdraw" : m["kind"]=="reach" ? "warn" : m["kind"]=="request" ? (share && obs["inventory"]>0 ? "give" : "refuse") : nothing
        action!==nothing && return (action,m["sender"],m["id"])
    end
    ("wait",nothing,nothing)
end
function scenario(spec)
    w=world(spec.hearing);states=D(a=>nothing for a in IDS)
    pressure=pressure_update(nothing,D(),"npc_a",3);rows=Any[];nights=Any[]
    for day in 0:2
        b=w.bodies["npc_a"];w.bodies["npc_a"]=Body(b.burst,b.strain,max(0.,b.reserve-20),b.damage)
        for attempt in 0:1
            now=day*DAY+attempt*6_000_000;w.seconds=now/1e6
            obs=observe(w,"npc_a");s=states["npc_a"]===nothing ? social_initial() : states["npc_a"]
            targets=[o["ref"] for o in obs["others"] if o["holding_food"]]
            target,selection=select_target(targets,s["model"],pressure)
            row=D("day"=>day,"attempt"=>attempt,"selection"=>selection)
            if target===nothing
                push!(rows,row);continue
            end
            op="request:$day:$attempt";mid="npc_a:"*op
            r=communicate!(w,"npc_a",op,"request",target)
            @assert communicate!(w,"npc_a",op,"request",target)==r
            s=deepcopy(s);s["pending"]=D("message_id"=>mid,"target"=>target,"deadline"=>now+5_000_000,
                "request_observation_id"=>"ob:$day:$attempt","operation_id"=>op)
            w.seconds=(now+1_000_000)/1e6
            decision=response(observe(w,target),target!="npc_b")
            reply=communicate!(w,target,"reply:$day:$attempt",decision...)
            capture=now+(decision[1]!="wait" ? 2_000_000 : 5_000_000);w.seconds=capture/1e6
            p=D("agent_id"=>"npc_a","capture_us"=>capture,"observation_id"=>"end:$day:$attempt","social"=>observe(w,"npc_a"))
            s=ingest(s,p,D(op=>r));pressure=pressure_update(pressure,s["records"],"npc_a",3)
            states["npc_a"]=s
            w.inventory["npc_a"]>0 && communicate!(w,"npc_a","eat:$day:$attempt","eat")
            merge!(row,D("request"=>r,"response"=>reply,"state"=>deepcopy(s),"pressure"=>deepcopy(pressure),"inventory"=>copy(w.inventory)))
            push!(rows,row)
        end
        start=day*DAY+14_400_000_000;night=D()
        for actor in IDS
            learning=sleeper(day)
            for sec in 0:spec.rest_seconds-1
                phase=spec.interrupt && sec==100 ? "safety" : "night"
                w.bodies[actor],_,_,_=step(w.bodies[actor],"rest",w.inventory[actor])
                receipt!(learning,start+sec*1_000_000;phase=phase)
                @assert !receipt!(learning,start+sec*1_000_000;phase=phase)
            end
            cycle=learning["sleep"]["cycle"]
            states[actor]===nothing && (states[actor]=social_initial())
            if spec.adopt
                binding=merge(copy(cycle),D("formation_us"=>start))
                states[actor]=consolidate_social(states[actor],binding,actor)
                @assert consolidate_social(states[actor],binding,actor)==states[actor]
            end
            night[actor]=D("sleep"=>learning["sleep"],"social"=>deepcopy(states[actor]))
        end
        push!(nights,night);@assert sum(values(w.inventory))+w.consumed==24
    end
    D("rows"=>rows,"nights"=>nights,"states"=>states,"pressure"=>pressure,
      "inventory"=>w.inventory,"bodies"=>D(a=>bodydict(w.bodies[a]) for a in IDS),"consumed"=>w.consumed)
end

function boundaries()
    out=D();s=ginitial("a");snapshots=Any[]
    for (i,(confirmed,comparable)) in enumerate(((false,true),(false,false),(false,true),(true,true)))
        id=string(i-1);s=gfinish(gbegin(s,id,D("observation_id"=>id)),id,confirmed,comparable,"end"*id)
        @assert gfinish(s,id,confirmed,comparable,"end"*id)==s
        push!(snapshots,deepcopy(s))
    end
    out["goal_sequence"]=snapshots;errors=D()
    cases=D("conflict"=>(() -> gfinish(s,"3",false,true,"end3")),"reopen"=>(() -> gbegin(s,"3",D())),
        "threshold"=>(() -> ginitial("a","home-trial-confirmation-hypothesis-v1","home_confirmed",0)),
        "bool_threshold"=>(() -> ginitial("a","home-trial-confirmation-hypothesis-v1","home_confirmed",true)),
        "parent"=>(() -> ginitial("a","home-trial-confirmation-hypothesis-v1","home_confirmed",2,"a")),
        "evidence"=>(() -> gfinish(s,"3",1,true,"end3")),
        "active"=>(() -> gbegin(gbegin(ginitial("a"),"x",D()),"y",D())),
        "binding"=>(() -> gfinish(ginitial("a"),"missing",false,true,"end")))
    for (key,fn) in cases
        try fn();error("expected rejection") catch e;errors[key]=e.msg;end
        @assert errors[key]!="expected rejection"
    end
    t=gbegin(ginitial("a"),"safety",D());t["trial"]["interrupted_by_safety"]=true
    out["safety_goal"]=gfinish(t,"safety",false,true,"end");out["sleep"]=D()
    start=17_278_000_000
    for name in ("last","safety","failed","pose","day")
        learning=sleeper(0,REST-1_000_000)
        receipt!(learning,name=="day" ? DAY : start;phase=name=="safety" ? "safety" : "night",
            status=name=="failed" ? "blocked" : "waited",pose=name!="pose")
        out["sleep"][name]=learning
    end
    try receipt!(sleeper(0),start;accepted=false) catch e;errors["sleep_acceptance"]=e.msg;end
    state=social_initial()
    for (i,(t,o)) in enumerate(((1,"given"),(2,"refuse"),(9,"given"),(1,"request_not_executed")))
        id=string(i-1);state["records"][id]=D("agent_id"=>"a","target"=>"b","message_id"=>id,"tick"=>t,"outcome"=>o)
    end
    before=deepcopy(state);cycle=D("status"=>"completed","day"=>0,"formation_us"=>2)
    out["social_cutoff"]=consolidate_social(state,cycle,"a");@assert state==before
    try consolidate_social(state,cycle,"other") catch e;errors["social_agent"]=e.msg;end
    pending=social_initial();pending["pending"]=D("message_id"=>"m","target"=>"b","deadline"=>5,"operation_id"=>"op")
    p=D("capture_us"=>5,"agent_id"=>"a","observation_id"=>"end","social"=>D("messages"=>Any[]))
    out["unexecuted"]=ingest(pending,p,D());@assert pending["pending"]!==nothing
    out["errors"]=errors;out
end
