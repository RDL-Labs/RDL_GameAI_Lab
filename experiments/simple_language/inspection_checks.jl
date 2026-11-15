include("appearance_checks.jl")
include("../../src/lw/configured_paths/call_inspection_probe.jl")
function inspect_call!(w,listener,cue,features,memory,relations,names)
 rows=Any[];rho_index=1;moves=0;bearing=cue.bearing
 for tick in 0:20
  rho=CALL_INSPECTION.rhos[rho_index]
  view=appearance_observe(w,listener,bearing,features,rho;now=tick)
  identity=appearance_identify(memory,listener,view)
  # Coarse visual geometry only, discard ref. No target tracking by world ID.
  sight=LW.social_sight(w,listener,bearing,tick;illumination=1.)
  peers=filter(p->abs(p["angle"])<=CALL_PROBE.identity_cone,sight["peers"])
  lower=length(peers)==1 ? only(peers)["range_lower"] : 0.
  action=configured_call_inspection_choice(identity.status,rho_index,lower,moves)
  push!(rows,(tick=tick,rho=rho,status=identity.status,candidates=identity.candidates,action=action,position=w.positions[listener]))
  if action==:done
   return (status=:recognized,peer=identity.peer,name=recall_peer_name(names,listener,identity),relation=LW.social_relation_bias(relations,identity.peer,"give"),moves=moves,trace=rows)
  elseif action==:raise_rho
   rho_index+=1
  elseif action==:approach
   bearing+=only(peers)["angle"]
   configured_call_inspection_move!(w,listener,bearing) || return (status=:blocked,moves=moves,trace=rows)
   moves+=1
  else
   return (status=action,moves=moves,trace=rows)
  end
 end
 error("inspection exceeded bounded schedule")
end
function inspection_fixture(;identical=false)
 w,r=call_fixture();b=(.51,.2,.7,.3,.8);c=identical ? b : (.64,.2,.7,.3,.8)
 features=Dict(B=>b,C=>c);memory=LocalAppearanceMemory(A,copy(features))
 names=LocalPeerNames(A);seed_peer_name!(names,B,"ハル");seed_peer_name!(names,C,"ナツ")
 w,r,features,memory,names
end
results=Any[]
@testset "raise rho then approach" begin
 w,r,f,m,n=inspection_fixture();result=inspect_call!(w,A,call_observation(w,B,A,"アキ！"),f,m,r,n)
 @test result.status==:recognized && result.peer==B && result.name.reply=="ハル？"
 @test result.moves==6
 @test [x.action for x in result.trace[1:3]]==[:raise_rho,:raise_rho,:approach]
 @test result.trace[end].rho==:fine
 push!(results,(case="far_then_recognized",result=result))
 w,r,f,m,n=inspection_fixture();w.positions[B]=(1.,0.)
 result=inspect_call!(w,A,call_observation(w,B,A,"アキ！"),f,m,r,n)
 @test result.status==:recognized && result.moves==0
 push!(results,(case="near_attention_only",result=result))
 w,r,f,m,n=inspection_fixture(;identical=true)
 result=inspect_call!(w,A,call_observation(w,B,A,"アキ！"),f,m,r,n)
 @test result.status==:unresolved_near && result.moves==6
 push!(results,(case="identical_stops",result=result))
 w,r,f,m,n=inspection_fixture();push!(w.obstacles,LW.RDLMigrationProbe.Circle(1.,.25,.1))
 result=inspect_call!(w,A,call_observation(w,B,A,"アキ！"),f,m,r,n)
 @test result.status==:blocked && result.moves<6
 push!(results,(case="body_blocked",result=result))
 @test configured_call_inspection_choice(:ambiguous,3,4.,12)==:budget
 @test configured_call_inspection_choice(:unseen,3,4.,0)==:stop
end
write(joinpath(@__DIR__,"inspection_result.json"),JSON3.write((settings=CALL_INSPECTION,cases=results)))
