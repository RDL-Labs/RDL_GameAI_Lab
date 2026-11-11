include("../parameters.jl")
include("../perception/task_motion.jl")
include("../configured_paths/task_interrupt.jl")
task_focus_state()=D("active"=>false,"skipped"=>0,"wakeups"=>D())
# A pending obligation survives low-cost attention. Only delivered inbox packets
# are checked here, using observe's visibility window; no peer intent/world scan.
function task_wait_notice(s,inbox,now)
    wait=get(s,"wait",nothing)
    wait===nothing && return nothing
    any(m->get(m,"reply_to",nothing)==wait["message_id"] && get(m,"sender",nothing)==wait["target"] &&
        get(m,"kind",nothing) in ("given","refuse") && 0<=now/1e6-m["time"]<TASK_WAIT_RULES.message_seconds &&
        m["time"]*1e6<wait["deadline"],inbox) && return "wait_reply"
    now>=wait["deadline"] ? "wait_deadline" : nothing
end
function task_focus_continue!(s,body,position,yaw,phase,now,motion;enabled=true,shield=true,need=0.,progress=0.,wait_notice=nothing)
    get(s,"active",false) || return false
    reason=!enabled ? "disabled" : wait_notice!==nothing ? wait_notice : phase!=s["phase"] ? "phase" : position!=s["position"] || yaw!=s["yaw"] ? "pose" :
        body.reserve<=0 || step(body,s["plan"]["action"],s["load"])[2]!=(s["plan"]["action"]=="rest" ? "rested" : "worked") ? "body" :
        body.reserve<s["reserve"]-TASK_ATTENTION.reserve_change || body.damage>s["damage"] ? "body_change" :
        configured_rest_recovered(s,body) ? "recovered" : now>=s["review_us"] ? "review" : nothing
    if reason===nothing && motion!==nothing
        gate=configured_task_interrupt(motion,need,progress;enabled=shield && s["plan"]["action"]!="rest")
        s["last_interrupt"]=D("us"=>now,"distance"=>get(motion,"distance",nothing),
            "radius"=>gate.radius,"need"=>gate.need,"progress"=>gate.progress,"wake"=>gate.wake)
        if gate.wake
            reason="motion"
        else
            s["suppressed_motion"]=get(s,"suppressed_motion",0)+1
        end
    end
    if reason!==nothing
        s["active"]=false;s["wakeups"][reason]=get(s["wakeups"],reason,0)+1
        return false
    end
    s["skipped"]+=1;true
end
function task_focus_record!(s,plan,status,body,position,yaw,phase,now,load,home;enabled=true,rest_enabled=true,pending_wait=nothing)
    s["wait"]=pending_wait===nothing ? nothing : D("kind"=>"aid_reply","message_id"=>pending_wait["message_id"],
        "target"=>pending_wait["target"],"deadline"=>pending_wait["deadline"])
    continuing=(plan["action"] in ("fish","process_food") && status in ("fishing","processing")) || configured_rest_focus(plan,status;enabled=rest_enabled)
    if !enabled || !continuing
        s["active"]=false;return
    end
    if !get(s,"active",false)
        merge!(s,D("active"=>true,"plan"=>deepcopy(plan),"position"=>position,"yaw"=>yaw,"phase"=>phase,
            "reserve"=>body.reserve,"damage"=>body.damage,"strain"=>body.strain,"load"=>load,"home"=>deepcopy(home),
            "review_us"=>now+TASK_ATTENTION.review_us))
    end
end
