include("call_attention_checks.jl")
include("peer_name_probe.jl")
using Serialization
name_rows=Any[]
@testset "owner-held peer names after sight" begin
 w,r=call_fixture();names=LocalPeerNames(A);seed_peer_name!(names,B,"ハル")
 cue=call_observation(w,B,A,"アキ！");seen=attend_call(w,A,"アキ",cue,r)
 result=recall_peer_name(names,A,seen)
 @test result.status==:recalled && result.reply=="ハル？"
 push!(name_rows,(case="known_peer",result=result))
 @test recall_peer_name(LocalPeerNames(A),A,seen).status==:unknown_name
 @test_throws ErrorException recall_peer_name(LocalPeerNames(B),A,seen)
 push!(w.obstacles,LW.RDLMigrationProbe.Circle(2.5,0.,.5))
 @test recall_peer_name(names,A,attend_call(w,A,"アキ",cue,r)).status==:unidentified
 empty!(w.obstacles);w.positions[C]=(6.,0.)
 @test recall_peer_name(names,A,attend_call(w,A,"アキ",cue,r)).status==:unidentified
 # Same observed peer can have different names in different owners' memories.
 other=LocalPeerNames(C);seed_peer_name!(other,B,"はるさん")
 @test recall_peer_name(other,C,seen).reply=="はるさん？"
 @test recall_peer_name(names,A,seen).reply=="ハル？"
 # Return value mutation must not modify the memory.
 empty!(result.names);@test recall_peer_name(names,A,seen).reply=="ハル？"
 io=IOBuffer();serialize(io,names);seekstart(io);restored=deserialize(io)
 @test recall_peer_name(restored,A,seen)==recall_peer_name(names,A,seen)
 seed_peer_name!(names,B,"はるさん")
 @test recall_peer_name(names,A,seen).status==:multiple_names
 # Caller B hidden, visible C misassociated: recall C's name, not hidden B's name.
 w.positions[C]=(5.,1.);push!(w.obstacles,LW.RDLMigrationProbe.Circle(2.5,0.,.2))
 seed_peer_name!(names,C,"ナツ")
 mistaken=attend_call(w,A,"アキ",cue,r)
 wrong_name=recall_peer_name(names,A,mistaken)
 @test mistaken.peer==C && wrong_name.reply=="ナツ？"
 push!(name_rows,(case="misassociated_visible_peer",result=wrong_name))
end
write(joinpath(@__DIR__,"peer_name_result.json"),JSON3.write((scope="synthetic seeded owner memories; visual identity still supplied by existing API",cases=name_rows)))
