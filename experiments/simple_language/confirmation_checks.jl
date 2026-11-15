include("orientation_checks.jl")
include("../../src/lw/configured_paths/identity_confirmation_probe.jl")
# Synthetic response fixture: local recipient hears its own name then may turn.
# This is not an inferred mental state or an autonomous NPC reply policy.
function fixture_name_response!(w,speaker,target,text,own_name,headings;respond)
 cue=call_observation(w,speaker,target,text)
 if respond && cue!==nothing && cue.text==own_name*"！"
  headings[target]=cue.bearing
  return :turned
 end
 :no_response
end
function confirmation_run(;respond=true,no_names=false)
 w,r,f,m,n=inspection_fixture();w.positions[B]=(1.,0.);headings=Dict(B=>90.)
 no_names && empty!(n.relations)
 before=deepcopy(m.features);trace=Any[];calls=0;orbit_steps=0
 # World observer produces anonymous coarse geometry; discard its ref immediately.
 visual=only(LW.social_sight(w,A,90.,0;illumination=1.)["peers"])
 radius=visual["distance"];bearing=90.0 + visual["angle"]
 p=w.positions[A];center=(p[1]+radius*sind(bearing),p[2]+radius*cosd(bearing))
 for tick in 0:12
  p=w.positions[A];bearing=atand(center[1]-p[1],center[2]-p[2])
  # Reacquire the sole visible silhouette after lateral motion, using only coarse angle.
  silhouettes=LW.social_sight(w,A,bearing,tick;illumination=1.)["peers"]
  length(silhouettes)==1 && (bearing+=only(silhouettes)["angle"])
  view=appearance_observe(w,A,bearing,f,:fine;headings,now=tick)
  identity=appearance_identify(m,A,view)
  if identity.status==:recognized
   @assert m.features==before
   return (status=:recognized,name=recall_peer_name(n,A,identity),calls=calls,orbit_steps=orbit_steps,trace=trace)
  end
  candidates=configured_confirm_candidates(identity,n,r;calls,orbit_steps)
  isempty(candidates) && return (status=:unresolved,trace=trace)
  selected=first(candidates)
  outcome=if selected.action==:call_name
   calls+=1
   fixture_name_response!(w,A,B,selected.name*"！","ハル",headings;respond)
  else
   orbit_steps+=1
   configured_confirm_orbit!(w,A,center) ? :moved : :blocked
  end
  push!(trace,(tick=tick,status=identity.status,identity_candidates=identity.candidates,candidates=candidates,selected=selected,outcome=outcome))
  outcome==:blocked && return (status=:blocked,trace=trace)
 end
 (status=:budget,trace=trace)
end
confirmation_results=Any[]
@testset "name call or orbit as confirmation candidates" begin
 a=confirmation_run()
 @test a.status==:recognized && a.name.reply=="ハル？"
 @test a.calls==1 && a.orbit_steps==0
 @test first(a.trace).selected.action==:call_name
 push!(confirmation_results,(case="call_then_turn",result=a))
 b=confirmation_run(;respond=false)
 @test b.status==:recognized && b.calls==1 && b.orbit_steps>0
 @test b.trace[1].identity_candidates==b.trace[2].identity_candidates
 @test b.trace[1].outcome==:no_response && b.trace[2].selected.action==:orbit
 push!(confirmation_results,(case="no_response_then_orbit",result=b))
 c=confirmation_run(;no_names=true)
 @test c.status==:recognized && c.calls==0 && c.orbit_steps>0
 @test c.name.status==:unknown_name
 push!(confirmation_results,(case="no_name_orbit",result=c))
 w,r,f,m,n=inspection_fixture();heads=Dict(B=>90.)
 @test fixture_name_response!(w,A,B,"ナツ！","ハル",heads;respond=true)==:no_response
 @test heads[B]==90.
 w.positions[A]=(0.,0.);push!(w.obstacles,LW.RDLMigrationProbe.Circle(.2,-.4,.2))
 @test !configured_confirm_orbit!(w,A,(.625,0.))
 @test w.positions[A]==(0.,0.)
end
write(joinpath(@__DIR__,"confirmation_result.json"),JSON3.write((settings=CONFIRM_PROBE,cases=confirmation_results)))
