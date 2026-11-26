# Counters/timing on a frozen day replay; no changed policy or logging per tick.
using JSON3, Serialization, Test
length(ARGS)==3 || error("usage TRADE_AUDIT_ROOT TRADE_AUDIT_DAY OUTPUT")
const TRADE_AUDIT_ROOT=abspath(ARGS[1]);const TRADE_AUDIT_DAY=parse(Int,ARGS[2]);const TRADE_AUDIT_OUT=abspath(ARGS[3])
ispath(TRADE_AUDIT_OUT) && error("fresh output required");mkpath(TRADE_AUDIT_OUT)
include(joinpath(TRADE_AUDIT_ROOT,"source/integrations/lightweight_julia/native.jl"))
const TRADE_AUDIT_COUNTS=D();const TRADE_AUDIT_COST=D()
function count_trade(a,key)
    c=get!(() -> D(),TRADE_AUDIT_COUNTS,a);c[key]=get(c,key,0)+1
end
function context_trade(state,view,body,stock,need)
    a=state["actor"];count_trade(a,"evaluations")
    count_trade(a,isempty(view["incoming"]) ? "initiating" : "responding")
    count_trade(a,isempty(view["trade_partners"]) ? "no_partner" : "has_partner")
    count_trade(a,body_demand(body)<=.05 ? "body_demand_le_005" : "body_demand_gt_005")
    count_trade(a,need>0 ? "forecast_shortfall" : "no_forecast_shortfall")
    count_trade(a,any(observed_food_candidate_count(view,p,k)>0 for p in view["trade_partners"] for k in RDLBody.FOOD_KIND_IDS) ? "observed_peer_food" : "no_observed_peer_food")
end
src=read(joinpath(TRADE_AUDIT_ROOT,"source/src/lw/decision/item_social.jl"),String)
start=first(findfirst("function item_social_plan!",src));stop=first(findnext("function item_social_executed!",src,start))
code=src[start:prevind(src,stop)]
signature=first(split(code,'\n'))
function patch(old,new)
    occursin(old,code) || error("missing anchor: $old")
    global code=replace(code,old=>new)
end
patch("function item_social_plan!","function measured_trade_inner!")
patch("    require_need && error","    count_trade(state[\"actor\"],\"calls\")\n    require_need && error")
patch("view===nothing && return nothing","view===nothing && (count_trade(state[\"actor\"],\"no_view\");return nothing)")
patch("body_alive(body) && body.strain<.8 && body.damage<1 || return nothing","body_alive(body) && body.strain<.8 && body.damage<1 || (count_trade(state[\"actor\"],\"body_gate\");return nothing)")
patch("!response && !allow_start && return nothing","!response && !allow_start && (count_trade(state[\"actor\"],\"daily_start_gate\");return nothing)")
patch("view[\"outgoing\"]!==nothing)) && return nothing","view[\"outgoing\"]!==nothing)) && (count_trade(state[\"actor\"],\"interval_or_pending\");return nothing)")
patch("loop.trial===nothing || return nothing","loop.trial===nothing || (count_trade(state[\"actor\"],\"active_trial\");return nothing)")
patch("    context=D(\"need\"=>body_demand(body))","    context_trade(state,view,body,available,need)\n    context=D(\"need\"=>body_demand(body))")
patch("    function candidate(other,give,want,gf,wf;offer_id=nothing,counter=false)","    function candidate(other,give,want,gf,wf;offer_id=nothing,counter=false)\n        count_trade(state[\"actor\"],\"candidate_attempts\")")
patch("use_model!==nothing && trade_use_equivalent(prepared,give,want,gf,wf) && return","use_model!==nothing && trade_use_equivalent(prepared,give,want,gf,wf) && (count_trade(state[\"actor\"],\"equivalent\");return)")
patch("        subjective=gradient[\"total\"]","        subjective=gradient[\"total\"]\n        count_trade(state[\"actor\"],subjective>0 ? \"positive\" : \"nonpositive\")")
patch("        isempty(candidates) && return nothing","        isempty(candidates) && (count_trade(state[\"actor\"],\"empty_candidates\");return nothing)")
patch("    plan=choose_method!(loop,candidates,source)","    count_trade(state[\"actor\"],\"selections\")\n    plan=choose_method!(loop,candidates,source)")
Base.include_string(Main,code,"trade-cost-instrumented-inner")
wrapper=signature*"\n"*raw"""
    timing=@timed measured_trade_inner!(state,view,body,gut,stock,now;map,kitchen,relation,require_need,allow_start,communication,compare_incoming,requested_food,supply_request)
    c=get!(() -> D("seconds"=>0.,"bytes"=>0,"gc_seconds"=>0.,"compile_seconds"=>0.),TRADE_AUDIT_COST,state["actor"])
    c["seconds"]+=timing.time;c["bytes"]+=timing.bytes;c["gc_seconds"]+=timing.gctime
    c["compile_seconds"]+=get(timing,:compile_time,0.)
    timing.value
end
"""
Base.include_string(Main,wrapper,"trade-cost-wrapper")
input=JSON3.read(read(joinpath(TRADE_AUDIT_ROOT,"input.json"),String),Dict{String,Any});input["config"]["days"]=TRADE_AUDIT_DAY
write(joinpath(TRADE_AUDIT_OUT,"input.json"),JSON3.write(input));cp(@__FILE__,joinpath(TRADE_AUDIT_OUT,"diagnostic_runner.jl"))
timing=@timed native_main([joinpath(TRADE_AUDIT_OUT,"run"),"--spec",joinpath(TRADE_AUDIT_OUT,"input.json"),"--resume-from",joinpath(TRADE_AUDIT_ROOT,"checkpoints/day-"*lpad(TRADE_AUDIT_DAY-1,3,'0')*".jls")])
write(joinpath(TRADE_AUDIT_OUT,"audit.json"),JSON3.write((day=TRADE_AUDIT_DAY,counts=TRADE_AUDIT_COUNTS,cost=TRADE_AUDIT_COST,total_seconds=timing.time,bytes=timing.bytes,gc_seconds=timing.gctime)))
original=deserialize(joinpath(TRADE_AUDIT_ROOT,"checkpoints/day-"*lpad(TRADE_AUDIT_DAY,3,'0')*".jls")).state
result=JSON3.read(read(joinpath(TRADE_AUDIT_OUT,"run/result.json"),String),Dict{String,Any})
same(a,b)=JSON3.read(JSON3.write(a),Any)==JSON3.read(JSON3.write(b),Any)
@testset "instrumentation observable parity" begin
    @test same(original[:daily][TRADE_AUDIT_DAY],result["daily"][TRADE_AUDIT_DAY])
    @test same(original[:items]["counts"],result["portable_items"]["counts"])
end
write(joinpath(TRADE_AUDIT_OUT,"completed.json"),JSON3.write((day=TRADE_AUDIT_DAY,parity="daily and item counts; not all internal state/RNG")))
println(JSON3.write((counts=TRADE_AUDIT_COUNTS,cost=TRADE_AUDIT_COST)))
