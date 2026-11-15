include("call_attention_checks.jl")
include("peer_name_probe.jl")
include("appearance_probe.jl")
using Serialization
appearance_rows=Any[]
@testset "five features collapse with distance and rho" begin
 w,r=call_fixture()
 # Only fine resolution separates the first feature; all five are compared.
 b=(.51,.2,.7,.3,.8);c=(.64,.2,.7,.3,.8)
 features=Dict(B=>b,C=>c)
 memory=LocalAppearanceMemory(A,copy(features))
 names=LocalPeerNames(A);seed_peer_name!(names,B,"ハル");seed_peer_name!(names,C,"ナツ")
 for (distance,rho,expected,bins) in ((5.,:fine,:ambiguous,2),(3.,:fine,:ambiguous,4),(1.,:coarse,:ambiguous,2),(1.,:fine,:recognized,8))
  w.positions[B]=(distance,0.)
  cue=call_observation(w,B,A,"アキ！")
  result=attend_appearance(w,A,"アキ",cue,features,memory,r,names;rho)
  @test result.status==expected
  @test only(result.view.patches).bins==bins
  @test propertynames(only(result.view.patches))==(:features,:bins)
  if expected==:recognized
   @test result.peer==B && result.name.reply=="ハル？"
  else
   @test result.peer===nothing && result.relation===nothing && result.name===nothing
  end
  push!(appearance_rows,(distance=distance,rho=rho,result=result))
 end
 # Change true visible identity to C while retaining B's appearance: inferred identity is B.
 w.positions[B]=(50.,50.);w.positions[C]=(1.,0.);features[C]=b
 cue=call_observation(w,C,A,"アキ！")
 @test attend_appearance(w,A,"アキ",cue,features,memory,r,names;rho=:fine).peer==B
 identical=LocalAppearanceMemory(A,Dict(B=>b,C=>b))
 @test attend_appearance(w,A,"アキ",cue,features,identical,r,names;rho=:fine).status==:ambiguous
 features[C]=(0.,0.,0.,0.,0.)
 @test attend_appearance(w,A,"アキ",cue,features,memory,r,names;rho=:fine).status==:unknown
 push!(w.obstacles,LW.RDLMigrationProbe.Circle(.5,0.,.2))
 @test attend_appearance(w,A,"アキ",cue,features,memory,r,names;rho=:fine).status==:unseen
 @test feature_bins((0.,1.,.5,.25,.75),2)==(0,1,1,0,1)
 @test_throws ErrorException feature_bins((NaN,0.,0.,0.,0.),2)
 @test_throws ErrorException appearance_resolution(1.,:invalid)
 io=IOBuffer();serialize(io,memory);seekstart(io)
 @test deserialize(io).features==memory.features
end
write(joinpath(@__DIR__,"appearance_result.json"),JSON3.write((settings=APPEARANCE_PROBE,cases=appearance_rows)))
