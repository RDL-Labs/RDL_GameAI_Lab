# Read-only instrumented replay of frozen source; counters do not feed decisions.
using JSON3,Serialization,Test
length(ARGS)==2 || error("usage ROOT OUT")
const TRACE_ROOT=abspath(ARGS[1]);const TRACE_OUT=abspath(ARGS[2]);mkpath(TRACE_OUT)
include(joinpath(TRACE_ROOT,"source/integrations/lightweight_julia/native.jl"))
const TRACE_COUNTS=D();const TRACE_CONTEXTS=D();const TRACE_SAMPLES=D();const TRACE_CASES=Set{String}()
function trace_count(a,label)
 row=get!(() -> D(),TRACE_COUNTS,a);row[label]=get(row,label,0)+1
end
function trace_sample(a,label,row)
 rows=get!(() -> Any[],TRACE_SAMPLES,"$a:$label")
 length(rows)<8 && push!(rows,row)
end
function trace_context(state,view,body,gut,stock,now,map,kitchen,relation,need,prepared,model)
 a=state["actor"];trace_count(a,"evaluation_context")
 partners=get(view,"trade_partners",String[]);visible=view["visible"]
 trace_count(a,isempty(partners) ? "no_partner" : "has_partner")
 trace_count(a,isempty(visible) ? "no_visible_items" : "has_visible_items")
 trace_count(a,any(observed_food_candidate_count(view,p,k)>0 for p in partners for k in RDLBody.FOOD_KIND_IDS) ? "observed_peer_food" : "no_observed_peer_food")
 trace_count(a,stock[5]>0 ? "owns_raw_fish" : "no_raw_fish")
 trace_count(a,need>0 ? "food_shortfall" : "no_food_shortfall")
 cooking=model!==nothing && any(r->r["salt"]>0,model["recipes"])
 trace_count(a,cooking ? "salt_recipe_available" : "salt_recipe_unavailable")
 before_salt=model===nothing ? 0 : trade_use_salts(view["own"],model)
 outlook=model===nothing ? nothing : trade_use_outlook(stock,before_salt,model)
 trace_sample(a,"context",D("us"=>now,"stock"=>copy(stock),"need"=>need,"partners"=>partners,"visible"=>length(visible),"salt"=>before_salt,"outlook"=>outlook,"position"=>kitchen.position,"salt_recipe"=>cooking))
 casekey="$a:$(stock[5]>0):$cooking:$(isempty(partners))"
 if !isempty(partners) && !(casekey in TRACE_CASES) && length(TRACE_CASES)<12
  push!(TRACE_CASES,casekey)
  serialize(joinpath(TRACE_OUT,"case-$(length(TRACE_CASES)).jls"),(state=state,view=view,body=body,gut=gut,stock=stock,now=now,map=map,kitchen=kitchen,relation=relation))
 end
end
src=read(joinpath(TRACE_ROOT,"source/src/lw/decision/item_social.jl"),String)
start=first(findfirst("function item_social_plan!",src));stop=first(findnext("function item_social_executed!",src,start))
code=src[start:prevind(src,stop)]
function patch(old,new)
 occursin(old,code)||error("instrumentation anchor missing: $old")
 global code=replace(code,old=>new)
end
patch("    require_need && error", "    trace_count(state[\"actor\"],\"calls\")\n    require_need && error")
patch("view===nothing && return nothing","view===nothing && (trace_count(state[\"actor\"],\"no_view\");return nothing)")
patch("body_alive(body) && body.strain<.8 && body.damage<1 || return nothing","body_alive(body) && body.strain<.8 && body.damage<1 || (trace_count(state[\"actor\"],\"body_gate\");return nothing)")
patch("!response && !allow_start && return nothing","!response && !allow_start && (trace_count(state[\"actor\"],\"start_gate\");return nothing)")
patch("view[\"outgoing\"]!==nothing)) && return nothing","view[\"outgoing\"]!==nothing)) && (trace_count(state[\"actor\"],\"pending_or_interval\");return nothing)")
patch("loop.trial===nothing || return nothing","loop.trial===nothing || (trace_count(state[\"actor\"],\"active_trial\");return nothing)")
patch("    context=D(\"need\"=>body_demand(body))","    trace_context(state,view,body,gut,available,now,map,kitchen,relation,need,prepared,use_model)\n    context=D(\"need\"=>body_demand(body))")
patch("    function candidate(other,give,want,gf,wf;offer_id=nothing,counter=false)","    function candidate(other,give,want,gf,wf;offer_id=nothing,counter=false)\n        trace_count(state[\"actor\"],\"candidate_attempts\")")
patch("gain===nothing && return","gain===nothing && (trace_count(state[\"actor\"],\"infeasible_bundle\");return)")
patch("use_model!==nothing && trade_use_equivalent(prepared,give,want,gf,wf) && return","use_model!==nothing && trade_use_equivalent(prepared,give,want,gf,wf) && (trace_count(state[\"actor\"],\"equivalent_outcome\");return)")
patch("        subjective=gradient[\"total\"]","        subjective=gradient[\"total\"]\n        trace_count(state[\"actor\"],\"valued\")\n        trace_count(state[\"actor\"],subjective>0 ? \"positive\" : \"nonpositive\")\n        trace_sample(state[\"actor\"],\"valuation\",D(\"us\"=>now,\"other\"=>other,\"stock\"=>copy(available),\"give_items\"=>copy(give),\"want_items\"=>copy(want),\"give_food\"=>copy(gf),\"want_food\"=>copy(wf),\"use_transition\"=>use_transition,\"gradient\"=>deepcopy(gradient)))")
patch("        exchange_give=item_exchange_prepared_bundle","        trace_count(state[\"actor\"],\"admitted_by_value\")\n        exchange_give=item_exchange_prepared_bundle")
patch("        isempty(candidates) && return nothing","        isempty(candidates) && (trace_count(state[\"actor\"],\"no_admitted_candidates\");return nothing)")
patch("    plan=choose_method!(loop,candidates,source)","    trace_count(state[\"actor\"],\"selection\")\n    plan=choose_method!(loop,candidates,source)")
Base.include_string(Main,code,"read-only-trade-diagnostic")
input=JSON3.read(read(joinpath(TRACE_ROOT,"input.json"),String),Dict{String,Any});input["config"]["days"]=18
write(joinpath(TRACE_OUT,"input.json"),JSON3.write(input))
# Same on-disk source/code hash and input except day limit: instrumentation only.
measurement=@timed native_main([joinpath(TRACE_OUT,"run"),"--spec",joinpath(TRACE_OUT,"input.json"),"--resume-from",joinpath(TRACE_ROOT,"checkpoints/day-017.jls")])
report=D("day"=>18,"counts"=>TRACE_COUNTS,"samples"=>TRACE_SAMPLES,"cases"=>collect(TRACE_CASES),"seconds"=>measurement.time)
write(joinpath(TRACE_OUT,"audit.json"),JSON3.write(report))
original=deserialize(joinpath(TRACE_ROOT,"checkpoints/day-018.jls")).state
replayed=JSON3.read(read(joinpath(TRACE_OUT,"run/result.json"),String),Dict{String,Any})
jsonsame(a,b)=JSON3.read(JSON3.write(a),Dict{String,Any})==JSON3.read(JSON3.write(b),Dict{String,Any})
@testset "diagnostic replay observable parity" begin
 @test jsonsame(original[:daily][18],replayed["daily"][18])
 @test jsonsame(original[:items]["counts"],replayed["portable_items"]["counts"])
end
write(joinpath(TRACE_OUT,"completed.json"),JSON3.write((day=18,seconds=measurement.time,parity="daily18 and item counts; not all state/RNG")))
println(JSON3.write(TRACE_COUNTS))
