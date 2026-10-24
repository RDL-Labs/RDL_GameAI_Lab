include(joinpath(@__DIR__,"native.jl"))
using Test
candidate(m)=D("method"=>m,"priority"=>1.,"question"=>"goal","action"=>"walk")
function resolved_reward(h)
 s=BasicLoop("food";probabilistic=true);s.H=h
 choose_method!(s,[candidate("route")],"move")
 resolve_method!(s,"move",false,nothing;creditable=true)
 @test s.methods["route"].reward==0
 choose_method!(s,[candidate("work")],"pickup")
 resolve_method!(s,"pickup",true,true)
 s
end
@testset "reward is resolved parent H" begin
 low=resolved_reward(2);high=resolved_reward(10);zero=resolved_reward(0)
 @test low.events[end].reward==2 && high.events[end].reward==10
 @test high.methods["route"].reward==5 && high.methods["work"].reward==5
 @test sum(values(high.events[end].credit))==10
 @test isempty(high.credit_path)
 @test all(n.reward==0 for n in values(zero.methods))
 cs=[candidate("route"),candidate("unlearned")]
 @test method_distribution(high,cs)[1]>method_distribution(low,cs)[1]>0.5
 @test !resolve_method!(high,"pickup",true,true)
 @test high.methods["route"].reward==5
 @test_throws Exception resolve_method!(high,"pickup",true,true;creditable=false)
 s=BasicLoop("unresolved";probabilistic=true);s.H=20
 choose_method!(s,[candidate("walk")],1);resolve_method!(s,1,true,false)
 @test s.H==21 && s.methods["walk"].reward==0 && s.events[end].reward==0
 choose_method!(s,[candidate("blocked")],2);resolve_method!(s,2,false,false;creditable=false)
 @test !("blocked" in s.credit_path)
 choose_method!(s,[candidate("unknown")],3);resolve_method!(s,3,nothing,nothing;creditable=false)
 @test s.events[end].reward==0
 for i in 4:50
   choose_method!(s,[candidate("m$i")],i);resolve_method!(s,i,false,nothing;creditable=true)
 end
 @test length(s.credit_path)==32
 choose_method!(s,[candidate("m50")],51);resolve_method!(s,51,false,nothing;creditable=true)
 @test length(s.credit_path)==32 && count(==("m50"),s.credit_path)==1
 delete!(s.methods,"m49")
 choose_method!(s,[candidate("work")],52);resolve_method!(s,52,true,true)
 @test sum(values(s.events[end].credit))≈s.events[end].reward
 @test !haskey(s.events[end].credit,"m49")
end
@testset "failure evidence preserves success" begin
 s=resolved_reward(10);earned=s.methods["route"].reward
 s.H=12;choose_method!(s,[candidate("route")],"failure")
 resolve_method!(s,"failure",false,false;creditable=false)
 @test s.methods["route"].reward==earned
 @test s.methods["route"].failure_count==1 && s.methods["route"].failure_H_total==12
 @test s.events[end].failed && s.events[end].failure_H==12 && s.events[end].reward==0
 @test !("route" in s.credit_path)
 @test !resolve_method!(s,"failure",false,false;creditable=false)
 @test s.methods["route"].failure_count==1
 for (i,(method,goal)) in enumerate(((nothing,false),(false,nothing),(true,false)))
   choose_method!(s,[candidate("route")],i);resolve_method!(s,i,method,goal)
   @test !s.events[end].failed
 end
 @test s.methods["route"].failure_count==1
 s.H=0;choose_method!(s,[candidate("route")],"zero")
 resolve_method!(s,"zero",false,false)
 @test s.methods["route"].failure_count==2 && s.events[end].failure_H==0
 @test s.methods["route"].reward==earned
 @test loop_snapshot(s)["methods"]["route"]["failure_count"]==2
end
@testset "failure repels without erasing reward" begin
 s=BasicLoop("repulsion";probabilistic=true,seed=2)
 cs=[candidate("route"),candidate("other")]
 choose_method!(s,[cs[1]],1);resolve_method!(s,1,true,true)
 n=s.methods["route"];n.reward=10
 before=method_distribution(s,cs)[1]
 s.H=10;choose_method!(s,[cs[1]],2);resolve_method!(s,2,false,false)
 # Isolate persistent failure evidence from existing transient H and temperature.
 s.H=0;n.H=0
 after=method_distribution(s,cs)[1]
 @test after<before && n.reward==10
 @test failure_repulsion(n)≈log1p(10)
 n.failure_H_total=20
 @test method_distribution(s,cs)[1]<after
 @test all(method_distribution(s,cs).>0) && sum(method_distribution(s,cs))≈1
 n.failure_H_total=10;n.reward=20
 @test method_distribution(s,cs)[1]>after
 @test !resolve_method!(s,2,false,false)
 @test n.failure_H_total==10
 n.failure_H_total=0;n.reward=0
 @test method_distribution(s,cs)≈[.5,.5]
 unknown=BasicLoop("other-purpose";probabilistic=true)
 @test method_distribution(unknown,cs)≈[.5,.5]
 @test method_distribution(s,cs[1:1])==[1.]
end
