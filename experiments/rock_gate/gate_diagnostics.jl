# Read-only, bounded diagnostics in the isolated source snapshot.
struct GateDiagnosticStop <: Exception end
const gate_diag_io=open(joinpath(out,"gate-decisions.jsonl"),"w")
const gate_diag_stop="--departure-diagnostics" in ARGS ? 46561 : 121681
gate_diag_window(sec)="--departure-diagnostics" in ARGS ? (37320<=sec<=37500 || 39180<=sec<=39360 || 46380<=sec<=46560) : (17_280<=sec<=17_420 || 121_380<=sec<=121_680)
atexit(()->close(gate_diag_io))
function gate_diag!(stage,a,now,w,yaw,plan,move,obstacles,structures,returning)
    sec=div(now,1_000_000)
    gate_diag_window(sec) || return
    JSON3.write(gate_diag_io,(stage=stage,actor=a,sec=sec,position=w.positions[a],yaw=yaw[a],
        returning=returning,plan=plan,move=move,obstacles=obstacles,structures=structures))
    println(gate_diag_io);flush(gate_diag_io)
end
function gate_candidate_diag!(a,now,w,yaw,candidates,s,distance,structures,home)
    sec=div(now,1_000_000);gate_diag_window(sec) || return
    # The existing distribution is read-only: do not draw from the policy RNG.
    probabilities=method_distribution(s,candidates)
    rows=[merge(copy(c),D("probability"=>probabilities[i],
        "learned_reward"=>haskey(s.methods,c["method"]) ? s.methods[c["method"]].reward : 0.,
        "method_H"=>haskey(s.methods,c["method"]) ? s.methods[c["method"]].H : 0.,
        "failure_repulsion_value"=>haskey(s.methods,c["method"]) ? failure_repulsion(s.methods[c["method"]]) : 0.)) for (i,c) in enumerate(candidates)]
    JSON3.write(gate_diag_io,(stage="candidates",actor=a,sec=sec,position=w.positions[a],yaw=yaw[a],
        parent_H=s.H,threshold=s.threshold,probabilistic=s.probabilistic,distance=distance,
        rho=structures["observation"],home=home,candidates=rows))
    println(gate_diag_io);flush(gate_diag_io)
end
function instrument_gate_day(s)
    anchor="                        plan=choose_method!(s,candidates,source)"
    @assert count(anchor,s)==1
    s=replace(s,anchor=>"                        Main.gate_candidate_diag!(a,now,w,yaw,candidates,s,get(mb_maps[a],\"home_distance\",nothing),ground_models[a][\"structures\"],home)\n"*anchor)
    anchor="            if continuous_descent && !get(plan,\"configured_observation\",false)"
    @assert count(anchor,s)==1
    hook="Main.gate_diag!(STAGE,a,now,w,yaw,plan,moves[a],lateral_views[a],ground_continuity ? ground_models[a][\"structures\"] : nothing,returning)"
    s=replace(s,anchor=>"            "*replace(hook,"STAGE"=>"\"before_steering\"")*"\n"*anchor)
    anchor="            plans[a]=plan"
    @assert count(anchor,s)==1
    replace(s,anchor=>"            "*replace(hook,"STAGE"=>"\"selected\"")*"\n"*anchor)
end
