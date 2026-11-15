using Test,Serialization,SHA
include("cohort_join.jl")
@testset "additive actor slots preserve existing state" begin
 old_actor=Dict("memory"=>[1,2],"seed"=>UInt64(731))
 state=Dict{Symbol,Any}(:actors=>Dict("npc_a"=>old_actor),:nested=>Dict("ledger"=>Dict("npc_a"=>0)),:clock=>33)
 new_actor=Dict("memory"=>Int[],"seed"=>UInt64(193))
 fresh=Dict{Symbol,Any}(:actors=>Dict("npc_a"=>Dict("memory"=>[99]),"npc_e"=>new_actor),
  :nested=>Dict("ledger"=>Dict("npc_a"=>0,"npc_e"=>0)),:clock=>0)
 paths=String[];cohort_add_slots!(state,fresh,paths)
 @test state[:actors]["npc_a"]===old_actor
 @test old_actor["memory"]==[1,2] && old_actor["seed"]==731
 @test state[:actors]["npc_e"]===new_actor
 @test state[:clock]==33
 @test state[:nested]["ledger"]["npc_e"]==0
 @test length(paths)==2
 @test_throws AssertionError cohort_add_slots!(state,fresh,String[])
 shared=Dict{String,Any}("npc_a"=>1)
 old=Dict(:left=>shared,:right=>shared)
 new_shared=Dict{String,Any}("npc_a"=>2,"npc_e"=>3)
 cohort_add_slots!(old,Dict(:left=>new_shared,:right=>new_shared),String[])
 @test old[:left]===old[:right]
 @test old[:left]==Dict("npc_a"=>1,"npc_e"=>3)
end
