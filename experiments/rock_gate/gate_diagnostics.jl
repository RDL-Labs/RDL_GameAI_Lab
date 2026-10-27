# Read-only, bounded diagnostics in the isolated source snapshot.
struct GateDiagnosticStop <: Exception end
const gate_diag_io=open(joinpath(out,"gate-decisions.jsonl"),"w")
atexit(()->close(gate_diag_io))
function gate_diag!(stage,a,now,w,yaw,plan,move,obstacles,structures,returning)
    sec=div(now,1_000_000)
    (17_280<=sec<=17_420 || 121_380<=sec<=121_680) || return
    JSON3.write(gate_diag_io,(stage=stage,actor=a,sec=sec,position=w.positions[a],yaw=yaw[a],
        returning=returning,plan=plan,move=move,obstacles=obstacles,structures=structures))
    println(gate_diag_io);flush(gate_diag_io)
end
function instrument_gate_day(s)
    anchor="            if continuous_descent && !get(plan,\"configured_observation\",false)"
    @assert count(anchor,s)==1
    hook="Main.gate_diag!(STAGE,a,now,w,yaw,plan,moves[a],lateral_views[a],ground_continuity ? ground_models[a][\"structures\"] : nothing,returning)"
    s=replace(s,anchor=>"            "*replace(hook,"STAGE"=>"\"before_steering\"")*"\n"*anchor)
    anchor="            plans[a]=plan"
    @assert count(anchor,s)==1
    replace(s,anchor=>"            "*replace(hook,"STAGE"=>"\"selected\"")*"\n"*anchor)
end
