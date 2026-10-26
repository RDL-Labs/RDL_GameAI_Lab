using Test
include("../../../integrations/lightweight_julia/native.jl")
@testset "camp protection independent of hazard distance" begin
    w=(positions=Dict("a"=>(0.,0.)),obstacles=Any[])
    hazards=[(x=0.,z=.01,vx=0.,vz=0.,start=0,stop=100)]
    yaw=Dict("a"=>0.)
    raw=hazard_observation(w,"a",yaw,hazards,0)
    @test length(raw["features"])==1
    ob=hazard_observation(w,"a",yaw,hazards,0;safe_home=(0.,0.))
    @test ob["safe_zone"] && isempty(ob["features"])
    @test length(ob["observed_hazards"])==1
    for continuous in (false,true)
        s=safety_state();s["active"]=true;s["H"]=7
        loop=BasicLoop("safety")
        plan=continuous ? safety_methods!(s,loop,ob,D(),"test") : safety_plan!(s,ob,D())
        @test plan===nothing
        @test !s["active"] && s["H"]==0
    end
    w.positions["a"]=(1.25,0.)
    @test hazard_observation(w,"a",yaw,hazards,0;safe_home=(0.,0.))["safe_zone"]
    w.positions["a"]=(1.2501,0.)
    @test !get(hazard_observation(w,"a",yaw,hazards,0;safe_home=(0.,0.)),"safe_zone",false)
end
@testset "visible nearby refuge candidates" begin
    ref=string(findfirst(==(0),ANGLES)-1)
    row=D("ref"=>ref,"cost"=>1.,"distance"=>.5)
    home=D("forward"=>3.,"right"=>0.,"distance"=>3.)
    @test length(refuge_candidates(home,[row],Any[]))==1
    @test isempty(refuge_candidates(nothing,[row],Any[]))
    @test isempty(refuge_candidates(merge(home,D("distance"=>7.)),[row],Any[]))
    @test isempty(refuge_candidates(home,[merge(row,D("cost"=>nothing))],Any[]))
    @test isempty(refuge_candidates(home,[row],[D("forward"=>.3,"right"=>0.)]))
    near= D("forward"=>1.5,"right"=>0.,"distance"=>1.5)
    @test length(refuge_candidates(near,[row],[D("forward"=>1.,"right"=>0.)]))==1
    c=only(refuge_candidates(home,[row],Any[]))
    @test c["refuge"] && c["priority"]>8
end
