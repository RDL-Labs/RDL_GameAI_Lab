using Test, Serialization
include("../../src/lw/LW.jl")
@testset "known source is not exploration discovery" begin
 m=LW.mb_map_state(first(LW.IDS));v(ref)=Any[LW.D("ref"=>ref,"acquisition"=>"fishing")]
 @test !LW.acquisition_observe!(m,v(1))
 LW.acquisition_result!(m,"explore",nothing,100.,1.,false)
 @test !LW.acquisition_observe!(m,Any[])
 @test !LW.acquisition_observe!(m,v(1))
 @test get(m["acquisition"]["methods"]["explore"],"reward",0)==0
 @test LW.acquisition_observe!(m,v(2))
 reward=m["acquisition"]["methods"]["explore"]["reward"]
 LW.acquisition_result!(m,"explore",nothing,100.,1.,false)
 @test !LW.acquisition_observe!(m,v(2))
 @test m["acquisition"]["methods"]["explore"]["reward"]==reward
 io=IOBuffer();serialize(io,m);seekstart(io);restored=deserialize(io)
 @test !LW.acquisition_observe!(restored,v(1))
 @test LW.acquisition_observe!(restored,v(3))
 legacy=LW.mb_map_state(first(LW.IDS));s=LW.acquisition_state();legacy["acquisition"]=s
 push!(s["records"],LW.D("candidates"=>Any[LW.D("ref"=>7)]))
 LW.acquisition_result!(legacy,"explore",nothing,100.,1.,false)
 @test !LW.acquisition_observe!(legacy,v(7))
 @test LW.acquisition_observe!(legacy,v(8))
 other=LW.mb_map_state(last(LW.IDS));LW.acquisition_result!(other,"explore",nothing,100.,1.,false)
 @test LW.acquisition_observe!(other,v(1)) # no shared omniscient memory
end
