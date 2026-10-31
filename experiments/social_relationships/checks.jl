# Directed social experience: only the owner's observations and outcomes.
using Test, Serialization, JSON3
include("../../src/lw/LW.jl")
if !isdefined(LW,:social_relations_state)
    Base.include(LW,normpath(joinpath(@__DIR__,"../../src/lw/learning/social_relations.jl")))
end
const SA="npc_a";const SB="npc_b";const SC="npc_c"
const SD=Dict{String,Any}
function saved_relation(x)
    io=IOBuffer();serialize(io,x);seekstart(io);deserialize(io)
end
relation_observation(a,others)=SD("self_id"=>a,"others"=>[SD("ref"=>b,"holding_food"=>false) for b in others])
function relation_event!(s,other,channel,id,t,outcome;value=0.)
    LW.social_relation_event!(s,other,channel,id,t;outcome,value)
end
profile(s,other=SB)=LW.social_relation_profile(s,other)
bias(s,context,other=SB)=LW.social_relation_bias(s,other,context)["weight"]

@testset "unknown peers are neutral and observation stays local" begin
    a=LW.social_relations_state(SA);b=LW.social_relations_state(SB)
    initial=deepcopy(a);unknown=profile(a)
    @test unknown["aid_probability"]==.5 && unknown["trade_probability"]==.5
    @test unknown["benefit"]==0. && unknown["familiarity"]==0.
    @test all(bias(a,c)==0. for c in ("request","give","trade_offer","trade_response"))
    @test a==initial && isempty(a["peers"]) && isempty(b["peers"])
    @test LW.social_relation_bias(nothing,SB,"give")["weight"]==0.
    @test_throws ErrorException LW.social_relations_observe!(a,relation_observation(SB,[SA]),0)
    @test a==initial
    LW.social_relations_observe!(a,relation_observation(SA,[SB]),0)
    @test Set(keys(a["peers"]))==Set([SB]) && isempty(b["peers"])
    @test profile(a)["encounters"]==1
    LW.social_relations_observe!(a,relation_observation(SA,[SB]),1_000_000)
    first_contact=deepcopy(a)
    @test profile(a)["contact_seconds"]>0 && profile(a)["familiarity"]>0
    LW.social_relations_observe!(a,relation_observation(SA,[SB]),1_000_000)
    @test a==first_contact
    LW.social_relations_observe!(a,relation_observation(SA,String[]),2_000_000)
    LW.social_relations_observe!(a,relation_observation(SA,[SB]),3_000_000)
    @test profile(a)["encounters"]==2 && !haskey(a["peers"],SC)
    @test profile(a)["aid_probability"]==.5 && profile(a)["trade_probability"]==.5
    # Merely looking at someone does not fabricate generosity or successful trades.
    @test profile(a)["benefit"]==0. && profile(a)["aid_credit"]==0.
end

@testset "aid, refusal and missing evidence remain separate" begin
    a=LW.social_relations_state(SA);b=LW.social_relations_state(SB);other_before=deepcopy(b)
    @test relation_event!(a,SB,"aid_received","given-1",1,"given")
    good=profile(a);give_bias=bias(a,"give");request_bias=bias(a,"request")
    @test good["aid_probability"]>.5 && good["aid_credit"]>0
    @test give_bias>0 && request_bias>0 && b==other_before
    @test good["trade_probability"]==.5 && good["benefit"]==0.
    @test relation_event!(a,SB,"aid_received","refusal-1",2,"refuse")
    refused=profile(a)
    @test refused["aid_probability"]<good["aid_probability"]
    @test refused["aid_credit"]==good["aid_credit"] && refused["benefit"]==0.
    @test bias(a,"give")==give_bias && bias(a,"request")<request_bias
    # Lack of a reply or a request that never executed is not observed hostility.
    relation_event!(a,SB,"aid_received","silent-1",3,"no_response_observed")
    relation_event!(a,SB,"aid_received","unexecuted-1",4,"request_not_executed")
    missing=profile(a)
    @test missing["aid_probability"]==refused["aid_probability"]
    @test missing["aid_credit"]==refused["aid_credit"] && missing["benefit"]==0.
    @test bias(a,"give")==give_bias
    for i in 1:8;relation_event!(a,SB,"aid_received","recovery-$i",4+i,"given");end
    @test profile(a)["aid_probability"]>good["aid_probability"]
    @test bias(a,"request")>request_bias
    # Giving help yourself is not evidence that the other party has helped you.
    fresh=LW.social_relations_state(SA)
    relation_event!(fresh,SB,"aid_given","self-gift",1,"transferred")
    relation_event!(fresh,SB,"aid_given","self-refusal",2,"refuse")
    @test profile(fresh)["aid_credit"]==0. && profile(fresh)["aid_probability"]==.5
    @test profile(fresh)["benefit"]==0.
end

@testset "trade acceptance and personal value are different relations" begin
    a=LW.social_relations_state(SA);b=LW.social_relations_state(SB)
    relation_event!(a,SB,"trade_offer","trade-1",1,"exchanged";value=.4)
    relation_event!(b,SA,"trade_response","trade-1",1,"exchanged";value=-.2)
    @test profile(a)["trade_probability"]>.5 && profile(a)["benefit"]>0.
    @test profile(b,SA)["trade_probability"]==.5 && profile(b,SA)["benefit"]<0.
    @test bias(a,"trade_response")>0 && bias(b,"trade_response",SA)<0
    before=profile(a);positive_response=bias(a,"trade_response")
    relation_event!(a,SB,"trade_offer","declined-1",2,"declined")
    declined=profile(a)
    @test declined["trade_probability"]<before["trade_probability"]
    @test declined["benefit"]==before["benefit"] && bias(a,"trade_response")==positive_response
    relation_event!(a,SB,"trade_offer","expired-1",3,"expired")
    relation_event!(a,SB,"trade_offer","unavailable-1",4,"unavailable")
    @test profile(a)["trade_probability"]==declined["trade_probability"]
    @test profile(a)["benefit"]==declined["benefit"]
    relation_event!(a,SB,"trade_response","own-decline",5,"declined")
    @test profile(a)["trade_probability"]==declined["trade_probability"]
    @test profile(a)["aid_probability"]==.5 && profile(a)["aid_credit"]==0.
    relation_event!(a,SB,"aid_received","help-after-trade",6,"given")
    @test bias(a,"trade_response")>positive_response
end

@testset "relation receipts prevent double learning and preserve sources" begin
    s=LW.social_relations_state(SA)
    @test relation_event!(s,SB,"trade_offer","once",10,"exchanged";value=.5)
    recorded=deepcopy(s)
    @test !relation_event!(s,SB,"trade_offer","once",10,"exchanged";value=.5)
    @test s==recorded
    @test_throws ErrorException relation_event!(s,SB,"trade_offer","once",10,"exchanged";value=.6)
    @test s==recorded
    @test !relation_event!(s,SB,"trade_offer","older",9,"declined")
    @test s==recorded
    trace=LW.social_relation_bias(s,SB,"trade_offer")
    @test !isempty(trace["source_refs"]) && !isempty(trace["authority"])
    snapshot=LW.social_relations_snapshot(s);empty!(snapshot["peers"])
    @test s==recorded
    restored=saved_relation(s)
    @test restored==s
    relation_event!(s,SB,"trade_offer","next",11,"exchanged";value=-.1)
    relation_event!(restored,SB,"trade_offer","next",11,"exchanged";value=-.1)
    @test restored==s && profile(restored)==profile(s)
    @test all(bias(restored,c)==bias(s,c) for c in ("request","give","trade_offer","trade_response"))
end

@testset "long histories stay bounded without fabricating certainty" begin
    s=LW.social_relations_state(SA)
    for i in 1:160
        relation_event!(s,SB,"trade_offer","many-$i",i,"exchanged";value=isodd(i) ? 4. : -4.)
    end
    @test length(s["records"])<=32 && length(s["peers"])==1
    @test s["peers"][SB]["trade_value_samples"]==160
    @test 0<profile(s)["trade_probability"]<1 && profile(s)["benefit"]==0.
    @test all(isfinite(bias(s,c)) && -2<=bias(s,c)<=2 for c in ("request","give","trade_offer","trade_response"))
    @test profile(s)["aid_probability"]==.5 && !haskey(s["peers"],SC)
end

const RF=LW.RDLBody
const RH=(0.,0.)
function relationship_trade_fixture(seed=1)
    kinds=[fill(RF.RAW_ACORN,20),fill(RF.FRUIT_FOOD,2),Int[]]
    w=LW.world(true);w.positions[SC]=(100.,100.)
    for (i,a) in enumerate(LW.IDS)
        w.inventory[a]=length(kinds[i]);w.bodies[a]=RF.Body(10.,0.,90.,0.)
    end
    stores=Dict(a=>0 for a in LW.IDS)
    r=LW.food_resources((typed_food=true,initial_inventory_kinds=kinds),w,Any[],Int[],0,stores)
    for a in LW.IDS
        amount=w.inventory[a];LW.food_deposit!(r,a,false);stores[a]+=amount;w.inventory[a]=0
    end
    relations=Dict(a=>LW.social_relations_state(a) for a in LW.IDS)
    (r=r,w=w,stores=stores,t=LW.food_trade_state(seed),relations=relations)
end
function fixed_relation_offer!(x)
    weights=LW.food_trade_weights(x.w.bodies[SA],nothing)
    gain=LW.food_trade_gain(x.r.personal[SA],weights,RF.RAW_ACORN,1,RF.FRUIT_FOOD,1)
    source="relation-offer"
    candidate=SD("method"=>"fixture-offer","action"=>"trade_offer","priority"=>0.,"question"=>"stock_value_improved",
        "target"=>SB,"give_kind"=>RF.RAW_ACORN,"give_count"=>1,"want_kind"=>RF.FRUIT_FOOD,"want_count"=>1,
        "trade_role"=>"offer","trade_source"=>source,"trade_weights"=>weights,"trade_gain"=>gain,"trade_partner"=>SB)
    p=LW.choose_method!(x.t["minds"][SA]["offer"],Any[candidate],source)
    result=LW.food_exchange_execute!(x.t["world"],x.r,x.w,x.stores,RH,SA,source,"trade_offer",0;
        target=SB,give_kind=RF.RAW_ACORN,give_count=1,want_kind=RF.FRUIT_FOOD,want_count=1)
    LW.food_trade_executed!(x.t,SA,p,result;relation=x.relations[SA])
    p,result
end
function fixed_relation_accept!(x,id)
    weights=LW.food_trade_weights(x.w.bodies[SB],nothing)
    gain=LW.food_trade_gain(x.r.personal[SB],weights,RF.FRUIT_FOOD,1,RF.RAW_ACORN,1)
    source="relation-accept"
    candidate=SD("method"=>"fixture-accept","action"=>"trade_accept","priority"=>0.,"question"=>"stock_value_improved",
        "offer_id"=>id,"trade_role"=>"response","trade_source"=>source,
        "trade_weights"=>weights,"trade_gain"=>gain,"trade_partner"=>SA)
    p=LW.choose_method!(x.t["minds"][SB]["response"],Any[candidate],source)
    result=LW.food_exchange_execute!(x.t["world"],x.r,x.w,x.stores,RH,SB,source,"trade_accept",1_000_000;offer_id=id)
    LW.food_trade_executed!(x.t,SB,p,result;relation=x.relations[SB])
    p,result
end

@testset "one committed trade gives each participant their own relation" begin
    x=relationship_trade_fixture();offer,offered=fixed_relation_offer!(x)
    @test offered["status"]=="offered"
    @test profile(x.relations[SA])["trade_probability"]==.5 && profile(x.relations[SA])["benefit"]==0.
    @test isempty(x.relations[SB]["peers"])
    accept,accepted=fixed_relation_accept!(x,offered["offer_id"])
    @test accepted["status"]=="exchanged"
    @test profile(x.relations[SB],SA)["benefit"]<0. && profile(x.relations[SB],SA)["trade_probability"]==.5
    @test profile(x.relations[SA])["benefit"]==0. # proposer has not received its outcome yet
    restored=saved_relation(x)
    LW.food_trade_views!(x.t,x.r,x.w,RH,2_000_000;relations=x.relations)
    LW.food_trade_views!(restored.t,restored.r,restored.w,RH,2_000_000;relations=restored.relations)
    @test restored.relations==x.relations && LW.food_trade_snapshot(restored.t)==LW.food_trade_snapshot(x.t)
    @test profile(x.relations[SA])["benefit"]>0. && profile(x.relations[SA])["trade_probability"]>.5
    @test x.relations[SA]["peers"][SB]["trade_value_samples"]==1
    @test x.relations[SB]["peers"][SA]["trade_value_samples"]==1
    settled=deepcopy(x.relations)
    LW.food_trade_views!(x.t,x.r,x.w,RH,3_000_000;relations=x.relations)
    @test x.relations==settled && isempty(x.relations[SC]["peers"])
    @test LW.food_audit!(x.r,x.w,Int[],0,x.stores)===nothing
end

@testset "shared partner experience changes aid decisions without double refusal pressure" begin
    obs=SD("self_id"=>SA,"inventory"=>1,"body"=>SD("reserve"=>90.),
        "messages"=>[SD("id"=>"request-1","sender"=>SB,"kind"=>"request")],
        "others"=>[SD("ref"=>b,"holding_food"=>true) for b in (SB,SC)])
    records=LW.Records();pressure=LW.pressure_update(nothing,records,SA)
    fresh=LW.social_relations_state(SA);helped=LW.social_relations_state(SA)
    for i in 1:8;relation_event!(helped,SB,"aid_received","aid-$i",i,"given");end
    _,neutral=LW.experienced_response(obs,records,pressure,SA,"same";relation=fresh)
    _,friendly=LW.experienced_response(obs,records,pressure,SA,"same";relation=helped)
    @test friendly["give_probability"]>neutral["give_probability"] && friendly["give_probability"]<1.
    @test friendly["relationship"]["profile"]["aid_credit"]>0
    @test LW.experienced_response(obs,records,pressure,SA,"same")==LW.experienced_response(obs,records,pressure,SA,"same";relation=nothing)
    # Old refusal evidence remains present. New relations replace, rather than
    # add a second penalty to, the historical maximum-refusal rule.
    declined=LW.social_relations_state(SA)
    for i in 1:3
        records["old-$i"]=SD("agent_id"=>SA,"target"=>SB,"outcome"=>"refuse",
            "request_observation_id"=>"start-$i","source_observation_id"=>"end-$i")
        relation_event!(declined,SB,"aid_received","old-$i",i,"refuse")
    end
    old_pressure=LW.pressure_update(nothing,records,SA)
    _,old_rule=LW.experienced_response(obs,records,old_pressure,SA,"same")
    _,new_rule=LW.experienced_response(obs,records,old_pressure,SA,"same";relation=declined)
    @test old_rule["weight"]>0 && new_rule["weight"]==0.
    @test new_rule["give_probability"]==neutral["give_probability"]
    _,unwilling=LW.experienced_request(obs,records,old_pressure,SA,SB,"same";relation=declined)
    for i in 1:12;relation_event!(declined,SB,"aid_received","later-$i",3+i,"given");end
    _,recovered=LW.experienced_request(obs,records,old_pressure,SA,SB,"same";relation=declined)
    @test recovered["request_probability"]>unwilling["request_probability"]
    @test recovered["weight"]==0. && recovered["request_probability"]<1.
    @test LW.experienced_request(obs,records,old_pressure,SA,SB,"same";relation=declined)==
        LW.experienced_request(obs,records,old_pressure,SA,SB,"same";relation=saved_relation(declined))
    # Relationships influence willingness, not physical possession or perception.
    empty_hand=deepcopy(obs);empty_hand["inventory"]=0
    @test LW.experienced_response(empty_hand,records,old_pressure,SA,"same";relation=declined)[1][1]=="refuse"
    no_food=deepcopy(obs);no_food["others"][1]["holding_food"]=false
    @test !LW.experienced_request(no_food,records,old_pressure,SA,SB,"same";relation=declined)[1]
    @test_throws ErrorException LW.experienced_response(obs,records,old_pressure,SA,"same";relation=LW.social_relations_state(SB))
    @test_throws ErrorException LW.experienced_request(obs,records,old_pressure,SA,"unseen","same";relation=declined)
end

@testset "request targets use common H probabilities over observed candidates" begin
    relations=LW.social_relations_state(SA)
    for i in 1:8;relation_event!(relations,SB,"aid_received","known-$i",i,"given");end
    records=LW.Records();pressure=LW.pressure_update(nothing,records,SA)
    chosen,trace=LW.select_target([SB,SC],SD(),pressure;relation=relations,seed="target-seed")
    @test trace["selection"]=="common_H_distribution" && chosen in (SB,SC)
    @test trace["probabilities"][1]>.5 && 0<trace["probabilities"][2]<.5
    @test sum(trace["probabilities"])≈1.
    @test (chosen,trace)==LW.select_target([SC,SB,SB],SD(),pressure;relation=saved_relation(relations),seed="target-seed")
    unknown_only,unknown_trace=LW.select_target([SC],SD(),pressure;relation=relations,seed="target-seed")
    @test unknown_only==SC && length(unknown_trace["candidates"])==1
    @test !haskey(relations["peers"],SC) # querying a candidate does not invent experience
    pressure.parent.H=8
    _,broad=LW.select_target([SB,SC],SD(),pressure;relation=relations,seed="target-seed")
    @test any(c->c["target"]===nothing,broad["candidates"])
    @test .5<broad["probabilities"][1]/sum(broad["probabilities"][1:2])<trace["probabilities"][1]
end

@testset "aid and personal trade value carry into barter choices" begin
    # Isolate relation weighting; default necessity admission is checked by
    # portable_items/necessity_checks.jl and the LW integration fixture.
    x=relationship_trade_fixture();_,offered=fixed_relation_offer!(x)
    view=LW.food_exchange_view(x.t["world"],x.r,x.w,RH,SB,1_000_000)
    good=LW.social_relations_state(SB);bad=LW.social_relations_state(SB)
    for i in 1:8
        relation_event!(good,SA,"aid_received","help-$i",i,"given")
        relation_event!(bad,SA,"trade_response","loss-$i",i,"exchanged";value=-1.)
    end
    plans=Any[]
    for rel in (bad,LW.social_relations_state(SB),good)
        t=LW.food_trade_state(8)
        push!(plans,LW.food_trade_plan!(t,SB,view,x.w.bodies[SB],nothing,1_000_000;relation=rel,require_need=false))
    end
    accept_probability(p)=p["action"]=="trade_accept" ? p["selection_probability"] : 1-p["selection_probability"]
    probabilities=accept_probability.(plans)
    @test 0<probabilities[1]<probabilities[2]<probabilities[3]<1
    expected=LW.food_trade_gain(view["own_stock"],LW.food_trade_weights(x.w.bodies[SB],nothing),RF.FRUIT_FOOD,1,RF.RAW_ACORN,1)
    @test all(p->p["action"]=="trade_decline" ? p["trade_gain"]==0. : p["trade_gain"]==expected,plans)
    @test all(p->p["action"] in ("trade_accept","trade_decline"),plans)
    @test last(good["choices"])["trace"]["profile"]["aid_credit"]>0.
    @test good["use_counts"]["trade_response"]==1
    # A positive proposal can be chosen, but familiarity never invents stock.
    chosen_offer=nothing
    for seed in 1:32
        z=relationship_trade_fixture(seed);rel=LW.social_relations_state(SA)
        relation_event!(rel,SB,"aid_received","old-help",1,"given")
        ownview=LW.food_exchange_view(z.t["world"],z.r,z.w,RH,SA,1_000_000)
        p=LW.food_trade_plan!(z.t,SA,ownview,z.w.bodies[SA],nothing,1_000_000;relation=rel,require_need=false)
        if p!==nothing
            @test p["priority"]≈4p["trade_gain"]-1+bias(rel,"trade_offer")
            @test p["give_count"]<=z.r.personal[SA][p["give_kind"]] && p["target"]==SB
            @test rel["use_counts"]["trade_offer"]==1 && !isempty(last(rel["choices"])["trace"]["source_refs"])
            chosen_offer=p;break
        end
    end
    @test chosen_offer!==nothing
    println("relationship response probabilities ",JSON3.write((negative=probabilities[1],neutral=probabilities[2],helped=probabilities[3])))
end

@testset "other social actions do not erase a pending aid request receipt" begin
    w=LW.world(true);state=LW.social_initial();request_op="ask-b"
    request_id=SA*":"*request_op
    state["pending"]=SD("message_id"=>request_id,"target"=>SB,"deadline"=>5_000_000,
        "request_observation_id"=>"ob:0:$SA","operation_id"=>request_op)
    request=LW.communicate!(w,SA,request_op,"request",SB)
    results=LW.social_result_window(SD(),state["pending"],request_op,request)
    @test request["status"]=="expressed" && length(results)==1
    other_request=LW.communicate!(w,SC,"ask-a","request",SA)
    @test other_request["status"]=="expressed"
    w.seconds=1.
    refusal=LW.communicate!(w,SA,"answer-c","refuse",SC,SC*":ask-a")
    @test refusal["status"]=="expressed"
    results=LW.social_result_window(results,state["pending"],"answer-c",refusal)
    @test length(results)==2 && results[request_op]["status"]=="expressed"
    @test results["answer-c"]["action"]=="refuse"
    # The window owns its evidence, so editing caller receipts cannot rewrite
    # whether the earlier request was actually expressed.
    request["status"]="changed-by-caller";refusal["status"]="changed-by-caller"
    @test results[request_op]["status"]=="expressed" && results["answer-c"]["status"]=="expressed"
    checkpoint=(w=w,state=state,results=results)
    restored=saved_relation(checkpoint)
    completed=Any[]
    for x in (checkpoint,restored)
        x.w.seconds=2.
        gift=LW.communicate!(x.w,SB,"help-a","give",SA,request_id)
        @test gift["status"]=="transferred" && x.w.inventory[SA]==1
        x.w.seconds=3.
        packet=SD("agent_id"=>SA,"capture_us"=>3_000_000,"observation_id"=>"ob:3000000:$SA","social"=>LW.observe(x.w,SA))
        finished=LW.ingest(x.state,packet,x.results)
        @test finished["records"][request_id]["outcome"]=="given" && finished["pending"]===nothing
        # This is the previous failure mode with precisely the same world
        # and visible gift: the latest unrelated reply hid our request receipt.
        old=LW.ingest(x.state,packet,SD("answer-c"=>x.results["answer-c"]))
        @test old["records"][request_id]["outcome"]=="request_not_executed"
        push!(completed,finished)
    end
    @test completed[1]["records"][request_id]==completed[2]["records"][request_id]
    @test LW.ingest(completed[1],SD("agent_id"=>SA,"capture_us"=>4_000_000,
        "observation_id"=>"ob:4000000:$SA","social"=>LW.observe(w,SA)),results)["records"][request_id]==completed[1]["records"][request_id]
    # Independent newer actions keep exactly the latest and pending receipt.
    kept=results
    for i in 1:10
        kept=LW.social_result_window(kept,state["pending"],"other-$i",SD("status"=>"wait","operation"=>"other-$i"))
        @test Set(keys(kept))==Set([request_op,"other-$i"])
    end
    cleared=LW.social_result_window(kept,completed[1]["pending"],"next",SD("status"=>"wait"))
    @test Set(keys(cleared))==Set(["next"])
    relations=LW.social_relations_state(SA);e=completed[1]["records"][request_id]
    relation_event!(relations,e["target"],"aid_received",request_id,e["tick"],e["outcome"])
    @test profile(relations)["aid_probability"]>.5 && profile(relations)["aid_credit"]>0.
end

@testset "retaining a failed request does not turn it into received help" begin
    w=LW.world(true);w.positions[SA]=(100.,100.)
    state=LW.social_initial();request_op="unreachable-request";request_id=SA*":"*request_op
    state["pending"]=SD("message_id"=>request_id,"target"=>SB,"deadline"=>5_000_000,
        "request_observation_id"=>"ob:0:$SA","operation_id"=>request_op)
    unavailable=LW.communicate!(w,SA,request_op,"request",SB)
    @test unavailable["status"]=="unavailable"
    results=LW.social_result_window(SD(),state["pending"],request_op,unavailable)
    w.seconds=1.
    waited=LW.communicate!(w,SA,"waiting","wait")
    results=LW.social_result_window(results,state["pending"],"waiting",waited)
    @test results[request_op]["status"]=="unavailable" && length(results)==2
    w.seconds=5.
    finished=LW.ingest(state,SD("agent_id"=>SA,"capture_us"=>5_000_000,
        "observation_id"=>"ob:5000000:$SA","social"=>LW.observe(w,SA)),results)
    @test finished["records"][request_id]["outcome"]=="request_not_executed"
    @test finished["pending"]===nothing && w.inventory[SA]==0
    relations=LW.social_relations_state(SA);e=finished["records"][request_id]
    relation_event!(relations,e["target"],"aid_received",request_id,e["tick"],e["outcome"])
    @test profile(relations)["aid_probability"]==.5 && profile(relations)["aid_credit"]==0.
end
