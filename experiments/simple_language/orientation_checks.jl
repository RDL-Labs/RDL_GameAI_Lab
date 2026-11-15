include("inspection_checks.jl")
view_rows=Any[]
@testset "orientation leaves unobserved features unknown" begin
 w,r,f,m,n=inspection_fixture();w.positions[B]=(1.,0.)
 cue=call_observation(w,B,A,"アキ！")
 for (heading,observed,status) in ((-90.,5,:recognized),(0.,3,:ambiguous),(90.,1,:insufficient_observation),(-90.,5,:recognized))
  result=attend_appearance(w,A,"アキ",cue,f,m,r,n;rho=:fine,headings=Dict(B=>heading))
  patch=only(result.view.patches)
  @test count(x->x!==nothing,patch.features)==observed
  @test result.status==status
  @test result.peer===nothing || result.name.reply=="ハル？"
  push!(view_rows,(heading=heading,result=result))
 end
 # Alter hidden parts only: observation and candidates remain identical.
 back=appearance_observe(w,A,cue.bearing,f,:fine;headings=Dict(B=>90.))
 f[B]=(.01,.99,.7,.99,.01)
 @test appearance_observe(w,A,cue.bearing,f,:fine;headings=Dict(B=>90.))==back
 @test appearance_identify(m,A,back).candidates==[B,C]
 single=LocalAppearanceMemory(A,Dict(B=>m.features[B]))
 @test appearance_identify(single,A,back).status==:insufficient_observation
 blank=(patches=[(features=(nothing,nothing,nothing,nothing,nothing),bins=8)],complete=true)
 @test appearance_identify(m,A,blank).status==:insufficient_observation
 zero_memory=LocalAppearanceMemory(A,Dict(B=>(0.,0.,0.,0.,0.)))
 zero_view=(patches=[(features=(0,0,0,nothing,nothing),bins=8)],complete=true)
 @test appearance_identify(zero_memory,A,zero_view).peer==B
 @test count(identity,appearance_visible_mask(45.))==5
 @test count(identity,appearance_visible_mask(120.))==3
 @test appearance_visible_mask(90.)==appearance_visible_mask(-90.)
 @test appearance_visible_mask(180.)==appearance_visible_mask(540.)
 @test_throws ErrorException appearance_visible_mask(NaN)
end
write(joinpath(@__DIR__,"orientation_result.json"),JSON3.write((settings=APPEARANCE_VIEW,cases=view_rows)))
