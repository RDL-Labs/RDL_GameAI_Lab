include("../parameters.jl")
include("../perception/task_motion.jl")
include("../configured_paths/task_interrupt.jl")
task_focus_state()=D("active"=>false,"skipped"=>0,"wakeups"=>D())
function task_focus_continue!(s,body,position,yaw,phase,now,motion;enabled=true,shield=true,need=0.,progress=0.)
    get(s,"active",false) || return false
    reason=!enabled ? "disabled" : phase!=s["phase"] ? "phase" : position!=s["position"] || yaw!=s["yaw"] ? "pose" :
        body.reserve<=0 || step(body,s["plan"]["action"],s["load"])[2]!="worked" ? "body" :
        body.reserve<s["reserve"]-TASK_ATTENTION.reserve_change || body.damage>s["damage"] ? "body_change" :
        now>=s["review_us"] ? "review" : nothing
    if reason===nothing && motion!==nothing
        gate=configured_task_interrupt(motion,need,progress;enabled=shield)
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
function task_focus_record!(s,plan,status,body,position,yaw,phase,now,load,home;enabled=true)
    continuing=plan["action"] in ("fish","process_food") && status in ("fishing","processing")
    if !enabled || !continuing
        s["active"]=false;return
    end
    if !get(s,"active",false)
        merge!(s,D("active"=>true,"plan"=>deepcopy(plan),"position"=>position,"yaw"=>yaw,"phase"=>phase,
            "reserve"=>body.reserve,"damage"=>body.damage,"load"=>load,"home"=>deepcopy(home),
            "review_us"=>now+TASK_ATTENTION.review_us))
    end
end
