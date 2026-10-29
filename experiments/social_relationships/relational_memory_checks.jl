using Test, Serialization, JSON3
include("../../src/lw/LW.jl")
const MD=Dict{String,Any}
const MA="npc_a";const MB="npc_b";const MC="npc_c"
memory_state(a=MA)=LW.social_relations_state(a;relational=true)
function memory_event!(s,other,channel,id,t,outcome;value=0.,context=nothing,food_kind=0)
    LW.social_relation_event!(s,other,channel,id,t;outcome,value,context,food_kind)
end
function memory_saved(s)
    io=IOBuffer();serialize(io,s);seekstart(io);deserialize(io)
end
memory_sources(s)=sum(n["source_count"] for group in LW.social_mb_groups(s["mb"]) for n in values(group);init=0)
trade_context(g,h;n=1,m=1,need=.4)=MD("give_kind"=>g,"want_kind"=>h,"give_count"=>n,"want_count"=>m,"need"=>need)

@testset "social MB: unknown input and direction remain explicit" begin
    s=memory_state();other=memory_state(MB);before=deepcopy(s)
    p=LW.social_mb_predict(s,MB,"aid_received")
    @test p["status"]=="unknown" && p["probability"]==.5
    @test isempty(p["kind_probabilities"]) && isempty(p["mb_ids"])
    @test s==before
    @test_throws ErrorException memory_event!(s,MB,"aid_received","hidden",1,"given";context=MD("peer_inventory"=>4))
    @test s==before
    @test_throws ErrorException memory_event!(s,MB,"aid_received","nan",1,"given";context=MD("need"=>NaN))
    @test s==before
    memory_event!(s,MB,"aid_received","help",1,"given";value=.7,food_kind=1,context=MD("need"=>.5))
    @test LW.social_mb_predict(s,MB,"aid_received";situation=MD("need"=>.5))["probability"]>.5
    @test isempty(other["mb"]["nodes"]) && isempty(other["mb"]["pending"])
    @test LW.social_mb_predict(s,MC,"aid_received")["probability"]==.5
    @test s["peers"][MB]["aid_received"]["given"]==1
    @test LW.social_relation_profile(s,MB)["trade_probability"]==.5
end

@testset "food-conditioned outcomes change prediction and metric" begin
    s=memory_state();fruit=trade_context(3,1);acorn=trade_context(1,3)
    for i in 1:16
        memory_event!(s,MB,"trade_offer","fruit-$i",2i,"exchanged";value=.6,context=fruit)
        memory_event!(s,MB,"trade_offer","acorn-$i",2i+1,"declined";context=acorn)
    end
    good=LW.social_mb_predict(s,MB,"trade_offer";situation=fruit)
    bad=LW.social_mb_predict(s,MB,"trade_offer";situation=acorn)
    @test good["probability"]>.8 && bad["probability"]<.2
    @test good["value_mean"]≈.6 && bad["value_mean"]==0.
    @test LW.social_relation_bias(s,MB,"trade_offer";situation=fruit)["weight"]>
        LW.social_relation_bias(s,MB,"trade_offer";situation=acorn)["weight"]
    @test s["mb"]["metric"]["weights"][1]>2.
    @test s["mb"]["metric"]["updates"]>0
    # Partial resemblance retrieves clues, it does not require identity.
    partial=LW.social_mb_predict(s,MB,"trade_offer";situation=MD("want_kind"=>1))
    @test partial["status"]!="unknown" && partial["probability"]>.5
    @test !isempty(partial["source_refs"])
    low=LW.social_mb_predict(s,MB,"trade_offer";situation=fruit,H=.2)
    wide=LW.social_mb_predict(s,MB,"trade_offer";situation=fruit,H=12.)
    @test length(low["mb_ids"])==1
    @test length(wide["mb_ids"])==2
    @test 0<wide["probability"]<1
end

@testset "received kinds and missing evidence are not hidden knowledge" begin
    s=memory_state();c=MD("need"=>.7)
    for (i,kind) in enumerate((1,1,4))
        memory_event!(s,MB,"aid_received","meal-$i",i,"given";value=.4,food_kind=kind,context=c)
    end
    p=LW.social_mb_predict(s,MB,"aid_received";situation=c)
    @test p["kind_probabilities"][1]≈2/3
    @test p["kind_probabilities"][4]≈1/3
    @test p["value_mean"]≈.4
    @test !haskey(p["kind_probabilities"],2)
    memory_event!(s,MB,"aid_received","silent",4,"no_response_observed";context=c)
    memory_event!(s,MB,"aid_received","not-executed",5,"request_not_executed";context=c)
    @test LW.social_mb_predict(s,MB,"aid_received";situation=c)==p
    @test s["mb"]["unknown"]==2
    @test s["peers"][MB]["aid_received"]["no_response_observed"]==1
    @test_throws ErrorException memory_event!(s,MB,"aid_received","invalid-kind",6,"refuse";food_kind=1)
    memory_event!(s,MB,"aid_received","no",6,"refuse";context=c)
    @test LW.social_mb_predict(s,MB,"aid_received";situation=c)["probability"]<p["probability"]
end

@testset "Sleep adopts only the frozen evidence and resumes exactly" begin
    s=memory_state();c=trade_context(3,1)
    memory_event!(s,MB,"trade_offer","before",1,"exchanged";value=.3,context=c)
    @test LW.social_mb_sleep_freeze!(s,0,2)
    frozen=deepcopy(s["mb"]["frozen"])
    @test isempty(s["mb"]["pending"]) && isempty(s["mb"]["nodes"])
    @test !LW.social_mb_sleep_freeze!(s,0,3)
    memory_event!(s,MB,"trade_offer","during",3,"declined";context=c)
    @test s["mb"]["frozen"]==frozen
    @test memory_sources(s)==2
    @test !LW.social_mb_sleep_review!(s,0,4;completed=false)
    @test isempty(s["mb"]["nodes"])
    restored=memory_saved(s)
    @test LW.social_mb_sleep_review!(s,0,4)
    @test LW.social_mb_sleep_review!(restored,0,4)
    @test s==restored
    @test memory_sources(s)==2
    @test sum(n["source_count"] for n in values(s["mb"]["nodes"]))==1
    @test sum(n["source_count"] for n in values(s["mb"]["pending"]))==1
    @test !LW.social_mb_sleep_review!(s,0,5)
    @test LW.social_mb_sleep_freeze!(s,1,6)
    @test LW.social_mb_sleep_review!(s,1,7)
    @test memory_sources(s)==2 && length(s["mb"]["nodes"])==1
    @test only(values(s["mb"]["nodes"]))["successes"]==1
    @test only(values(s["mb"]["nodes"]))["samples"]==2
    @test only(values(s["mb"]["nodes"]))["source_count"]==2
    @test length(only(values(s["mb"]["nodes"]))["source_refs"])==2
    @test !LW.social_mb_sleep_freeze!(s,1,8)
    # Original receipt identity still prevents double learning after admission.
    before=deepcopy(s)
    @test !memory_event!(s,MB,"trade_offer","during",3,"declined";context=c)
    @test s==before
    @test_throws ErrorException memory_event!(s,MB,"trade_offer","during",3,"declined";context=trade_context(1,3))
    @test s==before
    @test JSON3.read(JSON3.write(LW.social_relations_snapshot(s)))!==nothing
end

@testset "compression retains outcome distinctions and source mass" begin
    s=memory_state()
    # Similar owner need, same food terms and similar observed consequences.
    memory_event!(s,MB,"trade_offer","near-1",1,"exchanged";value=.4,context=trade_context(3,1;need=.2))
    memory_event!(s,MB,"trade_offer","near-2",2,"exchanged";value=.4,context=trade_context(3,1;need=.4))
    # Different food terms or opposite consequence remain distinct memories.
    memory_event!(s,MB,"trade_offer","different-food",3,"exchanged";value=.4,context=trade_context(1,3;need=.4))
    memory_event!(s,MB,"trade_offer","opposite-value",4,"exchanged";value=-.4,context=trade_context(3,1;need=.6))
    LW.social_mb_sleep_freeze!(s,0,5);LW.social_mb_sleep_review!(s,0,6)
    @test memory_sources(s)==4
    @test length(s["mb"]["nodes"])==3
    @test s["mb"]["merged"]==1
    @test sum(n["value_sum"] for n in values(s["mb"]["nodes"]))≈.8
    @test sum(n["represented"] for n in values(s["mb"]["nodes"]))==4
end

@testset "interrupted reviews keep bounded provisional evidence" begin
    s=memory_state();t=0
    for day in 0:3
        for g in 1:4,h in 1:4,n in 1:4,m in 1:4
            g==h && continue;t+=1
            memory_event!(s,MB,"trade_offer","budget-$t",t,"exchanged";value=.2,
                context=trade_context(g,h;n,m,need=.4day))
        end
        t+=1;LW.social_mb_sleep_freeze!(s,day,t)
        @test length(s["mb"]["frozen"]["candidates"])<=LW.SOCIAL_MB_PENDING_LIMIT
        @test length(s["mb"]["pending"])<=LW.SOCIAL_MB_PENDING_LIMIT
        @test !LW.social_mb_sleep_review!(s,day,t+1;completed=false)
    end
    @test s["mb"]["admission_blocked"]>0
    @test s["mb"]["provisional_evicted"]>0
    @test LW.social_mb_sleep_review!(s,3,t+2)
    @test length(s["mb"]["nodes"])<=LW.SOCIAL_MB_NODE_LIMIT
    @test length(s["records"])<=32
    @test length(s["mb"]["metric"]["records"])<=64
    @test all(length(n["source_refs"])<=16 for n in values(s["mb"]["nodes"]))
end
