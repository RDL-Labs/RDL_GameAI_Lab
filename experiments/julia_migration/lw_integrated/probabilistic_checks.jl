include(joinpath(@__DIR__,"native.jl"))
using Test
@testset "probabilistic purpose selection" begin
 cs=[D("method"=>m,"action"=>"walk","priority"=>1.,"question"=>"target_observed") for m in ("step_0","step_90","step_-90")]
 s=BasicLoop("a:food";probabilistic=true,seed=42)
 s.last_method="step_90"
 p=method_distribution(s,cs)
 @test p≈fill(1/3,3)
 s.last_method="step_0";@test method_distribution(s,cs)==p
 learned=deepcopy(cs);learned[2]["priority"]=3.
 @test method_distribution(s,learned)[2]>p[2]
 @test sum(p)≈1 && all(p.>0)
 @test length(parent_candidates(s,repeat(cs,3)))==9
 s.H=8
 @test method_distribution(s,learned)[2]<.79
 s.H=0;s.methods["step_90"]=MethodNode(8,2,0)
 @test method_distribution(s,learned)[2]<.79
 s.methods["step_90"].H=0
 extreme=deepcopy(cs);extreme[1]["priority"]=1e300
 @test all(isfinite,method_distribution(s,extreme)) && all(method_distribution(s,extreme).>0)
 @test method_distribution(s,Any[])==[]
 @test method_distribution(s,cs[1:1])==[1.]
 a=BasicLoop("a:food";probabilistic=true,seed=42);b=BasicLoop("a:food";probabilistic=true,seed=42)
 for i in 1:100
   method_choice(a,cs);method_distribution(a,cs)
   @test choose_method!(a,cs,i)==choose_method!(b,cs,i)
   resolve_method!(a,i,true,false);resolve_method!(b,i,true,false)
 end
 @test a.H==32 && all(n.H==0 for n in values(a.methods))
 @test a.seed!=BasicLoop("b:food";probabilistic=true,seed=42).seed
 # Fixed initial state each draw isolates the absence of recency preference.
 count=0
 for i in 1:5000
   s.last_method="step_90"
   plan=choose_method!(s,cs,i);count+=plan["method"]=="step_90"
   resolve_method!(s,i,true,true)
 end
 @test 1500<count<1850
end
@testset "learned route support affects sampling" begin
 m=route_memory();m["at_home"]=true
 t=trail();push!(t["points"],D("color"=>"orange","source"=>"seen","result"=>"walk"))
 admit_route!(m,"food",t,"delivery1")
 move=D("energy"=>D("rows"=>[D("ref"=>"2","cost"=>1.)]))
 ob=D("coverage"=>"complete","features"=>[D("color"=>"orange","azimuth"=>[-7.5,7.5],"range_band"=>"mid")])
 s=BasicLoop("route-test";probabilistic=true)
 weak=landmark_candidates(move,ob,m,"food","now")
 i=findfirst(c->c["route"]!==nothing,weak)
 p=method_distribution(s,weak)[i]
 for j in 2:8;admit_route!(m,"food",t,"delivery$j");end
 strong=landmark_candidates(move,ob,m,"food","now")
 @test method_distribution(s,strong)[i]>p
 s.last_method=weak[1]["method"]
 @test method_distribution(s,strong)==method_distribution(BasicLoop("other";probabilistic=true),strong)
 s.H=32
 @test method_distribution(s,strong)[i]<method_distribution(BasicLoop("other";probabilistic=true),strong)[i]
end
