using Test,JSON3
include("../../src/lw/LW.jl")
include("call_attention_probe.jl")
const A=LW.IDS[1];const B=LW.IDS[2];const C=LW.IDS[3]
function call_fixture()
 w=LW.world(true);empty!(w.obstacles)
 for a in LW.IDS;w.positions[a]=(50.,50.);end
 w.positions[A]=(0.,0.);w.positions[B]=(5.,0.)
 relations=LW.social_relations_state(A)
 for i in 1:3;LW.social_relation_event!(relations,B,"aid_received","fixture-$i",i;outcome="given");end
 w,relations
end
rows=Any[]
@testset "call -> visual observation -> relationship MB" begin
 w,r=call_fixture();before=deepcopy(r)
 @test isempty(LW.social_sight(w,A,-90.,0;illumination=1.)["peers"])
 cue=call_observation(w,B,A,"アキ！")
 @test propertynames(cue)==(:text,:bearing)
 matched=attend_call(w,A,"アキ",cue,r)
 @test matched.status==:visually_matched && matched.peer==B
 @test matched.relation==LW.social_relation_bias(r,B,"give")
 @test r==before
 push!(rows,(case="visible_after_turn",cue=cue,result=matched))
 push!(w.obstacles,LW.RDLMigrationProbe.Circle(2.5,0.,.5))
 hidden=attend_call(w,A,"アキ",cue,r)
 @test hidden.status==:unseen && hidden.relation===nothing
 push!(rows,(case="occluded",result=hidden))
 empty!(w.obstacles);w.positions[C]=(6.,0.)
 ambiguous=attend_call(w,A,"アキ",cue,r)
 @test ambiguous.status==:ambiguous && ambiguous.relation===nothing
 push!(rows,(case="two_visible",result=ambiguous))
 @test attend_call(w,A,"別名",cue,r).status==:not_addressed
 w.positions[B]=(9.,0.)
 @test call_observation(w,B,A,"アキ！")===nothing
 @test attend_call(w,A,"アキ",nothing,r).status==:not_heard
 w.positions[B]=(5.,0.);w.hearing[A]=false
 @test call_observation(w,B,A,"アキ！")===nothing
 # Wrong visual association is possible: hidden caller B, visible bystander C.
 w.hearing[A]=true;w.positions[C]=(5.,1.)
 push!(w.obstacles,LW.RDLMigrationProbe.Circle(2.5,0.,.2))
 mistaken=attend_call(w,A,"アキ",call_observation(w,B,A,"アキ！"),r)
 @test mistaken.peer==C
 push!(rows,(case="possible_misidentification",result=mistaken))
end
write(joinpath(@__DIR__,"call_attention_result.json"),JSON3.write((settings=CALL_PROBE,cases=rows)))
